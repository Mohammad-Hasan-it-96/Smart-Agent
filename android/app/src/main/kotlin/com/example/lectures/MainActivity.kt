package com.example.lectures

import android.os.Bundle
import android.view.WindowManager.LayoutParams
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(LayoutParams.FLAG_SECURE) // يمنع تسجيل الشاشة وأخذ لقطات
        }
        }