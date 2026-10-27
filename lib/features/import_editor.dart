import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import '../core/models.dart';
import '../core/images.dart';
import '../painting/art.dart';

class ImportedImage {
  final Uint8List bytes;
  final String name;
  final Kind kind;
  final double aspect;
  final String? source;
  ImportedImage(this.bytes, this.name, this.kind, this.aspect, this.source);
}

class BrushStroke {
  final List<Offset> points;
  final double width;
  final bool restore;
  BrushStroke(this.points, this.width, this.restore);
}

bool hasVisiblePixels(Uint8List bytes) {
  final image = img.decodePng(bytes);
  if (image == null) {
    return false;
  }
  for (final pixel in image) {
    if (pixel.a > 0) {
      return true;
    }
  }
  return false;
}

class ImportEditor extends StatefulWidget {
  final Uint8List bytes;
  final String filename;
  const ImportEditor({super.key, required this.bytes, required this.filename});
  @override
  State<ImportEditor> createState() => _ImportEditorState();
}

class _ImportEditorState extends State<ImportEditor> {
  ui.Image? image;
  ui.Image? segmented;
  Offset? subjectPoint;
  String? error;
  final List<BrushStroke> strokes = [];
  double brush = 24, left = 0, right = 1, top = 0, bottom = 1;
  String mode = '擦除';
  bool showOriginal = false, busy = false;
  Kind kind = Kind.top;
  late final TextEditingController name = TextEditingController(
    text: widget.filename.split('.').first,
  );
  final TextEditingController source = TextEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final decoded = await decodeBounded(widget.bytes, longestEdge: 1200);
      if (mounted) {
        setState(() => image = decoded);
      } else {
        decoded.dispose();
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = '無法解碼這張圖片，請改用 JPEG 或 PNG。');
      }
    }
  }

  @override
  void dispose() {
    image?.dispose();
    segmented?.dispose();
    name.dispose();
    source.dispose();
    super.dispose();
  }

  Rect get crop => Rect.fromLTRB(left, top, right, bottom);
  Future<void> automatic() async {
    setState(() => busy = true);
    try {
      if (kIsWeb ||
          ![
            TargetPlatform.iOS,
            TargetPlatform.android,
          ].contains(defaultTargetPlatform)) {
        throw PlatformException(
          code: 'unavailable',
          message: '此平台目前使用手動去背。請用擦除／還原筆刷修整圖片。',
        );
      }
      final input = await image!.toByteData(format: ui.ImageByteFormat.png);
      final bytes = await const MethodChannel('outfit_canvas/segmentation')
          .invokeMethod<Uint8List>('segment', {
            'bytes': input!.buffer.asUint8List(),
            'x': subjectPoint?.dx,
            'y': subjectPoint?.dy,
          });
      if (bytes == null) {
        throw const FormatException();
      }
      final decoded = await decodeBounded(bytes, longestEdge: 1200);
      if (mounted) {
        final old = segmented;
        setState(() {
          segmented = decoded;
          strokes.clear();
        });
        old?.dispose();
      } else {
        decoded.dispose();
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message ?? '去背不可用，請使用手動工具。')));
      }
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('此安裝版本尚未提供原生去背，請使用手動工具。')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('自動去背未成功，原圖仍保留，可繼續手動編輯。')));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> save() async {
    if (image == null || busy) {
      return;
    }
    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入單品名稱')));
      return;
    }
    final url = source.text.trim();
    final uri = Uri.tryParse(url);
    if (url.isNotEmpty &&
        (uri == null ||
            !['https', 'http'].contains(uri.scheme) ||
            uri.host.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('來源網址僅支援有效的 http／https 網址')));
      return;
    }
    setState(() => busy = true);
    try {
      final fullSize = Size(image!.width.toDouble(), image!.height.toDouble());
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      final offset = Offset(left * fullSize.width, top * fullSize.height);
      canvas.translate(-offset.dx, -offset.dy);
      MaskPainter(
        image!,
        strokes,
        baseline: segmented,
        original: false,
      ).paint(canvas, fullSize);
      final picture = rec.endRecording();
      final rendered = await picture.toImage(
        ((right - left) * fullSize.width).round().clamp(1, 1200).toInt(),
        ((bottom - top) * fullSize.height).round().clamp(1, 1200).toInt(),
      );
      picture.dispose();
      final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
      final w = rendered.width, h = rendered.height;
      rendered.dispose();
      final bytes = data!.buffer.asUint8List();
      if (!await compute(hasVisiblePixels, bytes)) {
        throw const FormatException('圖片已完全透明，請還原一部分主體再儲存。');
      }
      if (mounted) {
        Navigator.pop(
          context,
          ImportedImage(
            bytes,
            name.text.trim(),
            kind,
            w / h,
            url.isEmpty ? null : url,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is FormatException ? e.message : '圖片輸出失敗，請重試。'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: paper,
    appBar: AppBar(
      title: const Text('匯入與修圖'),
      actions: [
        TextButton(onPressed: busy ? null : save, child: const Text('加入衣櫥')),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              image == null
                  ? '正在解碼圖片…'
                  : kIsWeb
                  ? '裝置端手動去背 · 圖片不會上傳'
                  : (subjectPoint == null
                        ? '圖片留在本機 · 「主體」模式可點選要保留的位置'
                        : '已選主體 ${((subjectPoint!.dx) * 100).round()}%, ${((subjectPoint!.dy) * 100).round()}% · 點自動去背'),
              style: const TextStyle(fontSize: 12, color: Color(0xff746660)),
            ),
          ),
          Expanded(
            child: error != null
                ? Center(child: Text(error!))
                : image == null
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, b) {
                      final ratio = image!.width / image!.height;
                      return InteractiveViewer(
                        panEnabled: mode == '移動',
                        scaleEnabled: mode == '移動',
                        minScale: .5,
                        maxScale: 5,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: ratio,
                            child: LayoutBuilder(
                              builder: (context, box) {
                                Offset normalized(Offset p) => Offset(
                                  p.dx / box.maxWidth,
                                  p.dy / box.maxHeight,
                                );
                                return GestureDetector(
                                  onTapDown: mode == '主體'
                                      ? (d) => setState(
                                          () => subjectPoint = normalized(
                                            d.localPosition,
                                          ),
                                        )
                                      : null,
                                  onPanStart:
                                      (mode == '移動' ||
                                          mode == '主體' ||
                                          showOriginal ||
                                          busy)
                                      ? null
                                      : (d) {
                                          final p = normalized(d.localPosition);
                                          setState(
                                            () => strokes.add(
                                              BrushStroke(
                                                [p],
                                                brush / image!.width,
                                                mode == '還原',
                                              ),
                                            ),
                                          );
                                        },
                                  onPanUpdate:
                                      (mode == '移動' ||
                                          mode == '主體' ||
                                          showOriginal ||
                                          busy)
                                      ? null
                                      : (d) {
                                          setState(
                                            () => strokes.last.points.add(
                                              normalized(d.localPosition),
                                            ),
                                          );
                                        },
                                  child: CustomPaint(
                                    painter: CheckerPainter(),
                                    foregroundPainter: CropOverlay(crop),
                                    child: CustomPaint(
                                      painter: MaskPainter(
                                        image!,
                                        strokes,
                                        baseline: segmented,
                                        original: showOriginal,
                                      ),
                                      size: Size.infinite,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (busy) const LinearProgressIndicator(),
          SizedBox(
            height: 280,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final m in ['擦除', '還原', '移動', '主體'])
                        ChoiceChip(
                          label: Text(m),
                          selected: mode == m,
                          onSelected: busy
                              ? null
                              : (_) => setState(() => mode = m),
                        ),
                      FilterChip(
                        label: const Text('原圖'),
                        selected: showOriginal,
                        onSelected: busy
                            ? null
                            : (v) => setState(() => showOriginal = v),
                      ),
                      IconButton(
                        tooltip: '復原筆刷',
                        onPressed: strokes.isEmpty || busy
                            ? null
                            : () => setState(() => strokes.removeLast()),
                        icon: const Icon(Icons.undo),
                      ),
                      IconButton(
                        tooltip: '重設編輯',
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                strokes.clear();
                                segmented?.dispose();
                                segmented = null;
                                subjectPoint = null;
                                left = top = 0;
                                right = bottom = 1;
                              }),
                        icon: const Icon(Icons.restart_alt),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('筆刷'),
                      Expanded(
                        child: Slider(
                          value: brush,
                          min: 4,
                          max: 140,
                          onChanged: busy
                              ? null
                              : (v) => setState(() => brush = v),
                        ),
                      ),
                      Text('${brush.round()} px'),
                    ],
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('裁切邊界', style: TextStyle(fontSize: 14)),
                    children: [
                      for (final entry in [
                        ('左', left),
                        ('右', right),
                        ('上', top),
                        ('下', bottom),
                      ])
                        Row(
                          children: [
                            Text(entry.$1),
                            Expanded(
                              child: Slider(
                                value: entry.$2,
                                min: 0,
                                max: 1,
                                onChanged: busy
                                    ? null
                                    : (v) => setState(() {
                                        switch (entry.$1) {
                                          case '左':
                                            left = v
                                                .clamp(0, right - .05)
                                                .toDouble();
                                          case '右':
                                            right = v
                                                .clamp(left + .05, 1)
                                                .toDouble();
                                          case '上':
                                            top = v
                                                .clamp(0, bottom - .05)
                                                .toDouble();
                                          case '下':
                                            bottom = v
                                                .clamp(top + .05, 1)
                                                .toDouble();
                                        }
                                      }),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: name,
                          decoration: const InputDecoration(labelText: '單品名稱'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<Kind>(
                          initialValue: kind,
                          decoration: const InputDecoration(labelText: '類別'),
                          items: Kind.values
                              .map(
                                (k) => DropdownMenuItem(
                                  value: k,
                                  child: Text(k.label),
                                ),
                              )
                              .toList(),
                          onChanged: busy
                              ? null
                              : (v) => setState(() => kind = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: source,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(labelText: '來源網址（選填）'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    kind == Kind.reference
                        ? '模特兒圖作為完整穿著參考貼紙，不會自動分離衣服。'
                        : '衣架或多件商品可能需要手動擦除，請確認透明邊緣。',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: busy ? null : automatic,
                    icon: const Icon(Icons.auto_fix_high_outlined),
                    label: Text(kIsWeb ? '自動去背支援說明' : '嘗試裝置端自動去背'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xfff5f1eb));
    for (var y = 0.0; y < s.height; y += 12) {
      for (var x = 0.0; x < s.width; x += 12) {
        if (((x / 12).floor() + (y / 12).floor()).isEven) {
          c.drawRect(
            Rect.fromLTWH(x, y, 12, 12),
            Paint()..color = const Color(0xffded7d0),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(CheckerPainter old) => false;
}

class MaskPainter extends CustomPainter {
  final ui.Image image;
  final List<BrushStroke> strokes;
  final ui.Image? baseline;
  final bool original;
  MaskPainter(this.image, this.strokes, {this.baseline, this.original = false});
  @override
  void paint(Canvas c, Size s) {
    final bounds = Offset.zero & s;
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    c.saveLayer(bounds, Paint());
    final base = original ? image : (baseline ?? image);
    c.drawImageRect(
      base,
      Rect.fromLTWH(0, 0, base.width.toDouble(), base.height.toDouble()),
      bounds,
      Paint()..filterQuality = FilterQuality.medium,
    );
    if (!original) {
      for (final stroke in strokes) {
        final path = Path();
        for (final p in stroke.points) {
          path.addOval(
            Rect.fromCircle(
              center: Offset(p.dx * s.width, p.dy * s.height),
              radius: stroke.width * s.width / 2,
            ),
          );
        }
        // Connect each sample with a stroked path, including sparse pointer events.
        for (var i = 1; i < stroke.points.length; i++) {
          final from = Offset(
                stroke.points[i - 1].dx * s.width,
                stroke.points[i - 1].dy * s.height,
              ),
              to = Offset(
                stroke.points[i].dx * s.width,
                stroke.points[i].dy * s.height,
              );
          final distance = (to - from).distance;
          final steps = (distance / (stroke.width * s.width / 4)).ceil().clamp(
            1,
            1000,
          );
          for (var j = 0; j <= steps; j++) {
            path.addOval(
              Rect.fromCircle(
                center: Offset.lerp(from, to, j / steps)!,
                radius: stroke.width * s.width / 2,
              ),
            );
          }
        }
        if (stroke.restore) {
          c.save();
          c.clipPath(path);
          c.drawImageRect(image, src, bounds, Paint());
          c.restore();
        } else {
          c.drawPath(path, Paint()..blendMode = BlendMode.clear);
        }
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(MaskPainter old) => true;
}

class CropOverlay extends CustomPainter {
  final Rect crop;
  CropOverlay(this.crop);
  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTRB(
      crop.left * s.width,
      crop.top * s.height,
      crop.right * s.width,
      crop.bottom * s.height,
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & s)
      ..addRect(r);
    c.drawPath(path, Paint()..color = const Color(0x88000000));
    c.drawRect(
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(CropOverlay old) => old.crop != crop;
}

Future<XFile?> pickImage() => openFile(
  acceptedTypeGroups: [
    const XTypeGroup(
      label: '圖片',
      extensions: ['png', 'jpg', 'jpeg', 'webp', 'heic'],
      mimeTypes: ['image/png', 'image/jpeg', 'image/webp', 'image/heic'],
    ),
  ],
);
