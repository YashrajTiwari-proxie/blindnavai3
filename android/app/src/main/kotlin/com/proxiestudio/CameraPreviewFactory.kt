package com.proxiestudio.blindnavaiv3

import android.content.Context
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec
import com.proxiestudio.blindnavaiv3.CameraPreview

class CameraPreviewFactory(
    private val cameraHandler: CameraXHandler
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return CameraPreview(context, cameraHandler)
    }
}
