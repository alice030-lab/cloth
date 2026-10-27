import 'dart:math' as math;
import 'dart:ui';

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1 << 30)}';
double number(dynamic v, [double fallback = 0]) =>
    v is num && v.isFinite ? v.toDouble() : fallback;

enum Kind {
  top,
  outer,
  bottom,
  shoes,
  accessory,
  hairBack,
  hairFront,
  expression,
  prop,
  reference,
}

extension KindInfo on Kind {
  String get label => const [
    '上衣',
    '外套',
    '下身',
    '鞋子',
    '配件',
    '後髮',
    '前髮',
    '表情',
    '道具',
    '穿著參考',
  ][index];
  int get z => const [5, 5, 4, 4, 7, 1, 6, 3, 7, 7][index];
  String? get anchor => switch (this) {
    Kind.top || Kind.outer => 'shoulderCenter',
    Kind.bottom => 'waistCenter',
    Kind.shoes => 'ankleCenter',
    Kind.hairBack || Kind.hairFront => 'headTop',
    Kind.expression => 'faceCenter',
    _ => null,
  };
  double get widthRatio =>
      const [1.15, 1.3, 1.0, .9, .5, .95, .95, .45, .4, 1.3][index];
}

class BodyProfile {
  double height, bust, waist, hip, shoulder;
  int skin;
  String gender, face;
  BodyProfile({
    this.height = 165,
    this.bust = 86,
    this.waist = 68,
    this.hip = 92,
    this.shoulder = 38,
    this.skin = 2,
    this.gender = 'feminine',
    this.face = '柔和',
  });
  static const ranges = <String, (double, double)>{
    'height': (140, 200),
    'bust': (65, 140),
    'waist': (50, 130),
    'hip': (70, 150),
    'shoulder': (30, 55),
  };
  double get(String key) => switch (key) {
    'height' => height,
    'bust' => bust,
    'waist' => waist,
    'hip' => hip,
    _ => shoulder,
  };
  void set(String key, double value) {
    final r = ranges[key]!;
    if (!value.isFinite || value < r.$1 || value > r.$2) {
      throw ArgumentError('超出時裝畫支援範圍 ${r.$1}–${r.$2} cm');
    }
    switch (key) {
      case 'height':
        height = value;
      case 'bust':
        bust = value;
      case 'waist':
        waist = value;
      case 'hip':
        hip = value;
      default:
        shoulder = value;
    }
  }

  Map<String, dynamic> toJson() => {
    'height': height,
    'bust': bust,
    'waist': waist,
    'hip': hip,
    'shoulder': shoulder,
    'skin': skin,
    'gender': gender,
    'face': face,
  };
  factory BodyProfile.fromJson(Map<String, dynamic> j) => BodyProfile(
    height: number(j['height'], 165),
    bust: number(j['bust'], 86),
    waist: number(j['waist'], 68),
    hip: number(j['hip'], 92),
    shoulder: number(j['shoulder'], 38),
    skin: (j['skin'] as int? ?? 2).clamp(0, 7).toInt(),
    gender: j['gender'] as String? ?? 'feminine',
    face: j['face'] as String? ?? '柔和',
  );
  BodyProfile copy() => BodyProfile.fromJson(toJson());
}

/// Coordinates in a 300×720 illustration viewport. Body dimensions change
/// independent control points; the figure is never stretched as one bitmap.
class FigureGeometry {
  final BodyProfile body;
  FigureGeometry(this.body);
  double get shoulder =>
      38 +
      (body.shoulder - 38) * 1.35 +
      (body.gender == 'masculine'
          ? 4
          : body.gender == 'neutral'
          ? 2
          : 0);
  double get chest => 33 + (body.bust - 86) * .48;
  double get waist =>
      23 + (body.waist - 68) * .43 + (body.gender == 'masculine' ? 3 : 0);
  double get hip => 39 + (body.hip - 92) * .45;
  double get legEnd => 656 + (body.height - 165) * .42;
  Map<String, Offset> get anchors => {
    'headTop': const Offset(150, 24),
    'faceCenter': const Offset(150, 76),
    'chin': const Offset(150, 108),
    'neck': const Offset(150, 133),
    'shoulderLeft': Offset(150 - shoulder, 150),
    'shoulderRight': Offset(150 + shoulder, 150),
    'shoulderCenter': const Offset(150, 148),
    'chestCenter': const Offset(150, 193),
    'waistCenter': const Offset(150, 272),
    'hipCenter': const Offset(150, 320),
    'kneeCenter': Offset(150, legEnd * .73),
    'ankleCenter': Offset(150, legEnd),
    'handLeft': Offset(150 - hip - 23, 367),
    'handRight': Offset(150 + hip + 23, 367),
  };
  Offset normalized(String name) {
    final a = anchors[name]!;
    return Offset(a.dx / 300, a.dy / 720);
  }
}

class Item {
  final String id;
  String name;
  final Kind kind;
  final int color;
  final String shape;
  final String? assetId;
  final double aspect;
  final String? sourceUrl;
  final DateTime createdAt;
  bool hidden;
  Item({
    required this.id,
    required this.name,
    required this.kind,
    this.color = 0xfff5f0e9,
    this.shape = 'tee',
    this.assetId,
    this.aspect = 1,
    this.sourceUrl,
    this.hidden = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
  bool get custom => assetId != null;
  double get naturalAspect => switch (shape) {
    'jeans' || 'trousers' => .26,
    'skirt' => .85,
    'hair' => .63,
    'shoes' => 2.3,
    'cardigan' => .8,
    'tee' || 'blouse' => 1.0,
    _ => aspect,
  };
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'color': color,
    'shape': shape,
    'assetId': assetId,
    'aspect': aspect,
    'sourceUrl': sourceUrl,
    'hidden': hidden,
    'createdAt': createdAt.toIso8601String(),
  };
  factory Item.fromJson(Map<String, dynamic> j) => Item(
    id: j['id'],
    name: j['name'],
    kind: Kind.values.byName(j['kind']),
    color: j['color'],
    shape: j['shape'],
    assetId: j['assetId'],
    aspect: number(j['aspect'], 1),
    sourceUrl: j['sourceUrl'],
    hidden: j['hidden'] == true,
    createdAt: DateTime.tryParse(j['createdAt'] ?? ''),
  );
}

class CanvasLayer {
  final String id, itemId;
  final Kind kind;
  double x, y, scale, rotation;
  String? snappedTo;
  int order;
  bool activated;
  CanvasLayer({
    required this.id,
    required this.itemId,
    required this.kind,
    this.x = .5,
    this.y = .4,
    this.scale = .25,
    this.rotation = 0,
    this.snappedTo,
    this.order = 0,
    this.activated = false,
  });
  int get z => kind.z;
  Map<String, dynamic> toJson() => {
    'id': id,
    'item_id': itemId,
    'kind': kind.name,
    'z': z,
    'x': x,
    'y': y,
    'scale': scale,
    'rotation': rotation,
    'snapped_to': snappedTo,
    'order': order,
    'activated': activated,
  };
  factory CanvasLayer.fromJson(Map<String, dynamic> j) => CanvasLayer(
    id: j['id'],
    itemId: j['item_id'],
    kind: Kind.values.byName(j['kind']),
    x: number(j['x'], .5),
    y: number(j['y'], .4),
    scale: number(j['scale'], .25).clamp(.03, 2).toDouble(),
    rotation: number(j['rotation']),
    snappedTo: j['snapped_to'],
    order: j['order'] ?? 0,
    activated: j['activated'] == true,
  );
  CanvasLayer copy() => CanvasLayer.fromJson(toJson());
}

class CanvasDocument {
  String id, name, scene;
  BodyProfile body;
  List<CanvasLayer> layers;
  double cropX, cropY;
  DateTime updatedAt;
  String? beforeAsset, afterAsset;
  CanvasDocument({
    String? id,
    this.name = '我的週末穿搭',
    this.scene = 'cafe',
    BodyProfile? body,
    List<CanvasLayer>? layers,
    this.cropX = 0,
    this.cropY = 0,
    this.beforeAsset,
    this.afterAsset,
    DateTime? updatedAt,
  }) : id = id ?? newId(),
       body = body ?? BodyProfile(),
       layers = layers ?? [],
       updatedAt = updatedAt ?? DateTime.now();
  List<CanvasLayer> get sorted => [...layers]
    ..sort((a, b) {
      final z = a.z.compareTo(b.z);
      return z == 0 ? a.order.compareTo(b.order) : z;
    });
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'name': name,
    'sceneId': scene,
    'bodyParams': body.toJson(),
    'avatarLevel': 1,
    'avatarScale': 1,
    'avatarPosition': [.5, .5],
    'cropX': cropX,
    'cropY': cropY,
    'layers': layers.map((l) => l.toJson()).toList(),
    'beforeSnapshotAssetId': beforeAsset,
    'afterSnapshotAssetId': afterAsset,
    'updatedAt': updatedAt.toIso8601String(),
  };
  factory CanvasDocument.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != 1) {
      throw const FormatException('作品版本不支援，原資料已保留');
    }
    return CanvasDocument(
      id: j['id'],
      name: j['name'],
      scene: j['sceneId'],
      body: BodyProfile.fromJson(Map<String, dynamic>.from(j['bodyParams'])),
      layers: (j['layers'] as List)
          .map((v) => CanvasLayer.fromJson(Map<String, dynamic>.from(v)))
          .toList(),
      cropX: number(j['cropX']),
      cropY: number(j['cropY']),
      beforeAsset: j['beforeSnapshotAssetId'],
      afterAsset: j['afterSnapshotAssetId'],
      updatedAt: DateTime.tryParse(j['updatedAt'] ?? ''),
    );
  }
  CanvasDocument copy() => CanvasDocument.fromJson(toJson());
}

class SceneInfo {
  final String id, name, subtitle;
  final int color;
  const SceneInfo(this.id, this.name, this.subtitle, this.color);
}

const scenes = [
  SceneInfo('cafe', '週末咖啡廳', '日常約會 · 午後', 0xffc9b29b),
  SceneInfo('gallery', '城市藝廊', '看展 · 留白的日常', 0xffddd6c8),
  SceneInfo('garden', '午後花園', '散步 · 微風與綠意', 0xffb7c3ab),
  SceneInfo('coast', '海邊假期', '旅行 · 藍色時刻', 0xffb7cbd1),
  SceneInfo('evening', '夜晚餐敘', '晚餐 · 一點儀式感', 0xff74656d),
];

List<Item> builtinItems() => [
  Item(id: 'tee_white', name: '奶油白短版上衣', kind: Kind.top, shape: 'tee'),
  Item(
    id: 'tee_rose',
    name: '乾燥玫瑰上衣',
    kind: Kind.top,
    shape: 'tee',
    color: 0xffb88782,
  ),
  Item(
    id: 'blouse',
    name: '法式綁帶襯衫',
    kind: Kind.top,
    shape: 'blouse',
    color: 0xfff1e3d0,
  ),
  Item(
    id: 'cardigan_blue',
    name: '霧藍針織外套',
    kind: Kind.outer,
    shape: 'cardigan',
    color: 0xff8fa9ba,
  ),
  Item(
    id: 'cardigan_wine',
    name: '酒紅針織外套',
    kind: Kind.outer,
    shape: 'cardigan',
    color: 0xff762e3d,
  ),
  Item(
    id: 'jeans',
    name: '靛藍直筒丹寧',
    kind: Kind.bottom,
    shape: 'jeans',
    color: 0xff435e72,
  ),
  Item(
    id: 'trousers',
    name: '奶茶西裝褲',
    kind: Kind.bottom,
    shape: 'trousers',
    color: 0xffb7a18c,
  ),
  Item(
    id: 'skirt',
    name: '墨黑傘裙',
    kind: Kind.bottom,
    shape: 'skirt',
    color: 0xff383235,
  ),
  Item(
    id: 'shoes_wine',
    name: '酒紅芭蕾鞋',
    kind: Kind.shoes,
    shape: 'shoes',
    color: 0xff762e3d,
  ),
  Item(
    id: 'shoes_cream',
    name: '奶油瑪莉珍',
    kind: Kind.shoes,
    shape: 'shoes',
    color: 0xffd9c8ad,
  ),
  Item(
    id: 'bag',
    name: '奶油肩背包',
    kind: Kind.accessory,
    shape: 'bag',
    color: 0xffe7d4b6,
  ),
  Item(
    id: 'bag_black',
    name: '小黑方包',
    kind: Kind.accessory,
    shape: 'bag',
    color: 0xff34302e,
  ),
  Item(
    id: 'hair_back',
    name: '自然長髮・後',
    kind: Kind.hairBack,
    shape: 'hair',
    color: 0xff352d29,
  ),
  Item(
    id: 'hair_front',
    name: '自然長髮・前',
    kind: Kind.hairFront,
    shape: 'fringe',
    color: 0xff352d29,
  ),
  Item(
    id: 'patch',
    name: '星星痘痘貼',
    kind: Kind.prop,
    shape: 'patch',
    color: 0xffedc774,
  ),
  Item(
    id: 'serum',
    name: '光澤精華',
    kind: Kind.prop,
    shape: 'bottle',
    color: 0xffb88767,
  ),
  Item(
    id: 'sunscreen',
    name: '日光防曬',
    kind: Kind.prop,
    shape: 'tube',
    color: 0xffe9d7a5,
  ),
  Item(
    id: 'comb',
    name: '木質小梳',
    kind: Kind.prop,
    shape: 'comb',
    color: 0xffac7954,
  ),
  Item(
    id: 'flower',
    name: '一朵小雛菊',
    kind: Kind.prop,
    shape: 'flower',
    color: 0xfff6ecdf,
  ),
  Item(
    id: 'coffee',
    name: '拿鐵時間',
    kind: Kind.prop,
    shape: 'cup',
    color: 0xffd3b597,
  ),
  Item(
    id: 'ribbon',
    name: '緞帶蝴蝶結',
    kind: Kind.prop,
    shape: 'ribbon',
    color: 0xff762e3d,
  ),
  Item(
    id: 'sparkle',
    name: '閃亮登場',
    kind: Kind.prop,
    shape: 'sparkle',
    color: 0xffd7b878,
  ),
];
