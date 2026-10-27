import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Request a bounded output using the supported cross-platform codec API.
/// Encoded ImageDescriptor.width/height are not implemented by Flutter Web.
/// The Web engine may briefly decode the intrinsic frame for this callback;
/// callers also cap input file size before reaching this method.
Future<ui.Image> decodeBounded(
  Uint8List bytes, {
  int longestEdge = 1600,
}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  // This API owns and disposes the buffer on both success and failure.
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (width, height) {
      final factor = math.min(1.0, longestEdge / math.max(width, height));
      return ui.TargetImageSize(
        width: math.max(1, (width * factor).round()),
        height: math.max(1, (height * factor).round()),
      );
    },
  );
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}
