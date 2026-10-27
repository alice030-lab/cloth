import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../painting/art.dart';

class AssetImageView extends StatefulWidget {
  final EditorController editor;
  final String id;
  final BoxFit fit;
  final Alignment alignment;
  const AssetImageView({
    super.key,
    required this.editor,
    required this.id,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });
  @override
  State<AssetImageView> createState() => _AssetImageViewState();
}

class _AssetImageViewState extends State<AssetImageView> {
  late Future<Uint8List?> future;
  @override
  void initState() {
    super.initState();
    future = widget.editor.repo.asset(widget.id);
  }

  @override
  void didUpdateWidget(AssetImageView old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      future = widget.editor.repo.asset(widget.id);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: future,
    builder: (context, s) {
      if (s.hasData) {
        return Image.memory(
          s.data!,
          fit: widget.fit,
          alignment: widget.alignment,
          gaplessPlayback: true,
          errorBuilder: (c, e, t) =>
              const Center(child: Icon(Icons.broken_image_outlined)),
        );
      }
      return Center(
        child: Icon(
          s.connectionState == ConnectionState.waiting
              ? Icons.hourglass_empty
              : Icons.broken_image_outlined,
          color: Colors.brown,
        ),
      );
    },
  );
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
      ? CustomPaint(
          painter: ItemPainter(item, activated: activated),
          size: Size.infinite,
        )
      : AssetImageView(editor: editor, id: item.assetId!);
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
          aspectRatio: 2 / 3,
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
                        child: CustomPaint(
                          painter: AvatarPainter(editor.doc.body),
                        ),
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
    final w = h * it.naturalAspect;
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
  return CustomPaint(
    painter: ScenePainter(id, cropX: e.doc.cropX, cropY: e.doc.cropY),
  );
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
      e.change(() => l.activated = !l.activated);
      HapticFeedback.lightImpact();
      if (!MediaQuery.of(context).disableAnimations) {
        pulse.forward(from: 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.editor.item(widget.layer.itemId).name,
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
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
