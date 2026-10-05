package es.germade.voicerecorder_native

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Registra los canales de conversión de audio, de acceso a carpetas y de la
 * pantalla.
 */
class VoicerecorderNativePlugin : FlutterPlugin, ActivityAware {
    private var codecChannel: MethodChannel? = null
    private var foldersChannel: MethodChannel? = null
    private var screenChannel: MethodChannel? = null
    private var folders: FolderAccess? = null
    private val screen = ScreenAwake()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        codecChannel = MethodChannel(binding.binaryMessenger, CODEC_CHANNEL).apply {
            setMethodCallHandler(AudioCodecHandler())
        }
        val folderAccess = FolderAccess(binding.applicationContext)
        folders = folderAccess
        foldersChannel = MethodChannel(binding.binaryMessenger, FOLDERS_CHANNEL).apply {
            setMethodCallHandler(folderAccess)
        }
        screenChannel = MethodChannel(binding.binaryMessenger, SCREEN_CHANNEL).apply {
            setMethodCallHandler(screen)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        codecChannel?.setMethodCallHandler(null)
        codecChannel = null
        foldersChannel?.setMethodCallHandler(null)
        foldersChannel = null
        folders = null
        screenChannel?.setMethodCallHandler(null)
        screenChannel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        folders?.attach(binding)
        screen.attach(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        folders?.detach()
        screen.detach()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        folders?.attach(binding)
        screen.attach(binding.activity)
    }

    override fun onDetachedFromActivity() {
        folders?.detach()
        screen.detach()
    }

    private companion object {
        const val CODEC_CHANNEL = "es.germade.voicerecorder/audio_codec"
        const val FOLDERS_CHANNEL = "es.germade.voicerecorder/folders"
        const val SCREEN_CHANNEL = "es.germade.voicerecorder/screen"
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
            } catch (e: SecurityException) {
                // Se retiró el permiso sobre la carpeta.
                mainHandler.post {
                    result.error("no_permission", e.message ?: e.javaClass.simpleName, null)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("failed", e.message ?: e.javaClass.simpleName, null)
                }
            }
        }
    }
}
