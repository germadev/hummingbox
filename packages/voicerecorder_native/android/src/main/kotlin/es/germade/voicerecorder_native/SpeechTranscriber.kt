package es.germade.voicerecorder_native

import android.annotation.TargetApi
import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.os.Build
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.util.Locale

/**
 * Transcribe archivos de audio con el reconocimiento de voz del sistema, en el
 * dispositivo. Necesita Android 13 o superior (para darle un archivo en vez
 * del micrófono) y un reconocedor en el dispositivo con el idioma descargado.
 *
 * El audio llega como un WAV PCM de 16 bits y un canal; se le pasa al
 * reconocedor por una tubería, en una sesión segmentada para que admita
 * grabaciones largas. Todo se llama desde el hilo principal.
 */
internal class SpeechTranscriber(private val context: Context) : MethodChannel.MethodCallHandler {
    private var session: Session? = null

    /** Reconocedor de la última descarga de idioma pedida. */
    private var downloader: SpeechRecognizer? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "check" -> {
                val language = call.argument<String>("language") ?: return badArgs(result)
                check(language, result)
            }
            "download" -> {
                val language = call.argument<String>("language") ?: return badArgs(result)
                if (isSupported()) download(language)
                result.success(null)
            }
            "transcribe" -> {
                val path = call.argument<String>("path") ?: return badArgs(result)
                val language = call.argument<String>("language") ?: return badArgs(result)
                val dataOffset = call.argument<Int>("dataOffset") ?: 44
                val sampleRate = call.argument<Int>("sampleRate") ?: 16000
                when {
                    session != null -> result.error("busy", "Ya se está transcribiendo", null)
                    !isSupported() -> result.error("unavailable", "Sin reconocedor en el dispositivo", null)
                    else -> transcribe(File(path), language, dataOffset.toLong(), sampleRate, result)
                }
            }
            "progress" -> result.success(session?.progress ?: 0.0)
            "cancel" -> {
                session?.cancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        session?.cancel()
        downloader?.destroy()
        downloader = null
    }

    private fun badArgs(result: MethodChannel.Result) =
        result.error("bad_args", "Faltan argumentos", null)

    private fun isSupported() =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)

    /**
     * Indica si se puede transcribir en [language] y con qué variante (p. ej.
     * «es-ES» para «es»): `available`, `downloading` (se está descargando),
     * `download` (hay que descargarlo), `language` (no lo admite),
     * `unavailable` (sin reconocedor) o `unknown` (el reconocedor no lo dice).
     */
    private fun check(language: String, result: MethodChannel.Result) {
        if (!isSupported()) {
            result.success(mapOf("status" to "unavailable"))
            return
        }
        querySupport(language) { status, tag ->
            result.success(mapOf("status" to status, "language" to tag))
        }
    }

    @TargetApi(Build.VERSION_CODES.TIRAMISU)
    private fun querySupport(language: String, done: (String, String?) -> Unit) {
        val recognizer = try {
            SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        } catch (e: Exception) {
            done("unavailable", null)
            return
        }
        recognizer.checkRecognitionSupport(
            recognizeIntent(language),
            context.mainExecutor,
            object : RecognitionSupportCallback {
                override fun onSupportResult(support: RecognitionSupport) {
                    recognizer.destroy()
                    val installed = bestMatch(language, support.installedOnDeviceLanguages)
                    val pending = bestMatch(language, support.pendingOnDeviceLanguages)
                    val supported = bestMatch(language, support.supportedOnDeviceLanguages)
                    when {
                        installed != null -> done("available", installed)
                        pending != null -> done("downloading", pending)
                        supported != null -> done("download", supported)
                        else -> done("language", null)
                    }
                }

                override fun onError(error: Int) {
                    recognizer.destroy()
                    // Algunos reconocedores no saben responder: se intenta igual.
                    if (error == SpeechRecognizer.ERROR_CANNOT_CHECK_SUPPORT) {
                        done("unknown", language)
                    } else {
                        done("unavailable", null)
                    }
                }
            },
        )
    }

    /** Pide al sistema que descargue [language] (muestra su propio aviso). */
    @TargetApi(Build.VERSION_CODES.TIRAMISU)
    private fun download(language: String) {
        downloader?.destroy()
        downloader = SpeechRecognizer.createOnDeviceSpeechRecognizer(context).also {
            it.triggerModelDownload(recognizeIntent(language))
        }
    }

    @TargetApi(Build.VERSION_CODES.TIRAMISU)
    private fun transcribe(
        file: File,
        language: String,
        dataOffset: Long,
        sampleRate: Int,
        result: MethodChannel.Result,
    ) {
        val (readEnd, writeEnd) = ParcelFileDescriptor.createPipe()
        val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        val current = Session(recognizer, result, readEnd, file.length() - dataOffset)
        session = current
        recognizer.setRecognitionListener(current)

        // Las muestras, sin la cabecera del WAV, se escriben en la tubería a
        // medida que el reconocedor las lee.
        Thread {
            try {
                FileInputStream(file).use { input ->
                    var skipped = 0L
                    while (skipped < dataOffset) {
                        val n = input.skip(dataOffset - skipped)
                        if (n <= 0) break
                        skipped += n
                    }
                    ParcelFileDescriptor.AutoCloseOutputStream(writeEnd).use { output ->
                        val buffer = ByteArray(16 * 1024)
                        while (!current.cancelled) {
                            val n = input.read(buffer)
                            if (n < 0) break
                            output.write(buffer, 0, n)
                            current.written += n
                        }
                    }
                }
            } catch (e: IOException) {
                // El reconocedor cerró la tubería (p. ej. por un error).
                runCatching { writeEnd.close() }
            }
        }.start()

        val intent = recognizeIntent(language).apply {
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, readEnd)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, sampleRate)
            // Sigue hasta que se acabe el audio, en vez de parar en el primer
            // silencio.
            putExtra(RecognizerIntent.EXTRA_SEGMENTED_SESSION, RecognizerIntent.EXTRA_AUDIO_SOURCE)
        }
        recognizer.startListening(intent)
    }

    private fun recognizeIntent(language: String) =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // Con mayúsculas y signos de puntuación.
                putExtra(
                    RecognizerIntent.EXTRA_ENABLE_FORMATTING,
                    RecognizerIntent.FORMATTING_OPTIMIZE_QUALITY,
                )
            }
        }

    /** Una transcripción en curso. */
    private inner class Session(
        private val recognizer: SpeechRecognizer,
        private val result: MethodChannel.Result,
        private val readEnd: ParcelFileDescriptor,
        private val total: Long,
    ) : RecognitionListener {
        @Volatile var written = 0L
        @Volatile var cancelled = false
        private val segments = mutableListOf<String>()
        private var finished = false

        /** Parte del audio que ya ha leído el reconocedor (0–1). */
        val progress: Double
            get() = if (total > 0) (written.toDouble() / total).coerceIn(0.0, 1.0) else 0.0

        fun cancel() {
            cancelled = true
            recognizer.cancel()
            finish { it.error("canceled", "Transcripción cancelada", null) }
        }

        private fun finish(reply: (MethodChannel.Result) -> Unit) {
            if (finished) return
            finished = true
            if (session === this) session = null
            recognizer.destroy()
            runCatching { readEnd.close() }
            reply(result)
        }

        private fun text() = segments.joinToString(" ")

        private fun add(bundle: Bundle?) {
            bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?.firstOrNull()
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
                ?.let(segments::add)
        }

        override fun onSegmentResults(segmentResults: Bundle) = add(segmentResults)

        override fun onEndOfSegmentedSession() = finish { it.success(text()) }

        override fun onResults(results: Bundle?) {
            add(results)
            finish { it.success(text()) }
        }

        override fun onError(error: Int) {
            when (error) {
                // Sin voz (o sin más voz): lo reconocido hasta ahora.
                SpeechRecognizer.ERROR_NO_MATCH,
                SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
                -> finish { it.success(text()) }
                SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED,
                SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE,
                -> finish { it.error("language", "Idioma no disponible ($error)", null) }
                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
                    finish { it.error("permission", "Falta el permiso del micrófono", null) }
                SpeechRecognizer.ERROR_RECOGNIZER_BUSY ->
                    finish { it.error("busy", "El reconocedor está ocupado", null) }
                else -> finish { it.error("failed", "Error del reconocedor ($error)", null) }
            }
        }

        override fun onReadyForSpeech(params: Bundle?) {}

        override fun onBeginningOfSpeech() {}

        override fun onRmsChanged(rmsdB: Float) {}

        override fun onBufferReceived(buffer: ByteArray?) {}

        override fun onEndOfSpeech() {}

        override fun onPartialResults(partialResults: Bundle?) {}

        override fun onEvent(eventType: Int, params: Bundle?) {}
    }

    private companion object {
        /** Idioma de una etiqueta («cmn-Hans-CN», el chino mandarín, es «zh»). */
        fun languageOf(tag: String): String =
            Locale.forLanguageTag(tag).language.let { if (it == "cmn") "zh" else it }

        /**
         * La variante de [available] que mejor encaja con [language]: la misma
         * etiqueta, el mismo idioma con la región del dispositivo o, si no, la
         * primera del mismo idioma.
         */
        fun bestMatch(language: String, available: List<String>): String? {
            val wanted = Locale.forLanguageTag(language)
            val code = languageOf(language)
            val region = wanted.country.ifEmpty { Locale.getDefault().country }
            val sameLanguage = available.filter { languageOf(it) == code }
            return sameLanguage.firstOrNull { it.equals(language, ignoreCase = true) }
                ?: sameLanguage.firstOrNull {
                    Locale.forLanguageTag(it).country.equals(region, ignoreCase = true)
                }
                ?: sameLanguage.firstOrNull()
        }
    }
}
