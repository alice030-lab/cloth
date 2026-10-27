import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/controller.dart';
import '../painting/art.dart';

/// Capture the starting avatar without temporarily mutating the live document
/// (autosave must never observe an empty outfit during a before-image render).
Future<Uint8List> renderBefore(EditorController editor) async {
  const size = Size(800, 1200);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final doc = editor.doc;
  Uint8List? bytes;
  if (doc.scene == 'cafe') {
    bytes = (await rootBundle.load(
      'assets/scenes/cafe.png',
    )).buffer.asUint8List();
  } else if (doc.scene.startsWith('scene_')) {
    bytes = await editor.repo.asset(doc.scene);
  }
  if (bytes != null) {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 1000,
      allowUpscaling: false,
    );
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: image,
      fit: BoxFit.cover,
      alignment: Alignment(doc.cropX, doc.cropY),
    );
    // Picture retains its image until rasterization; release below.
    canvas.save();
    canvas.translate(size.width * .17, size.height * .025);
    AvatarPainter(
      doc.body,
    ).paint(canvas, Size(size.width * .66, size.height * .94));
    canvas.restore();
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(800, 1200);
    picture.dispose();
    image.dispose();
    final output = (await rendered.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    rendered.dispose();
    return output;
  }
  ScenePainter(
    doc.scene,
    cropX: doc.cropX,
    cropY: doc.cropY,
  ).paint(canvas, size);
  canvas.save();
  canvas.translate(size.width * .17, size.height * .025);
  AvatarPainter(
    doc.body,
  ).paint(canvas, Size(size.width * .66, size.height * .94));
  canvas.restore();
  final picture = recorder.endRecording();
  final rendered = await picture.toImage(800, 1200);
  picture.dispose();
  final output = (await rendered.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
  rendered.dispose();
  return output;
}
