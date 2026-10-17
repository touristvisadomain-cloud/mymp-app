package bd.mymp.app

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Whether this build carries a Google Maps key (lib/maps/google.dart):
        // without one the Maps SDK cannot show a map, so the app draws its own.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bd.mymp.app/maps")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasKey" -> result.success(hasMapsKey())
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasMapsKey(): Boolean = try {
        @Suppress("DEPRECATION")
        val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        val key = info.metaData?.getString("com.google.android.geo.API_KEY")?.trim()
        !key.isNullOrEmpty() && !key.startsWith("\${")
    } catch (e: Exception) {
        false
    }
}
