package com.proxiestudio.blindnavaiv3

import android.content.Context
import android.graphics.*
import android.util.Log
import android.view.Surface
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import java.io.ByteArrayOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class CameraXHandler(private val context: Context) {
    private var cameraProvider: ProcessCameraProvider? = null
    private var imageCapture: ImageCapture? = null
    private lateinit var cameraExecutor: ExecutorService

    private var previewView: PreviewView = PreviewView(context)

    fun getPreviewView(): PreviewView {
        return previewView
    }

    fun startCamera(onImageCaptured: (Bitmap) -> Unit) {
        cameraExecutor = Executors.newSingleThreadExecutor()

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener(
                {
                    cameraProvider = cameraProviderFuture.get()

                    val preview =
                            Preview.Builder().build().also {
                                it.setSurfaceProvider(previewView.surfaceProvider)
                            }

                    val rotation =
                            try {
                                previewView.display?.rotation ?: Surface.ROTATION_0
                            } catch (e: Exception) {
                                Surface.ROTATION_0
                            }

                    imageCapture = ImageCapture.Builder().setTargetRotation(rotation).build()

                    val imageAnalyzer =
                            ImageAnalysis.Builder()
                                    .setBackpressureStrategy(
                                            ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST
                                    )
                                    .build()
                                    .also {
                                        it.setAnalyzer(cameraExecutor) { imageProxy ->
                                            val bitmap = imageProxyToBitmap(imageProxy)
                                            onImageCaptured(bitmap)
                                            imageProxy.close()
                                        }
                                    }

                    try {
                        cameraProvider?.unbindAll()
                        cameraProvider?.bindToLifecycle(
                                context as LifecycleOwner,
                                CameraSelector.DEFAULT_BACK_CAMERA,
                                preview,
                                imageCapture,
                                imageAnalyzer
                        )
                    } catch (e: Exception) {
                        Log.e("CameraX", "Use case binding failed", e)
                    }
                },
                ContextCompat.getMainExecutor(context)
        )
    }

    fun stopCamera() {
        cameraProvider?.unbindAll()
        if (::cameraExecutor.isInitialized) {
            cameraExecutor.shutdown()
        }
    }

    fun captureImage(result: (ByteArray?) -> Unit) {
        val imageCapture = this.imageCapture ?: return result(null)

        imageCapture.takePicture(
                ContextCompat.getMainExecutor(context),
                object : ImageCapture.OnImageCapturedCallback() {
                    override fun onCaptureSuccess(imageProxy: ImageProxy) {
                        val bitmap = jpegFromImageProxy(imageProxy)
                        val stream = ByteArrayOutputStream()
                        bitmap?.compress(Bitmap.CompressFormat.JPEG, 100, stream)
                        result(stream.toByteArray())
                        imageProxy.close()
                    }

                    override fun onError(exception: ImageCaptureException) {
                        Log.e("CameraX", "Capture failed: ${exception.message}", exception)
                        result(null)
                    }
                }
        )
    }

    private fun jpegFromImageProxy(imageProxy: ImageProxy): Bitmap? {
        return try {
            val buffer = imageProxy.planes[0].buffer
            val bytes = ByteArray(buffer.remaining())
            buffer.get(bytes)
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } catch (e: Exception) {
            Log.e("CameraX", "Failed to convert imageProxy to bitmap", e)
            null
        }
    }

    private fun imageProxyToBitmap(image: ImageProxy): Bitmap {
        val yBuffer = image.planes[0].buffer
        val uBuffer = image.planes[1].buffer
        val vBuffer = image.planes[2].buffer

        val ySize = yBuffer.remaining()
        val uSize = uBuffer.remaining()
        val vSize = vBuffer.remaining()

        val nv21 = ByteArray(ySize + uSize + vSize)

        yBuffer.get(nv21, 0, ySize)
        vBuffer.get(nv21, ySize, vSize)
        uBuffer.get(nv21, ySize + vSize, uSize)

        val yuvImage = YuvImage(nv21, ImageFormat.NV21, image.width, image.height, null)
        val out = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, image.width, image.height), 100, out)
        val jpegBytes = out.toByteArray()

        return BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)
    }
}
