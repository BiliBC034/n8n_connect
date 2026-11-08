package me.bilibc.n8n_connect

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    // Text shared from another app ("Share → n8n Connect"), until Dart takes it.
    private var pendingShare: Map<String, String?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "me.bilibc.n8n_connect/system")
            .also {
                it.setMethodCallHandler { call, result ->
                    when (call.method) {
                        // Back to the background after running an action from a notification button.
                        "moveTaskToBack" -> result.success(moveTaskToBack(true))
                        "takeSharedContent" -> {
                            result.success(pendingShare)
                            pendingShare = null
                        }
                        // launch_app: the package's own launcher intent (needs the
                        // MAIN/LAUNCHER <queries> entry to see other apps on Android 11+).
                        "launchApp" -> {
                            val pkg = call.argument<String>("package")
                            val launch = pkg?.let { packageManager.getLaunchIntentForPackage(it) }
                            if (launch == null) {
                                result.success(false)
                            } else {
                                startActivity(launch)
                                result.success(true)
                            }
                        }
                        else -> result.notImplemented()
                    }
                }
            }
        captureShare(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (captureShare(intent)) channel?.invokeMethod("shareReceived", null)
    }

    private fun captureShare(intent: Intent?): Boolean {
        if (intent?.action != Intent.ACTION_SEND) return false
        if (intent.type?.startsWith("text/") != true) return false
        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return false
        pendingShare = mapOf(
            "text" to text,
            "subject" to intent.getStringExtra(Intent.EXTRA_SUBJECT),
        )
        // Handled: don't capture it again when the activity is recreated.
        intent.action = null
        return true
    }
}
