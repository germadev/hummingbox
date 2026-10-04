package es.germade.voicerecorder_native

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.io.RandomAccessFile

/** Convierte entre audio comprimido y WAV PCM de 16 bits con MediaCodec. */
internal class AudioCodecHandler : MethodChannel.MethodCallHandler {
    private val runner = BackgroundRunner()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val input = call.argument<String>("input")
        val output = call.argument<String>("output")
        when (call.method) {
            "decodeToWav", "encodeToM4a" -> {
                if (input == null || output == null) {
                    result.error("bad_args", "Faltan las rutas de entrada o salida", null)
                    return
                }
                if (call.method == "decodeToWav") {
                    runner.run(result) {
                        decodeToWav(input, output)
                        null
                    }
                } else {
                    val bitRate = call.argument<Int>("bitRate") ?: 128_000
                    runner.run(result) {
                        encodeToM4a(input, output, bitRate)
                        null
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private companion object {
        const val TIMEOUT_US = 10_000L

        fun decodeToWav(inputPath: String, outputPath: String) {
            val extractor = MediaExtractor()
            var decoder: MediaCodec? = null
            try {
                extractor.setDataSource(inputPath)
                val track = (0 until extractor.trackCount).firstOrNull {
                    extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
                } ?: throw IOException("El archivo no tiene audio")
                extractor.selectTrack(track)
                val format = extractor.getTrackFormat(track)
                var sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)

                val codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
                decoder = codec
                codec.configure(format, null, null, 0)
                codec.start()

                WavWriter(File(outputPath)).use { wav ->
                    val info = MediaCodec.BufferInfo()
                    var inputDone = false
                    while (true) {
                        if (!inputDone) {
                            val index = codec.dequeueInputBuffer(TIMEOUT_US)
                            if (index >= 0) {
                                val buffer = codec.getInputBuffer(index)!!
                                val size = extractor.readSampleData(buffer, 0)
                                if (size < 0) {
                                    codec.queueInputBuffer(
                                        index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                                    )
                                    inputDone = true
                                } else {
                                    codec.queueInputBuffer(index, 0, size, extractor.sampleTime, 0)
                                    extractor.advance()
                                }
                            }
                        }

                        val index = codec.dequeueOutputBuffer(info, TIMEOUT_US)
                        if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                            // El formato real de salida puede diferir del de la pista.
                            val output = codec.outputFormat
                            sampleRate = output.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                            channels = output.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                            if (output.containsKey(MediaFormat.KEY_PCM_ENCODING) &&
                                output.getInteger(MediaFormat.KEY_PCM_ENCODING) != AudioFormat.ENCODING_PCM_16BIT
                            ) {
                                throw IOException("El decodificador no genera PCM de 16 bits")
                            }
                        } else if (index >= 0) {
                            if (info.size > 0) {
                                val buffer = codec.getOutputBuffer(index)!!
                                buffer.position(info.offset)
                                buffer.limit(info.offset + info.size)
                                wav.write(buffer)
                            }
                            codec.releaseOutputBuffer(index, false)
                            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                        }
                    }
                    wav.finish(sampleRate, channels)
                }
            } finally {
                decoder?.let {
                    runCatching { it.stop() }
                    it.release()
                }
                extractor.release()
            }
        }

        fun encodeToM4a(inputPath: String, outputPath: String, bitRate: Int) {
            val wav = readWavInfo(File(inputPath))
            val format = MediaFormat.createAudioFormat(
                MediaFormat.MIMETYPE_AUDIO_AAC, wav.sampleRate, wav.channels,
            ).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16 * 1024)
            }

            val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            try {
                encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                encoder.start()
                val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                try {
                    RandomAccessFile(inputPath, "r").use { file ->
                        encode(encoder, muxer, file, wav)
                    }
                } finally {
                    runCatching { muxer.release() }
                }
            } finally {
                runCatching { encoder.stop() }
                encoder.release()
            }
        }

        private fun encode(encoder: MediaCodec, muxer: MediaMuxer, file: RandomAccessFile, wav: WavInfo) {
            val bytesPerFrame = 2 * wav.channels
            var remaining = wav.dataLength - wav.dataLength % bytesPerFrame
            var framesQueued = 0L
            val chunk = ByteArray(64 * 1024)
            val info = MediaCodec.BufferInfo()
            var track = -1
            var muxerStarted = false
            var inputDone = false
            file.seek(wav.dataOffset)

            while (true) {
                if (!inputDone) {
                    val index = encoder.dequeueInputBuffer(TIMEOUT_US)
                    if (index >= 0) {
                        val buffer = encoder.getInputBuffer(index)!!
                        buffer.clear()
                        val presentationUs = framesQueued * 1_000_000L / wav.sampleRate
                        var size = minOf(buffer.remaining().toLong(), remaining, chunk.size.toLong()).toInt()
                        size -= size % bytesPerFrame
                        if (size <= 0) {
                            encoder.queueInputBuffer(
                                index, 0, 0, presentationUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputDone = true
                        } else {
                            file.readFully(chunk, 0, size)
                            buffer.put(chunk, 0, size)
                            encoder.queueInputBuffer(index, 0, size, presentationUs, 0)
                            framesQueued += size / bytesPerFrame
                            remaining -= size
                        }
                    }
                }

                val index = encoder.dequeueOutputBuffer(info, TIMEOUT_US)
                if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    if (muxerStarted) throw IOException("El formato del codificador cambió a mitad")
                    track = muxer.addTrack(encoder.outputFormat)
                    muxer.start()
                    muxerStarted = true
                } else if (index >= 0) {
                    val buffer = encoder.getOutputBuffer(index)!!
                    val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                    if (info.size > 0 && !isConfig && muxerStarted) {
                        buffer.position(info.offset)
                        buffer.limit(info.offset + info.size)
                        muxer.writeSampleData(track, buffer, info)
                    }
                    encoder.releaseOutputBuffer(index, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                }
            }

            if (!muxerStarted) throw IOException("No se generó audio")
            muxer.stop()
        }
    }
}
