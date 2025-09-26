package com.example.fmark_camera

import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.ImageFormat
import android.media.MediaRecorder
import android.util.Log
import android.util.Size
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  companion object {
    private const val CAPABILITIES_CHANNEL = "com.example.fmark_camera/capabilities"
    private const val METHOD_GET_CAPABILITIES = "getCameraCapabilities"
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAPABILITIES_CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          METHOD_GET_CAPABILITIES -> result.success(fetchCameraCapabilities())
          else -> result.notImplemented()
        }
      }
  }

  private fun fetchCameraCapabilities(): List<Map<String, Any>> {
    val manager = getSystemService(CAMERA_SERVICE) as? CameraManager ?: return emptyList()
    val devices = mutableListOf<Map<String, Any>>()
    try {
      manager.cameraIdList.forEach { cameraId ->
        val characteristics = manager.getCameraCharacteristics(cameraId)
        val lensFacingValue =
          characteristics.get(CameraCharacteristics.LENS_FACING)
            ?: CameraCharacteristics.LENS_FACING_BACK
        val lensFacing = when (lensFacingValue) {
          CameraCharacteristics.LENS_FACING_FRONT -> "front"
          CameraCharacteristics.LENS_FACING_EXTERNAL -> "external"
          else -> "back"
        }
        val configMap =
          characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            ?: return@forEach

        val photoSizes = serializeSizes(configMap.getOutputSizes(ImageFormat.JPEG))
        val videoSizes = serializeSizes(configMap.getOutputSizes(MediaRecorder::class.java))

        devices.add(
          mapOf(
            "id" to cameraId,
            "lensFacing" to lensFacing,
            "photoSizes" to photoSizes,
            "videoSizes" to videoSizes,
          ),
        )
      }
    } catch (error: CameraAccessException) {
      Log.w("FmarkCamera", "Failed to query camera capabilities", error)
    } catch (error: SecurityException) {
      Log.w("FmarkCamera", "Camera access denied", error)
    }
    return devices
  }

  private fun serializeSizes(sizes: Array<Size>?): List<Map<String, Int>> {
    if (sizes == null || sizes.isEmpty()) {
      return emptyList()
    }
    return sizes
      .toSet()
      .sortedWith(
        compareByDescending<Size> { it.width.toLong() * it.height.toLong() }
          .thenByDescending { it.width },
      )
      .map { size ->
        mapOf("width" to size.width, "height" to size.height)
      }
  }
}
