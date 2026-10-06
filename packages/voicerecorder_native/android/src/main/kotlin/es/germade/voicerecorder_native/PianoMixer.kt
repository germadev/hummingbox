package es.germade.voicerecorder_native

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min

/**
 * Mezcla las notas del piano en un solo flujo de audio, sin chasquidos.
 *
 * Cada nota es el sonido de su tecla (muestras de 16 bits, mono, a la
 * frecuencia de la salida), que ya empieza y termina en silencio. Una tecla
 * suena una sola vez: al volver a tocarla, la nota anterior se apaga en
 * [CUT_FADE_MS] en vez de cortarse. Al soltarla o pararla, su volumen baja
 * muestra a muestra. Lo que suenan juntas no pasa de [CEILING]: el volumen de
 * todas baja con una curva suave a lo largo del trozo ([BLOCK] fotogramas)
 * anterior al que se pasaría, y vuelve poco a poco ([LIMIT_RELEASE_MS]). Por
 * eso la salida va un trozo por detrás.
 *
 * No es seguro entre hilos: lo usa solo el hilo del audio.
 */
internal class PianoMixer(sampleRate: Int) {
    private class Voice(val key: Int, val samples: ShortArray) {
        var position = 0
        var gain = 1f

        /** Lo que baja [gain] en cada fotograma (al apagarse). */
        var fade = 0f
    }

    private val voices = ArrayList<Voice>()

    /** Fotogramas en los que se apaga una nota al volver a tocar su tecla. */
    val cutFadeFrames = max(1, sampleRate * CUT_FADE_MS / 1000)

    /** Lo que puede subir el volumen de un trozo al siguiente. */
    private val releaseStep = BLOCK / (sampleRate * LIMIT_RELEASE_MS / 1000f)

    /** El trozo que sale después: mezclado, sin limitar, y su pico. */
    private var pending = FloatArray(BLOCK)
    private var pendingPeak = 0f

    /** El trozo siguiente, para saber cómo acaba el volumen de [pending]. */
    private var next = FloatArray(BLOCK)

    /** Volumen al principio de [pending]. */
    private var gain = 1f

    /** Lo que sale, ya limitado, por dónde va y si suena algo. */
    private val output = FloatArray(BLOCK)
    private var outputPosition = BLOCK
    private var outputSilent = true

    /** Si no suena nada ni queda nada por salir. */
    val isIdle: Boolean
        get() = voices.isEmpty() && pendingPeak == 0f && outputSilent

    /** Suena la tecla [key] con [samples]; si ya sonaba, la anterior se apaga. */
    fun play(key: Int, samples: ShortArray) {
        fadeOut(key, cutFadeFrames)
        if (voices.size >= MAX_VOICES) {
            // Sin sitio: se apaga la que lleva más tiempo sonando.
            voices.firstOrNull { it.fade == 0f }?.let { fadeOut(it, cutFadeFrames) }
            if (voices.size >= MAX_VOICES * 2) voices.removeAt(0)
        }
        voices.add(Voice(key, samples))
    }

    /** La tecla [key] se apaga en [frames] fotogramas. */
    fun fadeOut(key: Int, frames: Int) {
        for (voice in voices) {
            if (voice.key == key && voice.fade == 0f) fadeOut(voice, frames)
        }
    }

    /** Todas las notas se apagan enseguida. */
    fun stopAll() {
        for (voice in voices) {
            if (voice.fade == 0f) fadeOut(voice, cutFadeFrames)
        }
    }

    private fun fadeOut(voice: Voice, frames: Int) {
        voice.fade = voice.gain / max(1, frames)
    }

    /** Escribe en [out] [frames] fotogramas desde [offset], entre −1 y 1. */
    fun render(out: FloatArray, offset: Int, frames: Int) {
        var written = 0
        while (written < frames) {
            if (outputPosition == BLOCK) nextBlock()
            val count = min(frames - written, BLOCK - outputPosition)
            System.arraycopy(output, outputPosition, out, offset + written, count)
            outputPosition += count
            written += count
        }
    }

    /** Mezcla el trozo siguiente y deja en [output] el que sale, limitado. */
    private fun nextBlock() {
        val nextPeak = mix(next)
        // El volumen al final de este trozo (y al principio del siguiente) no
        // pasa del que necesitan los dos, y sube poco a poco.
        val end = min(min(limitOf(pendingPeak), limitOf(nextPeak)), gain + releaseStep)
        val start = gain
        for (i in 0 until BLOCK) {
            val value = pending[i] * (start + (end - start) * RAMP[i])
            output[i] = if (value > 1f) 1f else if (value < -1f) -1f else value
        }
        outputPosition = 0
        outputSilent = pendingPeak == 0f
        val done = pending
        pending = next
        pendingPeak = nextPeak
        next = done
        gain = end
    }

    private fun limitOf(peak: Float) = if (peak > CEILING) CEILING / peak else 1f

    /** Suma en [into] lo que suenan las notas en un trozo y devuelve su pico. */
    private fun mix(into: FloatArray): Float {
        into.fill(0f)
        var index = 0
        while (index < voices.size) {
            val voice = voices[index]
            val samples = voice.samples
            val count = min(BLOCK, samples.size - voice.position)
            var gain = voice.gain
            val fade = voice.fade
            var ended = false
            for (i in 0 until count) {
                if (fade != 0f) {
                    gain -= fade
                    if (gain <= 0f) {
                        ended = true
                        break
                    }
                }
                into[i] += samples[voice.position + i] * gain * SCALE
            }
            voice.gain = gain
            voice.position += max(0, count)
            if (ended || voice.position >= samples.size) {
                voices.removeAt(index)
            } else {
                index++
            }
        }
        var peak = 0f
        for (value in into) peak = max(peak, abs(value))
        return peak
    }

    companion object {
        /** Pico al que se limita lo que suenan juntas (del máximo). */
        const val CEILING = 0.9f

        /** Fotogramas de cada trozo: lo que va por detrás la salida. */
        const val BLOCK = 256

        /** Lo que tarda en apagarse una nota al volver a tocar su tecla. */
        const val CUT_FADE_MS = 10

        /** Lo que tarda el volumen en volver del todo al dejar de limitar. */
        const val LIMIT_RELEASE_MS = 300

        /** Notas que pueden sonar a la vez. */
        const val MAX_VOICES = 64

        private const val SCALE = 1f / 32768f

        /** De 0 a 1 a lo largo de un trozo, con una curva suave. */
        private val RAMP = FloatArray(BLOCK) { ((1 - cos(PI * (it + 1) / BLOCK)) / 2).toFloat() }
    }
}
