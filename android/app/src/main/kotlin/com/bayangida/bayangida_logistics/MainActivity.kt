package com.bayangida.bayangida_logistics

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Workaround for text input crash
        intent.putExtra("enable-software-rendering", false)
        super.onCreate(savedInstanceState)
    }
}

