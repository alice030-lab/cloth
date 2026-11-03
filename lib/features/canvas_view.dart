import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../core/images.dart';
import 'dart:ui' as ui;
import '../painting/art.dart';
import '../painting/fashion.dart';

class AssetImageView extends StatefulWidget {
  final EditorController editor;
  final String id;
  final BoxFit fit;
  final Alignment alignment;
  final bool alphaHitTest;
  const AssetImageView({
    super.key,
    required this.editor,
    required this.id,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.alphaHitTest = false,
  });
  @override
  State<AssetImageView> createState() => _AssetImageViewState();
}

class _LoadedAsset {
  final ui.Image image;
  final SpriteMask? mask;
  _LoadedAsset(this.image, this.mask);
}

class _AssetImageViewState extends State<AssetImageView> {
  late Future<_LoadedAsset?> future;
  _LoadedAsset? owned;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    final token = ++generation;
    owned?.image.dispose();
    owned = null;
    final id = widget.id, alpha = widget.alphaHitTest;
    future = () async {
      final bytes = await widget.editor.repo.asset(id);
      if (bytes == null) return null;
      final image = await decodeBounded(bytes);
      SpriteMask? mask;
      if (alpha) {
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        final values = Uint8List(image.width * image.height);
        for (var i = 0; i < values.length; i++) {
          values[i] = data[i * 4 + 3];
        }
        mask = SpriteMask(image.width, image.height, values);
      }
      if (!mounted || token != generation) {
        image.dispose();
        return null;
      }
      return owned = _LoadedAsset(image, mask);
    }();
  }

  @override
  void didUpdateWidget(AssetImageView old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id || old.alphaHitTest != widget.alphaHitTest) {
      reload();
    }
  }

  @override
  void dispose() {
    generation++;
    owned?.image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_LoadedAsset?>(
    future: future,
    builder: (context, snapshot) {
      final asset = snapshot.data;
      if (asset == null) {
        return fashionLoading(
          snapshot.hasError || snapshot.connectionState == ConnectionState.done,
        );
      }
      final image = RawImage(
        image: asset.image,
        fit: widget.fit,
        alignment: widget.alignment,
      );
      if (!widget.alphaHitTest) return image;
      return LayoutBuilder(
        builder: (context, box) {
          final source = Size(
            asset.image.width.toDouble(),
            asset.image.height.toDouble(),
          );
          final fitted = applyBoxFit(widget.fit, source, box.biggest);
          final destination = widget.alignment.inscribe(
            fitted.destination,
            Offset.zero & box.biggest,
          );
          final crop = widget.alignment.inscribe(
            fitted.source,
            Offset.zero & source,
          );
          return SpriteHitRegion(
            mask: asset.mask,
            region: Rect.fromLTRB(
              crop.left / source.width,
              crop.top / source.height,
              crop.right / source.width,
              crop.bottom / source.height,
            ),
            destination: destination,
            child: image,
          );
        },
      );
    },
  );
}

/// Await every actual decoded asset in a capture subtree before rasterizing.
Future<void> waitForCanvasAssets(BuildContext context) async {
  final pending = <Future<_LoadedAsset?>>[];
  void visit(Element element) {
    if (element is StatefulElement && element.state is _AssetImageViewState) {
      pending.add((element.state as _AssetImageViewState).future);
    }
    element.visitChildren(visit);
  }

  visit(context as Element);
  final results = await Future.wait(pending);
  if (results.any((asset) => asset == null)) throw StateError('圖片尚未就緒，請重試。');
}

class ItemArt extends StatelessWidget {
  final EditorController editor;
  final Item item;
  final bool activated;
  const ItemArt({
    super.key,
    required this.editor,
    required this.item,
    this.activated = false,
  });
  @override
  Widget build(BuildContext context) => item.assetId == null
      ? (fashionSprites.containsKey(item.id)
            ? FashionGarment(item: item)
            : CustomPaint(
                painter: ItemPainter(item, activated: activated),
                size: Size.infinite,
              ))
      : AssetImageView(editor: editor, id: item.assetId!, alphaHitTest: true);
}

class CanvasView extends StatelessWidget {
  final EditorController editor;
  final GlobalKey? captureKey;
  final bool interactive;
  final VoidCallback? onLayers;
  final void Function(CanvasLayer)? onMenu;
  const CanvasView({
    super.key,
    required this.editor,
    this.captureKey,
    this.interactive = true,
    this.onLayers,
    this.onMenu,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      return Center(
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: LayoutBuilder(
              builder: (context, b) {
                final size = b.biggest;
                final content = Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: interactive ? () => editor.select(null) : null,
                      child: sceneBackground(editor, editor.doc.scene),
                    ),
                    for (final l in editor.doc.sorted.where((l) => l.z < 2))
                      _layer(l, size),
                    Positioned(
                      left: size.width * .17,
                      top: size.height * .025,
                      width: size.width * .66,
                      height: size.height * .94,
                      child: IgnorePointer(
                        child: FashionAvatar(body: editor.doc.body),
                      ),
                    ),
                    for (final l in editor.doc.sorted.where((l) => l.z >= 2))
                      _layer(l, size),
                  ],
                );
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(key: captureKey, child: content),
                    if (interactive)
                      IgnorePointer(
                        child: CareFeedback(
                          event: editor.careEvent,
                          kind: editor.careKind,
                          face: editor.anchor('faceCenter'),
                        ),
                      ),
                    if (interactive && editor.selection != null)
                      _selection(editor.selection!, size),
                    if (interactive)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .22),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .6),
                              ),
                            ),
                            child: Text(
                              scenes
                                      .where((s) => s.id == editor.doc.scene)
                                      .firstOrNull
                                      ?.subtitle ??
                                  '我的專屬場景',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (interactive)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Row(
                          children: [
                            _round(
                              '復原',
                              Icons.undo_rounded,
                              editor.canUndo ? editor.undo : null,
                            ),
                            const SizedBox(width: 6),
                            _round(
                              '重做',
                              Icons.redo_rounded,
                              editor.canRedo ? editor.redo : null,
                            ),
                          ],
                        ),
                      ),
                    if (interactive)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: _round('圖層', Icons.layers_outlined, onLayers),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
  Widget _round(String tip, IconData icon, VoidCallback? onTap) => Material(
    color: paper.withValues(alpha: .94),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: tip,
      onPressed: onTap,
      icon: Icon(icon, size: 20),
    ),
  );
  Rect rect(CanvasLayer l, Size s) {
    final it = editor.item(l.itemId);
    final h = l.scale * s.height * .94;
    final w = h * it.naturalAspect * l.widthScale;
    final centerAligned = l.kind.anchor == null;
    return Rect.fromLTWH(
      l.x * s.width - w / 2,
      l.y * s.height - (centerAligned ? h / 2 : 0),
      w,
      h,
    );
  }

  Widget _layer(CanvasLayer l, Size size) {
    final r = rect(l, size);
    return Positioned.fromRect(
      rect: r,
      child: Transform.rotate(
        angle: l.rotation,
        alignment: l.kind.anchor == null
            ? Alignment.center
            : Alignment.topCenter,
        child: interactive
            ? GestureLayer(
                editor: editor,
                layer: l,
                size: size,
                onMenu: () => onMenu?.call(l),
                child: ItemArt(
                  editor: editor,
                  item: editor.item(l.itemId),
                  activated: l.activated,
                ),
              )
            : IgnorePointer(
                child: ItemArt(
                  editor: editor,
                  item: editor.item(l.itemId),
                  activated: l.activated,
                ),
              ),
      ),
    );
  }

  Widget _selection(CanvasLayer l, Size size) {
    final r = rect(l, size);
    return Positioned.fromRect(
      rect: r.inflate(3),
      child: IgnorePointer(
        child: Transform.rotate(
          angle: l.rotation,
          alignment: l.kind.anchor == null
              ? Alignment.center
              : Alignment.topCenter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 1.4),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final align in [
                  Alignment.topLeft,
                  Alignment.topRight,
                  Alignment.bottomRight,
                  Alignment.bottomLeft,
                ])
                  Align(
                    alignment: align,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: paper,
                        shape: BoxShape.circle,
                        border: Border.all(color: wine, width: .7),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget sceneBackground(EditorController e, String id) {
  if (id.startsWith('scene_')) {
    return AssetImageView(
      editor: e,
      id: id,
      fit: BoxFit.cover,
      alignment: Alignment(e.doc.cropX, e.doc.cropY),
    );
  }
  if (id == 'cafe') {
    return Image.asset(
      'assets/scenes/cafe.png',
      fit: BoxFit.cover,
      alignment: Alignment(e.doc.cropX, e.doc.cropY),
      errorBuilder: (c, err, s) => CustomPaint(painter: ScenePainter(id)),
    );
  }
  return FashionScene(id, x: e.doc.cropX, y: e.doc.cropY);
}

class GestureLayer extends StatefulWidget {
  final EditorController editor;
  final CanvasLayer layer;
  final Size size;
  final Widget child;
  final VoidCallback onMenu;
  const GestureLayer({
    super.key,
    required this.editor,
    required this.layer,
    required this.size,
    required this.child,
    required this.onMenu,
  });
  @override
  State<GestureLayer> createState() => _GestureLayerState();
}

class _GestureLayerState extends State<GestureLayer>
    with SingleTickerProviderStateMixin {
  late double startX, startY, startScale, startRotation;
  late Offset startFocal;
  bool moving = false;
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  void activateProp() {
    final e = widget.editor, l = widget.layer;
    final it = e.item(l.itemId);
    if (it.id == 'patch' || it.id == 'serum') {
      e.useCare(l);
      HapticFeedback.lightImpact();
      if (!MediaQuery.of(context).disableAnimations) {
        pulse.forward(from: 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${widget.editor.item(widget.layer.itemId).name}${widget.layer.activated ? '，已使用' : ''}',
    button: true,
    child: GestureDetector(
      behavior:
          (fashionSprites.containsKey(widget.layer.itemId) ||
              widget.editor.item(widget.layer.itemId).assetId != null)
          ? HitTestBehavior.deferToChild
          : HitTestBehavior.translucent,
      onTap: () {
        widget.editor.tapLayer(widget.layer);
        activateProp();
      },
      onLongPress: widget.onMenu,
      onScaleStart: (d) {
        final e = widget.editor, l = widget.layer;
        e.checkpoint();
        e.select(l.id);
        startX = l.x;
        startY = l.y;
        startScale = l.scale;
        startRotation = l.rotation;
        startFocal = d.focalPoint;
        setState(() => moving = true);
      },
      onScaleUpdate: (d) {
        final l = widget.layer;
        final delta = d.focalPoint - startFocal;
        l.x = (startX + delta.dx / widget.size.width)
            .clamp(.02, .98)
            .toDouble();
        l.y = (startY + delta.dy / widget.size.height)
            .clamp(.02, .96)
            .toDouble();
        l.scale = (startScale * d.scale).clamp(.03, 2).toDouble();
        l.rotation = startRotation + d.rotation;
        l.snappedTo = null;
        widget.editor.liveUpdate();
      },
      onScaleEnd: (d) {
        setState(() => moving = false);
        widget.editor.finishGesture(widget.layer, widget.size);
      },
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) => Transform.scale(
          scale: moving ? 1.05 : 1 + math.sin(pulse.value * math.pi) * .12,
          child: Opacity(
            opacity:
                widget.layer.activated &&
                    widget.editor.item(widget.layer.itemId).id == 'patch'
                ? .45
                : 1,
            child: child,
          ),
        ),
        child: widget.child,
      ),
    ),
  );
}

/// Transient care feedback is outside the capture boundary and never baked
/// into a saved outfit. Reduced-motion users get the persistent used state.
class CareFeedback extends StatefulWidget {
  final int event;
  final String? kind;
  final Offset face;
  const CareFeedback({
    super.key,
    required this.event,
    required this.kind,
    required this.face,
  });
  @override
  State<CareFeedback> createState() => _CareFeedbackState();
}

class _CareFeedbackState extends State<CareFeedback>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  @override
  void didUpdateWidget(CareFeedback old) {
    super.didUpdateWidget(old);
    if (old.event != widget.event && !MediaQuery.disableAnimationsOf(context)) {
      controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, child) => CustomPaint(
      painter: CareFeedbackPainter(controller.value, widget.face, widget.kind),
      size: Size.infinite,
    ),
  );
}

class CareFeedbackPainter extends CustomPainter {
  final double progress;
  final Offset face;
  final String? kind;
  CareFeedbackPainter(this.progress, this.face, this.kind);
  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1 || kind == null) return;
    final center = Offset(face.dx * size.width, face.dy * size.height);
    final radius = size.width * .038;
    final opacity = math.sin(progress * math.pi);
    final paint = Paint()
      ..color = const Color(0xfff7e6b6).withValues(alpha: opacity);
    if (kind == 'serum') {
      final sweep = Path()
        ..moveTo(center.dx - radius, center.dy + radius * .4)
        ..quadraticBezierTo(
          center.dx,
          center.dy + radius * (1.6 - progress),
          center.dx + radius,
          center.dy + radius * .25,
        );
      canvas.drawPath(
        sweep,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity * .8)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = radius * .55
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      for (var i = 0; i < 3; i++) {
        final t = (progress + i * .22) % 1;
        canvas.drawOval(
          Rect.fromCenter(
            center:
                center + Offset((i - 1) * radius * .85, (t - .5) * radius * 2),
            width: radius * .23,
            height: radius * .35,
          ),
          paint,
        );
      }
    } else {
      for (var i = 0; i < 5; i++) {
        final angle = i * math.pi * 2 / 5;
        final position =
            center +
            Offset(math.cos(angle), math.sin(angle)) *
                radius *
                (1 + progress * 1.8);
        final r = radius * .25 * opacity;
        canvas.drawLine(
          position - Offset(r, 0),
          position + Offset(r, 0),
          paint..strokeWidth = 1.5,
        );
        canvas.drawLine(
          position - Offset(0, r),
          position + Offset(0, r),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CareFeedbackPainter old) =>
      old.progress != progress || old.face != face || old.kind != kind;
}
