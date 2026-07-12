package app.aoki.yuki.vagina

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NON_BACKUP_STORAGE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNonBackupStorageRoot" -> result.success(noBackupFilesDir.absolutePath)
                else -> result.notImplemented()
            }
        }
    }

    private companion object {
        const val NON_BACKUP_STORAGE_CHANNEL =
            "app.aoki.yuki.vagina/non_backup_storage"
    }
}
