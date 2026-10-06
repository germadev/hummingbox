package es.germade.voicerecorder_native

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import android.os.Process
import android.os.SystemClock
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue
import kotlin.math.max
import kotlin.math.min

/**
 * Suena el piano por un solo [AudioTrack], con las notas mezcladas por
 * [PianoMixer] en un hilo propio: el sistema no tiene que sumar ni cortar
 * reproductores, que es lo que hacía chasquear al tocar.
 *
 * Los sonidos de las teclas son WAV mono de 16 bits a [sampleRate] (los
 * escribe la app), que se leen una vez ("load") y se tocan por su ruta.
 * Sin notas durante [IDLE_MS], la salida se pausa hasta la siguiente.
 */
internal class PianoOutput(context: Context) : MethodChannel.MethodCallHandler {
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    /** La frecuencia de la salida del dispositivo: así el sistema no remuestrea. */
    private val sampleRate: Int =
        audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)?.toIntOrNull()
            ?.takeIf { it in 8000..192000 } ?: 48000

    /** Fotogramas que pide de una vez la salida del dispositivo. */
    private val framesPerBurst: Int =
        audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER)?.toIntOrNull()
            ?.takeIf { it in 16..8192 } ?: PianoMixer.BLOCK

    private val sounds = ConcurrentHashMap<String, ShortArray>()
    private val loader = BackgroundRunner()

    /** Lo que se pide al mezclador, que lo hace el hilo del audio. */
    private val commands = ConcurrentLinkedQueue<(PianoMixer) -> Unit>()
    private val lock = Object()

    @Volatile private var lastActivity = 0L

    /** El hilo del audio y su número: al cerrar, cambia y el hilo termina. */
    private var thread: Thread? = null
    @Volatile private var generation = 0

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> {
                start()
                result.success(mapOf("sampleRate" to sampleRate))
            }
            "load" -> {
                val path = call.argument<String>("path") ?: return result.error("bad_args", "Falta path", null)
                if (sounds.containsKey(path)) return result.success(null)
                loader.run(result) {
                    sounds[path] = readSamples(File(path))
                    null
                }
            }
            "unload" -> {
                call.argument<List<String>>("paths")?.forEach { sounds.remove(it) }
                result.success(null)
            }
            "play" -> {
                val key = call.argument<Int>("key") ?: return result.error("bad_args", "Falta key", null)
                val path = call.argument<String>("path") ?: return result.error("bad_args", "Falta path", null)
                val samples = sounds[path] ?: return result.error("not_loaded", "Sin cargar: $path", null)
                start()
                post { it.play(key, samples) }
                result.success(null)
            }
            "release" -> {
                val key = call.argument<Int>("key") ?: return result.error("bad_args", "Falta key", null)
                val fadeMs = call.argument<Int>("fadeMs") ?: 0
                val frames = max(1, (sampleRate.toLong() * fadeMs / 1000).toInt())
                post { it.fadeOut(key, frames) }
                result.success(null)
            }
            "stop" -> {
                val key = call.argument<Int>("key") ?: return result.error("bad_args", "Falta key", null)
                post { it.fadeOut(key, it.cutFadeFrames) }
                result.success(null)
            }
            "close" -> {
                close()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun post(command: (PianoMixer) -> Unit) {
        lastActivity = SystemClock.elapsedRealtime()
        commands.add(command)
        synchronized(lock) { lock.notifyAll() }
    }

    /** Arranca el hilo del audio, si no está ya (o lo despierta). */
    private fun start() {
        lastActivity = SystemClock.elapsedRealtime()
        if (thread?.isAlive == true) {
            synchronized(lock) { lock.notifyAll() }
            return
        }
        // Lo que quedara de un hilo anterior ya no vale.
        commands.clear()
        val current = ++generation
        thread = Thread({ run(current) }, "piano-output").apply { start() }
    }

    fun close() {
        generation++
        synchronized(lock) { lock.notifyAll() }
        thread = null
        commands.clear()
        sounds.clear()
    }

    private fun run(current: Int) {
        Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
        val running = { generation == current }
        val track = try {
            createTrack()
        } catch (e: Exception) {
            return
        }
        val mixer = PianoMixer(sampleRate)
        val buffer = FloatArray(PianoMixer.BLOCK)
        var underruns = 0
        // Al arrancar, el sistema puede contar que se ha quedado sin muestras
        // antes de recibir las primeras: eso no cuenta.
        var settledAt = 0L
        fun play() {
            track.play()
            settledAt = SystemClock.elapsedRealtime() + SETTLE_MS
        }
        try {
            play()
            while (running()) {
                while (true) {
                    val command = commands.poll() ?: break
                    command(mixer)
                }
                if (mixer.isIdle && commands.isEmpty() &&
                    SystemClock.elapsedRealtime() - lastActivity > IDLE_MS
                ) {
                    // Sin nada que sonar: se pausa hasta que llegue algo.
                    track.pause()
                    track.flush()
                    synchronized(lock) {
                        while (running() && commands.isEmpty() &&
                            SystemClock.elapsedRealtime() - lastActivity > IDLE_MS
                        ) {
                            lock.wait()
                        }
                    }
                    if (!running()) break
                    play()
                    continue
                }
                mixer.render(buffer, 0, buffer.size)
                var offset = 0
                while (offset < buffer.size && running()) {
                    val written = track.write(buffer, offset, buffer.size - offset, AudioTrack.WRITE_BLOCKING)
                    if (written < 0) throw IOException("AudioTrack.write: $written")
                    if (written == 0) break
                    offset += written
                }
                // Si se ha quedado sin muestras, se le da más margen (suena
                // un poco más tarde, pero sin cortes).
                val count = track.underrunCount
                if (count > underruns) {
                    underruns = count
                    val size = track.bufferSizeInFrames
                    if (SystemClock.elapsedRealtime() > settledAt && size < track.bufferCapacityInFrames) {
                        track.bufferSizeInFrames = min(track.bufferCapacityInFrames, size + framesPerBurst)
                    }
                }
            }
        } catch (e: Exception) {
            // Se vuelve a crear con la siguiente nota.
        } finally {
            try {
                track.pause()
                track.flush()
                track.release()
            } catch (e: Exception) {
            }
        }
    }

    private fun createTrack(): AudioTrack {
        val format = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
            .setSampleRate(sampleRate)
            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
            .build()
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()
        val minBytes = max(
            AudioTrack.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_FLOAT),
            PianoMixer.BLOCK * 4,
        )
        val builder = AudioTrack.Builder()
            .setAudioAttributes(attributes)
            .setAudioFormat(format)
            .setTransferMode(AudioTrack.MODE_STREAM)
            // Margen para crecer si se queda sin muestras.
            .setBufferSizeInBytes(minBytes * 4)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
        }
        val track = builder.build()
        if (track.state != AudioTrack.STATE_INITIALIZED) {
            track.release()
            throw IOException("No se pudo crear el AudioTrack")
        }
        // Empieza con lo mínimo que pide el sistema, para que suene enseguida.
        track.bufferSizeInFrames = max(minBytes / 4, 2 * framesPerBurst)
        return track
    }

    private companion object {
        /** Lo que sigue la salida en marcha sin sonar nada. */
        const val IDLE_MS = 20_000L

        /** Lo que tarda la salida en asentarse al arrancar. */
        const val SETTLE_MS = 300L
    }
}

/** Las muestras (del primer canal) de un WAV PCM de 16 bits. */
private fun readSamples(file: File): ShortArray {
    val info = readWavInfo(file)
    val bytes = ByteArray(min(info.dataLength, Int.MAX_VALUE.toLong()).toInt())
    RandomAccessFile(file, "r").use { raf ->
        raf.seek(info.dataOffset)
        raf.readFully(bytes)
    }
    val all = ShortArray(bytes.size / 2)
    ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().get(all)
    if (info.channels == 1) return all
    return ShortArray(all.size / info.channels) { all[it * info.channels] }
}
