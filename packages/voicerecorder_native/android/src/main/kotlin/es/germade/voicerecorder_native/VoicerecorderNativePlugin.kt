package es.germade.voicerecorder_native

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** Registra los canales de conversión de audio y de acceso a carpetas. */
class VoicerecorderNativePlugin : FlutterPlugin, ActivityAware {
    private var codecChannel: MethodChannel? = null
    private var foldersChannel: MethodChannel? = null
    private var folders: FolderAccess? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        codecChannel = MethodChannel(binding.binaryMessenger, CODEC_CHANNEL).apply {
            setMethodCallHandler(AudioCodecHandler())
        }
        val folderAccess = FolderAccess(binding.applicationContext)
        folders = folderAccess
        foldersChannel = MethodChannel(binding.binaryMessenger, FOLDERS_CHANNEL).apply {
            setMethodCallHandler(folderAccess)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        codecChannel?.setMethodCallHandler(null)
        codecChannel = null
        foldersChannel?.setMethodCallHandler(null)
        foldersChannel = null
        folders = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        folders?.attach(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        folders?.detach()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        folders?.attach(binding)
    }

    override fun onDetachedFromActivity() {
        folders?.detach()
    }

    private companion object {
        const val CODEC_CHANNEL = "es.germade.voicerecorder/audio_codec"
        const val FOLDERS_CHANNEL = "es.germade.voicerecorder/folders"
    }
}

/** Ejecuta tareas en un hilo propio y devuelve el resultado en el principal. */
internal class BackgroundRunner {
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    fun run(result: MethodChannel.Result, task: () -> Any?) {
        executor.execute {
            try {
                val value = task()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("failed", e.message ?: e.javaClass.simpleName, null)
                }
            }
        }
    }
}
