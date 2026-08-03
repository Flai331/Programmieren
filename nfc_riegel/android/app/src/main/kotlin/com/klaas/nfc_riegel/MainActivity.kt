package com.klaas.nfc_riegel

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Zustand nach App-Start begradigen: abgelaufener Timer wird sofort aufgelöst.
        LockController(this).expire()
        RiegelChannel(this).register(flutterEngine.dartExecutor.binaryMessenger)
    }
}
