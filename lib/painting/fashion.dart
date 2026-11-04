import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import '../core/models.dart';
import 'art.dart';

/// Shared decoded sprites, loaded once. Both live canvas and PNG capture use
/// these same painters; exported artwork never substitutes a different avatar.
class FashionImages {
  static final Map<String, Future<ui.Image>> _images = {};
  static final Map<String, SpriteMask> masks = {};
  static final Map<String, ui.Image> ready = {};
  static Future<ui.Image> load(String name) =>
      _images.putIfAbsent(name, () async {
        final data = await rootBundle.load('assets/fashion/$name.png');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        try {
          final image = (await codec.getNextFrame()).image;
          if (!name.startsWith('avatar') && name != 'scenes') {
            final raw = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            final alpha = Uint8List(image.width * image.height);
            for (var i = 0; i < alpha.length; i++) {
              alpha[i] = raw[i * 4 + 3];
            }
            masks[name] = SpriteMask(image.width, image.height, alpha);
          }
          ready[name] = image;
          return image;
        } finally {
          codec.dispose();
        }
      });
}

bool photographic(BodyProfile body) => body.appearance == 'photo';
String avatarSheet(BodyProfile body) =>
    body.gender == 'feminine' ? 'avatar' : 'avatars-inclusive';
Rect avatarRegion(BodyProfile body) => body.gender == 'feminine'
    ? const Rect.fromLTWH(0, 0, 1, 1)
    : Rect.fromLTWH(body.gender == 'masculine' ? 0 : .5, 0, .5, 1);

Widget fashionLoading(bool failed) => Center(
  child: Icon(
    failed ? Icons.broken_image_outlined : Icons.hourglass_empty,
    size: 18,
    color: const Color(0xffaa9589),
    semanticLabel: failed ? '素材讀取失敗' : '素材載入中',
  ),
);

class FashionAvatar extends StatelessWidget {
  final BodyProfile body;
  const FashionAvatar({super.key, required this.body});
  @override
  Widget build(BuildContext context) {
    if (!photographic(body)) {
      return CustomPaint(painter: AvatarPainter(body));
    }
    final ready = FashionImages.ready[avatarSheet(body)];
    if (ready != null) {
      return CustomPaint(painter: FashionAvatarPainter(body, ready));
    }
    return FutureBuilder<ui.Image>(
      key: ValueKey(avatarSheet(body)),
      future: FashionImages.load(avatarSheet(body)),
      builder: (context, snapshot) => snapshot.hasData
          ? CustomPaint(painter: FashionAvatarPainter(body, snapshot.data!))
          : fashionLoading(snapshot.hasError),
    );
  }
}

class FashionAvatarPainter extends CustomPainter {
  final BodyProfile body;
  final ui.Image image;
  FashionAvatarPainter(this.body, this.image);
  @override
  void paint(Canvas canvas, Size size) {
    const columns = 32, rows = 80;
    final positions = <Offset>[], texture = <Offset>[], indices = <int>[];
    for (var row = 0; row <= rows; row++) {
      for (var col = 0; col <= columns; col++) {
        final x = col / columns, y = row / rows;
        final point = FigureGeometry(body).deformPhotograph(x, y);
        positions.add(
          Offset(
            (.5 + (point.dx - .5) * (0.82 / .66)) * size.width,
            point.dy * size.height,
          ),
        );
        final region = avatarRegion(body);
        texture.add(
          Offset(
            (region.left + x * region.width) * image.width,
            (region.top + y * region.height) * image.height,
          ),
        );
        if (row < rows && col < columns) {
          final a = row * (columns + 1) + col, b = a + columns + 1;
          indices.addAll([a, b, a + 1, a + 1, b, b + 1]);
        }
      }
    }
    final vertices = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texture,
      indices: indices,
    );
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.medium
      ..shader = ui.ImageShader(
        image,
        TileMode.clamp,
        TileMode.clamp,
        Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
      );
    // A tone adjustment preserves texture; it is an artistic preview only.
    if (body.skin != 2) {
      final brightness = [1.15, 1.07, 1.0, .88, .76, .65, .53, .42][body.skin];
      paint.colorFilter = ColorFilter.matrix([
        brightness,
        0,
        0,
        0,
        0,
        0,
        brightness,
        0,
        0,
        0,
        0,
        0,
        brightness,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
    }
    canvas.drawVertices(vertices, BlendMode.srcOver, paint);
    vertices.dispose();
  }

  @override
  bool shouldRepaint(FashionAvatarPainter old) => true;
}

/// Source rectangles describe independently selectable garment and hair sprites.
/// The atlas is never used as a screen background or a flattened outfit.
const fashionSprites = <String, Rect>{
  'tee_white': Rect.fromLTRB(.01, .073, .328, .345),
  'cardigan_blue': Rect.fromLTRB(.338, .035, .663, .425),
  'tee_rose': Rect.fromLTRB(.671, .075, .994, .344),
  'jeans': Rect.fromLTRB(.075, .454, .273, .981),
  'trousers': Rect.fromLTRB(.414, .454, .605, .981),
  'skirt': Rect.fromLTRB(.674, .462, .99, .938),
  'shoes_wine': Rect.fromLTRB(.016, .37, .484, .756),
  'shoes_cream': Rect.fromLTRB(.515, .367, .986, .756),
  'bag': Rect.fromLTRB(.072, .516, .431, .982),
  'bag_black': Rect.fromLTRB(.565, .516, .925, .982),
  'blouse': Rect.fromLTRB(.054, .012, .439, .488),
  'cardigan_wine': Rect.fromLTRB(.547, .012, .95, .488),
  'hair_back': Rect.fromLTRB(.045, .512, .456, .975),
  'hair_front': Rect.fromLTRB(.573, .514, .929, .964),
};

class FashionGarment extends StatelessWidget {
  final Item item;
  const FashionGarment({super.key, required this.item});
  String get sheet =>
      ['blouse', 'cardigan_wine', 'hair_back', 'hair_front'].contains(item.id)
      ? 'extras'
      : item.kind == Kind.shoes
      ? 'footwear'
      : item.kind == Kind.accessory
      ? 'accessories'
      : 'garments';
  Widget artwork(ui.Image image) => SpriteHitRegion(
    mask: FashionImages.masks[sheet],
    region: fashionSprites[item.id]!,
    child: CustomPaint(
      painter: FashionGarmentPainter(
        image,
        fashionSprites[item.id]!,
        splitShoes: item.kind == Kind.shoes,
        coverFromWaist: item.id == 'jeans' || item.id == 'trousers',
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final image = FashionImages.ready[sheet];
    if (image != null) return artwork(image);
    return FutureBuilder<ui.Image>(
      future: FashionImages.load(sheet),
      builder: (context, snapshot) => snapshot.hasData
          ? artwork(snapshot.data!)
          : fashionLoading(snapshot.hasError),
    );
  }
}

class SpriteMask {
  final int width, height;
  final Uint8List alpha;
  SpriteMask(this.width, this.height, this.alpha);
  bool opaque(Offset normalized) {
    final x = (normalized.dx * width).floor();
    final y = (normalized.dy * height).floor();
    return x >= 0 &&
        y >= 0 &&
        x < width &&
        y < height &&
        alpha[y * width + x] > 28;
  }
}

/// Transparent hair openings and garment margins allow hits to layers below.
class SpriteHitRegion extends SingleChildRenderObjectWidget {
  final SpriteMask? mask;
  final Rect region;
  final Rect? destination;
  const SpriteHitRegion({
    super.key,
    required this.mask,
    required this.region,
    this.destination,
    required super.child,
  });
  @override
  RenderObject createRenderObject(BuildContext context) =>
      SpriteHitBox(mask, region, destination);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant SpriteHitBox renderObject,
  ) {
    renderObject
      ..mask = mask
      ..region = region
      ..destination = destination;
  }
}

class SpriteHitBox extends RenderProxyBox {
  SpriteMask? mask;
  Rect region;
  Rect? destination;
  SpriteHitBox(this.mask, this.region, this.destination);
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    final target = destination ?? (Offset.zero & size);
    if (target.isEmpty || !target.contains(position)) return false;
    final point = Offset(
      region.left + (position.dx - target.left) / target.width * region.width,
      region.top + (position.dy - target.top) / target.height * region.height,
    );
    if (mask != null && !mask!.opaque(point)) return false;
    return super.hitTest(result, position: position);
  }
}

class FashionGarmentPainter extends CustomPainter {
  final ui.Image image;
  final Rect region;
  final bool splitShoes, coverFromWaist;
  FashionGarmentPainter(
    this.image,
    this.region, {
    this.splitShoes = false,
    this.coverFromWaist = false,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final source = Rect.fromLTRB(
      region.left * image.width,
      region.top * image.height,
      region.right * image.width,
      region.bottom * image.height,
    );
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (splitShoes) {
      final half = source.width / 2;
      final width = size.height * half / source.height;
      for (var side = 0; side < 2; side++) {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(
            source.left + side * half,
            source.top,
            half,
            source.height,
          ),
          Rect.fromLTWH(
            side == 0 ? 0 : size.width - width,
            0,
            width,
            size.height,
          ),
          paint,
        );
      }
    } else if (coverFromWaist) {
      final fitted = applyBoxFit(BoxFit.cover, source.size, size);
      final crop = Alignment.topCenter.inscribe(fitted.source, source);
      canvas.drawImageRect(image, crop, Offset.zero & size, paint);
    } else {
      canvas.drawImageRect(image, source, Offset.zero & size, paint);
    }
  }

  @override
  bool shouldRepaint(FashionGarmentPainter old) =>
      old.region != region ||
      old.image != image ||
      old.splitShoes != splitShoes ||
      old.coverFromWaist != coverFromWaist;
}

const fashionScenes = <String, Rect>{
  'gallery': Rect.fromLTWH(0, 0, .5, .5),
  'garden': Rect.fromLTWH(.5, 0, .5, .5),
  'coast': Rect.fromLTWH(0, .5, .5, .5),
  'evening': Rect.fromLTWH(.5, .5, .5, .5),
};

class FashionScene extends StatelessWidget {
  final String id;
  final double x, y;
  const FashionScene(this.id, {super.key, this.x = 0, this.y = 0});
  @override
  Widget build(BuildContext context) => FutureBuilder<ui.Image>(
    future: FashionImages.load('scenes'),
    builder: (context, snapshot) => snapshot.hasData
        ? CustomPaint(
            painter: FashionScenePainter(
              snapshot.data!,
              fashionScenes[id]!,
              x,
              y,
            ),
          )
        : fashionLoading(snapshot.hasError),
  );
}

class FashionScenePainter extends CustomPainter {
  final ui.Image image;
  final Rect region;
  final double x, y;
  FashionScenePainter(this.image, this.region, this.x, this.y);
  @override
  void paint(Canvas canvas, Size size) {
    final cell = Rect.fromLTRB(
      region.left * image.width,
      region.top * image.height,
      region.right * image.width,
      region.bottom * image.height,
    );
    final fitted = applyBoxFit(BoxFit.cover, cell.size, size);
    final source = Alignment(x, y).inscribe(fitted.source, cell);
    canvas.drawImageRect(
      image,
      source,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(FashionScenePainter old) =>
      old.region != region || old.x != x || old.y != y;
}
