package es.germade.voicerecorder_native

import android.app.Activity
import android.view.WindowManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Mantiene la pantalla encendida mientras la app lo pide (p. ej. mientras se
 * graba). Solo afecta a la ventana de la app: al salir de ella, la pantalla
 * se apaga como siempre.
 */
internal class ScreenAwake : MethodChannel.MethodCallHandler {
    private var activity: Activity? = null
    private var keepOn = false

    fun attach(activity: Activity) {
        this.activity = activity
        apply()
    }

    fun detach() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "keepOn" -> {
                keepOn = call.argument<Boolean>("on") ?: false
                apply()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun apply() {
        val window = activity?.window ?: return
        if (keepOn) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}
