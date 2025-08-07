package com.proxiestudio.blindnavaiv3

import android.content.Context
import android.view.View
import androidx.camera.view.PreviewView
import io.flutter.plugin.platform.PlatformView

class CameraPreview(
    context: Context,
    private val cameraHandler: CameraXHandler
) : PlatformView {

    private val previewView: PreviewView = cameraHandler.getPreviewView()

    override fun getView(): View {
        return previewView
    }

    override fun dispose() {
        // Optional: Clean up
    }
}
