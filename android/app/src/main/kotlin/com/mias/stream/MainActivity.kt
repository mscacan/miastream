package com.mias.stream

import android.app.PictureInPictureParams
import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var filled = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mias/outside")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enter" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val params = PictureInPictureParams.Builder()
                                .setAspectRatio(Rational(16, 9))
                                .build()
                            val entered = enterPictureInPictureMode(params)
                            result.success(if (entered) "activity" else "none")
                        } else {
                            result.success("none")
                        }
                    }
                    "bars" -> {
                        val hide = call.argument<Boolean>("hide") == true
                        runOnUiThread { hideSystemBars(hide) }
                        result.success(null)
                    }
                    "full" -> {
                        filled = !filled
                        runOnUiThread { hideSystemBars(filled) }
                        result.success(filled)
                    }
                    "isTv" -> result.success(isTelevision())
                    "exit" -> result.success(null)
                    else -> result.notImplemented()
                }
            }
    }

    private fun isTelevision(): Boolean {
        val modes = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        if (modes?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) {
            return true
        }
        return packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            !packageManager.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN)
    }

    private fun hideSystemBars(hide: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val controller = window.insetsController ?: return
            val types = WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars()
            if (hide) {
                controller.hide(types)
                controller.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            } else {
                controller.show(types)
            }
            return
        }
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = if (hide) {
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
        } else {
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        }
    }
}
