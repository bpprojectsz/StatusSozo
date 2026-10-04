package com.zdmgold.statussozo

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var handler: SafChannelHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val created = SafChannelHandler(this)
        handler = created
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SafChannelHandler.CHANNEL)
            .setMethodCallHandler(created)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        handler?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        handler?.dispose()
        handler = null
        super.onDestroy()
    }
}
