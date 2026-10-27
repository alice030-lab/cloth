package com.outfitcanvas.outfit_canvas

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "outfit_canvas/segmentation")
            .setMethodCallHandler { call, result ->
                if (call.method != "segment") { result.notImplemented(); return@setMethodCallHandler }
                val bytes = call.argument<ByteArray>("bytes")
                val bitmap = bytes?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
                if (bitmap == null) { result.error("image", "圖片無法讀取。", null); return@setMethodCallHandler }
                val options = SubjectSegmenterOptions.Builder().enableForegroundBitmap().build()
                val segmenter = SubjectSegmentation.getClient(options)
                // Foreground bitmap provides all foreground subjects. Instance picking is
                // explicitly unavailable here until per-subject masks are validated.
                if (call.argument<Double>("x") != null) {
                    result.error("unavailable", "Android 目前支援整體主體去背；點選單一主體尚待裝置驗證，請用手動擦除。", null)
                    segmenter.close(); bitmap.recycle(); return@setMethodCallHandler
                }
                segmenter.process(InputImage.fromBitmap(bitmap, 0))
                    .addOnSuccessListener { output ->
                        val foreground = output.foregroundBitmap
                        if (foreground == null) { result.error("subject", "沒有可辨識主體，請使用手動擦除。", null) }
                        else {
                            val stream = ByteArrayOutputStream()
                            foreground.compress(Bitmap.CompressFormat.PNG, 100, stream)
                            result.success(stream.toByteArray())
                        }
                    }
                    .addOnFailureListener { result.error("segmentation", "模型尚未可用或處理失敗，請稍後重試，或使用手動工具。", null) }
                    .addOnCompleteListener { segmenter.close(); bitmap.recycle() }
            }
    }
}
