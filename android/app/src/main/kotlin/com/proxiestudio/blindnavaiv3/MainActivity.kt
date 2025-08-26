/* 
package com.proxiestudio.blindnavaiv3

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel


class MainActivity : FlutterActivity() {
    private lateinit var cameraHandler: CameraXHandler

    private var recognizerHandler: SpeechRecognizerHandler? = null
    private var screenReceiver: BroadcastReceiver? = null
    private var methodChannel: MethodChannel? = null

    private val REQUEST_PERMISSIONS_CODE = 1001

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensurePermissions()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        cameraHandler = CameraXHandler(this)

        flutterEngine.platformViewsController.registry.registerViewFactory(
                "camera-preview-view",
                CameraPreviewFactory(cameraHandler)
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "camera_channel")
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "captureImage" -> {
                            cameraHandler.captureImage { byteArray ->
                                if (byteArray != null) {
                                    result.success(byteArray)
                                } else {
                                    result.error("CAPTURE_FAILED", "Image capture failed", null)
                                }
                            }
                        }
                        "startCamera" -> {
                            // cameraHandler = CameraXHandler(this)
                            cameraHandler.startCamera { bitmap -> }

                            result.success("Camera started")
                        }
                        "stopCamera" -> {
                            cameraHandler.stopCamera()
                            result.success("Camera stopped")
                        }
                        else -> result.notImplemented()
                    }
                }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "speech_channel")
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "startListening" -> {
                            if (hasAudioPermission()) {
                                recognizerHandler =
                                        SpeechRecognizerHandler(this) { spokenText ->
                                            result.success(spokenText ?: "")
                                        }
                                recognizerHandler?.startListening()
                            } else {
                                result.error(
                                        "PERMISSION_DENIED",
                                        "Microphone permission not granted",
                                        null
                                )
                                ensurePermissions()
                            }
                        }
                        "stopListening" -> {
                            recognizerHandler?.stop()
                            result.success(null)
                        }
                    }
                }
                // Screen on/off detection
        methodChannelScreen = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "screen_state")
        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    Intent.ACTION_SCREEN_OFF -> methodChannelScreen?.invokeMethod("screenOff", null)
                    Intent.ACTION_SCREEN_ON -> methodChannelScreen?.invokeMethod("screenOn", null)
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        registerReceiver(screenReceiver, filter)
    }

    // Detect hardware key events
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN) {
            val keyCode = event.keyCode
            android.util.Log.d("ClickerDebug", "Key pressed: $keyCode")
            methodChannelScreen?.invokeMethod("keyPressed", keyCode)
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onDestroy() {
        recognizerHandler?.stop()
        super.onDestroy()
    }

    private fun hasAudioPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
    }

    private fun hasCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun ensurePermissions() {
        val permissionsToRequest = mutableListOf<String>()

        if (!hasCameraPermission()) {
            permissionsToRequest.add(Manifest.permission.CAMERA)
        }

        if (!hasAudioPermission()) {
            permissionsToRequest.add(Manifest.permission.RECORD_AUDIO)
        }

        if (permissionsToRequest.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                this,
                permissionsToRequest.toTypedArray(),
                REQUEST_PERMISSIONS_CODE
            )
        }
    }
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_PERMISSIONS_CODE) {
            val deniedPermissions = permissions.zip(grantResults.toList())
                .filter { it.second != PackageManager.PERMISSION_GRANTED }
                .map { it.first }

            if (deniedPermissions.isNotEmpty()) {
            }
        }
    }
}
*/

package com.proxiestudio.blindnavaiv3

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.KeyEvent
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var cameraHandler: CameraXHandler
    private var recognizerHandler: SpeechRecognizerHandler? = null
    private var screenReceiver: BroadcastReceiver? = null
    private var methodChannelScreen: MethodChannel? = null

    private val REQUEST_PERMISSIONS_CODE = 1001

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensurePermissions()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        cameraHandler = CameraXHandler(this)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "camera-preview-view",
            CameraPreviewFactory(cameraHandler)
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "camera_channel")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "captureImage" -> cameraHandler.captureImage { byteArray ->
                        if (byteArray != null) result.success(byteArray)
                        else result.error("CAPTURE_FAILED", "Image capture failed", null)
                    }
                    "startCamera" -> {
                        cameraHandler.startCamera { bitmap -> }
                        result.success("Camera started")
                    }
                    "stopCamera" -> {
                        cameraHandler.stopCamera()
                        result.success("Camera stopped")
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "speech_channel")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startListening" -> {
                        if (hasAudioPermission()) {
                            recognizerHandler = SpeechRecognizerHandler(this) { spokenText ->
                                result.success(spokenText ?: "")
                            }
                            recognizerHandler?.startListening()
                        } else {
                            result.error("PERMISSION_DENIED", "Microphone permission not granted", null)
                            ensurePermissions()
                        }
                    }
                    "stopListening" -> {
                        recognizerHandler?.stop()
                        result.success(null)
                    }
                }
            }

        // Screen on/off detection
        methodChannelScreen = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "screen_state")
        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: android.content.Context?, intent: Intent?) {
                when (intent?.action) {
                    Intent.ACTION_SCREEN_OFF -> methodChannelScreen?.invokeMethod("screenOff", null)
                    Intent.ACTION_SCREEN_ON -> methodChannelScreen?.invokeMethod("screenOn", null)
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        registerReceiver(screenReceiver, filter)
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN) {
            val keyCode = event.keyCode
            android.util.Log.d("ClickerDebug", "Key pressed: $keyCode")
            methodChannelScreen?.invokeMethod("keyPressed", keyCode)
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onDestroy() {
        recognizerHandler?.stop()
        screenReceiver?.let { unregisterReceiver(it) }
        super.onDestroy()
    }

    private fun hasAudioPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    private fun hasCameraPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

    private fun ensurePermissions() {
        val permissionsToRequest = mutableListOf<String>()
        if (!hasCameraPermission()) permissionsToRequest.add(Manifest.permission.CAMERA)
        if (!hasAudioPermission()) permissionsToRequest.add(Manifest.permission.RECORD_AUDIO)

        if (permissionsToRequest.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                this,
                permissionsToRequest.toTypedArray(),
                REQUEST_PERMISSIONS_CODE
            )
        }
    }
}
