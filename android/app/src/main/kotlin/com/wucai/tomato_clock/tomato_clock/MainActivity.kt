package com.wucai.tomato_clock

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "tomato_clock/native"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "appDataDirectory" -> {
                    result.success(filesDir.absolutePath)
                }

                "canDrawOverlays" -> {
                    result.success(Settings.canDrawOverlays(this))
                }

                "openOverlaySettings" -> {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")
                    )
                    startActivity(intent)
                    result.success(null)
                }

                "startOverlay", "updateOverlay" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val arguments = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    TomatoOverlayService.show(this, arguments)
                    result.success(true)
                }

                "stopOverlay" -> {
                    TomatoOverlayService.stop(this)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}
