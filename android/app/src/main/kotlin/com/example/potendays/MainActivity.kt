package com.example.potendays

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "potendays/config"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "googleMapsApiKey" -> result.success(readGoogleMapsApiKey())
                else -> result.notImplemented()
            }
        }
    }

    private fun readGoogleMapsApiKey(): String {
        val applicationInfo = packageManager.getApplicationInfo(
            packageName,
            PackageManager.GET_META_DATA
        )

        return applicationInfo.metaData
            ?.getString("com.google.android.geo.API_KEY")
            .orEmpty()
    }
}
