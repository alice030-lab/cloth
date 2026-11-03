import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/controller.dart';
import '../painting/art.dart';
import '../painting/fashion.dart';

/// Capture the starting avatar without mutating the live editable document.
/// The before and after canvases share the same 4:5 coordinate system.
Future<Uint8List> renderBefore(EditorController editor) async {
  const size = Size(800, 1000);
  final doc = editor.doc;
  final avatar = photographic(doc.body)
      ? await FashionImages.load(avatarSheet(doc.body))
      : null;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  ui.Image? ownedScene;
  if (fashionScenes.containsKey(doc.scene)) {
    final image = await FashionImages.load('scenes');
    FashionScenePainter(
      image,
      fashionScenes[doc.scene]!,
      doc.cropX,
      doc.cropY,
    ).paint(canvas, size);
  } else {
    final bytes = doc.scene == 'cafe'
        ? (await rootBundle.load('assets/scenes/cafe.png')).buffer.asUint8List()
        : await editor.repo.asset(doc.scene);
    if (bytes != null) {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 1000,
        allowUpscaling: false,
      );
      ownedScene = (await codec.getNextFrame()).image;
      codec.dispose();
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: ownedScene,
        fit: BoxFit.cover,
        alignment: Alignment(doc.cropX, doc.cropY),
      );
    } else {
      ScenePainter(
        doc.scene,
        cropX: doc.cropX,
        cropY: doc.cropY,
      ).paint(canvas, size);
    }
  }
  canvas.save();
  canvas.translate(size.width * .17, size.height * .025);
  final avatarSize = Size(size.width * .66, size.height * .94);
  if (avatar != null) {
    FashionAvatarPainter(doc.body, avatar).paint(canvas, avatarSize);
  } else {
    AvatarPainter(doc.body).paint(canvas, avatarSize);
  }
  canvas.restore();
  final picture = recorder.endRecording();
  final rendered = await picture.toImage(800, 1000);
  picture.dispose();
  ownedScene?.dispose();
  final output = (await rendered.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
  rendered.dispose();
  return output;
}
