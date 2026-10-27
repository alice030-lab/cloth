import Flutter
import UIKit
import Vision
import CoreImage

/// iOS 17 foreground instances; all work runs locally on a serial queue.
/// Input PNG is orientation-normalized by Flutter's decoder.
final class SegmentationPlugin {
    private let queue = DispatchQueue(label: "outfit.segmentation", qos: .userInitiated)
    static func register(with messenger: FlutterBinaryMessenger) {
        let plugin = SegmentationPlugin()
        let channel = FlutterMethodChannel(name: "outfit_canvas/segmentation", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            guard call.method == "segment" else { result(FlutterMethodNotImplemented); return }
            guard #available(iOS 17.0, *) else {
                result(FlutterError(code: "unavailable", message: "自動去背需要 iOS 17 或以上，請使用手動擦除。", details: nil)); return
            }
            guard let args = call.arguments as? [String: Any],
                  let data = args["bytes"] as? FlutterStandardTypedData,
                  let image = UIImage(data: data.data)?.cgImage else {
                result(FlutterError(code: "image", message: "圖片無法讀取。", details: nil)); return
            }
            plugin.queue.async {
                do {
                    let request = VNGenerateForegroundInstanceMaskRequest()
                    let handler = VNImageRequestHandler(cgImage: image, options: [:])
                    try handler.perform([request])
                    guard let observation = request.results?.first else {
                        throw NSError(domain: "segmentation", code: 1)
                    }
                    var instances = observation.allInstances
                    if let x = args["x"] as? Double, let y = args["y"] as? Double {
                        let mask = observation.instanceMask
                        CVPixelBufferLockBaseAddress(mask, .readOnly)
                        if let address = CVPixelBufferGetBaseAddress(mask) {
                            let width = CVPixelBufferGetWidth(mask), height = CVPixelBufferGetHeight(mask)
                            let px = min(width - 1, max(0, Int(x * Double(width))))
                            let py = min(height - 1, max(0, Int(y * Double(height))))
                            let stride = CVPixelBufferGetBytesPerRow(mask)
                            let index = Int(address.assumingMemoryBound(to: UInt8.self)[py * stride + px])
                            CVPixelBufferUnlockBaseAddress(mask, .readOnly)
                            guard index != 0 else {
                                DispatchQueue.main.async { result(FlutterError(code: "subject", message: "點選位置沒有可辨識主體，請換個位置或使用手動擦除。", details: nil)) }; return
                            }
                            instances = IndexSet(integer: index)
                        } else { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
                    }
                    let buffer = try observation.generateMaskedImage(ofInstances: instances, from: handler, croppedToInstancesExtent: false)
                    let ciImage = CIImage(cvPixelBuffer: buffer)
                    let context = CIContext(options: nil)
                    guard let output = context.createCGImage(ciImage, from: ciImage.extent),
                          let png = UIImage(cgImage: output).pngData() else {
                        throw NSError(domain: "segmentation", code: 2)
                    }
                    DispatchQueue.main.async { result(FlutterStandardTypedData(bytes: png)) }
                } catch {
                    DispatchQueue.main.async { result(FlutterError(code: "segmentation", message: "去背未成功，請使用手動工具修整。", details: nil)) }
                }
            }
        }
    }
}
