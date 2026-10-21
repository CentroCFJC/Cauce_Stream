package com.cauce.cauce_stream

import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "cauce_stream/device"
    private val powerChannelName = "cauce.power/power"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceName" -> {
                        // Nombre configurado del dispositivo, tal cual lo
                        // expone el SO; en TV boxes suele venir vacío y se
                        // usa el modelo como fallback.
                        val name = Settings.Global.getString(
                            contentResolver,
                            "device_name"
                        ) ?: Build.MODEL
                        result.success(name)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, powerChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "wakeScreen" -> {
                        // Encender la pantalla (action "on"). La app sigue
                        // ejecutándose con la pantalla en espera (los
                        // heartbeats siguen llegando), así que el canal
                        // atiende el comando aunque la activity esté
                        // pausada. Idempotente: pantalla ya encendida es
                        // éxito.
                        wakeScreen()
                        result.success(true)
                    }
                    "enterStandby" -> {
                        // Android NO ofrece API pública para que una app
                        // ponga la pantalla en espera (goToSleep /
                        // KEYCODE_SLEEP requieren permisos de firma
                        // DEVICE_POWER / INJECT_EVENTS). Se declara
                        // explícitamente como no soportado (false): el
                        // cliente responde power.error/standby_denied.
                        // Sin workarounds (overlay negro, etc.).
                        result.success(false)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Enciende la pantalla desde código. Con la activity pausada la
    /// ruta fiable es un wake lock con ACQUIRE_CAUSES_WAKEUP (API
    /// pública, permiso normal WAKE_LOCK); los flags de activity
    /// aseguran que la app sea lo que se muestre al volver la pantalla.
    /// El wake lock se libera solo por timeout: solo enciende, no se
    /// retiene.
    private fun wakeScreen() {
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        if (powerManager.isInteractive) return

        @Suppress("DEPRECATION")
        val wakeLock = powerManager.newWakeLock(
            PowerManager.FULL_WAKE_LOCK
                or PowerManager.ACQUIRE_CAUSES_WAKEUP
                or PowerManager.ON_AFTER_RELEASE,
            "cauce:power:wake"
        )
        wakeLock.acquire(3_000L)

        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setTurnScreenOn(true)
                setShowWhenLocked(true)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                        or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                )
            }
        }
    }
}
