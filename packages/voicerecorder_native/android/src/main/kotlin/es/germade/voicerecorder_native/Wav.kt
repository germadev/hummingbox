package es.germade.voicerecorder_native

import java.io.Closeable
import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Formato y posición de las muestras de un WAV PCM de 16 bits. */
internal class WavInfo(
    val sampleRate: Int,
    val channels: Int,
    val dataOffset: Long,
    val dataLength: Long,
)

/** Lee la cabecera de un WAV PCM de 16 bits, recorriendo todos sus bloques. */
internal fun readWavInfo(file: File): WavInfo {
    RandomAccessFile(file, "r").use { raf ->
        val length = raf.length()
        val riff = ByteArray(12)
        raf.readFully(riff)
        if (fourCC(riff, 0) != "RIFF" || fourCC(riff, 8) != "WAVE") {
            throw IOException("No es un archivo WAV")
        }

        var sampleRate = 0
        var channels = 0
        var offset = 12L
        val chunk = ByteArray(8)
        while (offset + 8 <= length) {
            raf.seek(offset)
            raf.readFully(chunk)
            val id = fourCC(chunk, 0)
            val size = ByteBuffer.wrap(chunk, 4, 4).order(ByteOrder.LITTLE_ENDIAN).int.toLong() and
                0xFFFFFFFFL
            val body = offset + 8
            when (id) {
                "fmt " -> {
                    val fmt = ByteArray(16)
                    raf.readFully(fmt)
                    val buffer = ByteBuffer.wrap(fmt).order(ByteOrder.LITTLE_ENDIAN)
                    val tag = buffer.getShort(0).toInt() and 0xFFFF
                    channels = buffer.getShort(2).toInt() and 0xFFFF
                    sampleRate = buffer.getInt(4)
                    val bits = buffer.getShort(14).toInt() and 0xFFFF
                    if ((tag != 1 && tag != 0xFFFE) || bits != 16 || channels < 1 || sampleRate < 1) {
                        throw IOException("Formato WAV no admitido")
                    }
                }
                "data" -> {
                    if (sampleRate == 0) throw IOException("El WAV no tiene bloque fmt")
                    // Si el tamaño no llegó a escribirse, se usa el resto del archivo.
                    val dataLength =
                        if (size == 0L || size == 0xFFFFFFFFL || body + size > length) length - body else size
                    return WavInfo(sampleRate, channels, body, dataLength)
                }
            }
            offset = body + size + (size and 1L)
        }
        throw IOException("El WAV no tiene datos de audio")
    }
}

private fun fourCC(bytes: ByteArray, offset: Int) = String(bytes, offset, 4, Charsets.US_ASCII)

/** Escribe un WAV PCM de 16 bits. La cabecera se completa en [finish]. */
internal class WavWriter(file: File) : Closeable {
    private val raf = RandomAccessFile(file, "rw").apply {
        setLength(0)
        write(ByteArray(HEADER_SIZE))
    }
    private val channel = raf.channel
    private var dataBytes = 0L

    fun write(buffer: ByteBuffer) {
        while (buffer.hasRemaining()) {
            dataBytes += channel.write(buffer)
        }
    }

    fun finish(sampleRate: Int, channels: Int) {
        val blockAlign = channels * 2
        val header = ByteBuffer.allocate(HEADER_SIZE).order(ByteOrder.LITTLE_ENDIAN).apply {
            put("RIFF".toByteArray(Charsets.US_ASCII))
            putInt((36 + dataBytes).toInt())
            put("WAVE".toByteArray(Charsets.US_ASCII))
            put("fmt ".toByteArray(Charsets.US_ASCII))
            putInt(16)
            putShort(1)
            putShort(channels.toShort())
            putInt(sampleRate)
            putInt(sampleRate * blockAlign)
            putShort(blockAlign.toShort())
            putShort(16)
            put("data".toByteArray(Charsets.US_ASCII))
            putInt(dataBytes.toInt())
        }
        raf.seek(0)
        raf.write(header.array())
    }

    override fun close() = raf.close()

    private companion object {
        const val HEADER_SIZE = 44
    }
}
