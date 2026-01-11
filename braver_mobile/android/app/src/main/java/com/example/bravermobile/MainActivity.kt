package com.example.bravermobile

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onPause() {
        // Do NOT call super.onPause() here.  This avoids calling webView.onPause(),
        // allowing background media playback to continue.
    }
}
