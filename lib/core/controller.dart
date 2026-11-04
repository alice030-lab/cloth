import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../data/repository.dart';
import 'models.dart';

class EditorController extends ChangeNotifier {
  final Repository repo;
  CanvasDocument doc = CanvasDocument();
  List<Item> items = builtinItems();
  String? selected;
  String status = '已儲存';
  String? loadError;
  bool welcomed = false;
  bool guideDone = false;
  int careEvent = 0;
  String? careKind;
  final List<CanvasDocument> _undo = [], _redo = [];
  Timer? _timer;
  Future<void> _writes = Future.value();
  int _revision = 0;
  bool _disposed = false;
  bool _clearing = false;
  int _operations = 0;
  bool get hasPendingOperation => _clearing || _operations > 0;
  void beginOperation() => _operations++;
  void endOperation() {
    if (_operations > 0) _operations--;
  }

  EditorController(this.repo);
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  CanvasLayer? get selection {
    for (final l in doc.layers) {
      if (l.id == selected) {
        return l;
      }
    }
    return null;
  }

  Item item(String id) => items.firstWhere(
    (i) => i.id == id,
    orElse: () =>
        Item(id: id, name: '素材遺失', kind: Kind.reference, shape: 'missing'),
  );
  Future<void> initialize() async {
    final merged = {for (final item in builtinItems()) item.id: item};
    for (final item in await repo.items()) {
      merged[item.id] = item;
    }
    items = merged.values.toList();
    welcomed = await repo.welcomed();
    guideDone = await repo.guided();
    try {
      final j = await repo.draft();
      if (j != null) {
        doc = CanvasDocument.fromJson(j);
        // Only migrate documents from before avatar registration was stored.
        // Current documents must keep the exact scale and width the user saved.
        final profile = j['bodyParams'];
        if (profile is Map && !profile.containsKey('appearance')) {
          for (final layer in doc.layers.where((l) => l.snappedTo != null)) {
            snap(layer);
          }
        }
      }
    } catch (_) {
      loadError = '草稿無法讀取，原始資料仍保留。請先備份資料，再建立新作品。';
      status = '讀取失敗';
    }
    notifyListeners();
  }

  void checkpoint() {
    _undo.add(doc.copy());
    if (_undo.length > 50) {
      _undo.removeAt(0);
    }
    _redo.clear();
  }

  void change(VoidCallback edit) {
    checkpoint();
    edit();
    doc.afterAsset = null;
    changed();
  }

  void changed() {
    doc.updatedAt = DateTime.now();
    status = '儲存中';
    _revision++;
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () => flush());
  }

  Future<bool> flush() async {
    if (_clearing) return false;
    _timer?.cancel();
    if (loadError != null) {
      return false;
    }
    final snapshot = doc.copy(), revision = _revision;
    var success = true;
    _writes = _writes.then((_) async {
      try {
        await repo.saveDraft(snapshot);
        if (revision == _revision) {
          status = '已儲存';
        }
      } catch (_) {
        success = false;
        if (revision == _revision) {
          status = '儲存失敗・點此重試';
        }
      }
      if (!_disposed) {
        notifyListeners();
      }
    });
    await _writes;
    return success;
  }

  void undo() {
    if (!canUndo) {
      return;
    }
    _redo.add(doc.copy());
    doc = _undo.removeLast();
    selected = null;
    changed();
  }

  void redo() {
    if (!canRedo) {
      return;
    }
    _undo.add(doc.copy());
    doc = _redo.removeLast();
    selected = null;
    changed();
  }

  void select(String? id) {
    selected = id;
    notifyListeners();
  }

  void liveUpdate([CanvasLayer? layer]) {
    if (layer != null) syncHair(layer);
    notifyListeners();
  }

  void tapLayer(CanvasLayer layer) {
    final front = doc.layers
        .where((other) => other.z == layer.z)
        .every((other) => other.order <= layer.order);
    if (!front) {
      reorder(layer, true);
    }
    select(layer.id);
  }

  double get figureWidth => .66;
  // Figure is rendered in a width .66, height .94 viewport, centered.
  Offset anchor(String name) {
    final a = FigureGeometry(doc.body).normalized(name);
    return Offset(.17 + a.dx * .66, .025 + a.dy * .94);
  }

  double shoulderWidth() {
    final geometry = FigureGeometry(doc.body);
    return (geometry.normalized('shoulderRight').dx -
            geometry.normalized('shoulderLeft').dx) *
        .66;
  }

  /// The registration point belongs to the artwork, not its bounding-box top.
  Offset attachmentPoint(CanvasLayer l) {
    final a = l.kind.anchor;
    if (a == null) return Offset(l.x, l.y);
    final p = anchor(a);
    final inset = switch (l.kind) {
      Kind.top || Kind.outer => .08,
      Kind.shoes => .16,
      Kind.hairFront => .08,
      _ => 0.0,
    };
    return Offset(p.dx, p.dy - l.scale * .94 * inset);
  }

  void snap(CanvasLayer l) {
    final a = l.kind.anchor;
    if (a == null) return;
    final it = item(l.itemId);
    // Never stretch an auto-fitted sprite horizontally. Width and height share
    // one scale, including imported images and all avatar presentations.
    l.widthScale = 1;
    l.fittedAspect = null;
    l.rotation = 0;
    final geometry = FigureGeometry(doc.body);
    if (l.kind == Kind.bottom) {
      l.scale = it.shape == 'skirt'
          ? .43
          : geometry.normalized('ankleCenter').dy -
                geometry.normalized('waistCenter').dy;
    } else if (l.kind == Kind.shoes) {
      l.scale = .075;
      final span = switch (doc.body.gender) {
        'masculine' => .34,
        'neutral' => .31,
        _ => .26,
      };
      if (!it.custom) {
        l.fittedAspect = math.max(
          it.naturalAspect,
          span * .82 * .8 / (.075 * .94),
        );
      }
    } else if (l.kind == Kind.hairBack || l.kind == Kind.hairFront) {
      // Both cells contain a whole hairstyle. The front cell has an inset
      // face opening; registering it at its bounding-box crown hides the eyes.
      l.scale = .20;
    } else if (l.kind == Kind.accessory) {
      l.scale = .24;
    } else {
      final shoulderSpan = switch (it.id) {
        'tee_white' || 'tee_rose' => .72,
        'blouse' || 'cardigan_blue' || 'cardigan_wine' => .68,
        _ => 1 / l.kind.widthRatio,
      };
      l.scale =
          (shoulderWidth() / shoulderSpan / it.naturalAspect * (4 / 5) / .94)
              .clamp(.03, 2)
              .toDouble();
    }
    if (!it.custom && (it.id == 'jeans' || it.id == 'trousers')) {
      double waistSpan;
      if (doc.body.appearance == 'photo') {
        final y = doc.body.gender == 'feminine' ? .415 : .47;
        final left = geometry.deformPhotograph(.33, y);
        final right = geometry.deformPhotograph(.67, y);
        waistSpan = (right.dx - left.dx) * .82;
      } else {
        waistSpan = geometry.waist * 2 / 300 * .66;
      }
      // Match the waistband and leg length, covering the target rectangle with
      // the source uniformly. Excess hem is cropped, never squashed sideways.
      final height = l.scale * .94;
      l.fittedAspect = math.max(
        it.naturalAspect,
        waistSpan / .75 * .8 / height,
      );
    }
    final p = attachmentPoint(l);
    l.x = p.dx;
    l.y = p.dy;
    l.snappedTo = a;
    syncHair(l);
  }

  /// Treat the front and back of the built-in hairstyle as one transform.
  void syncHair(CanvasLayer source) {
    if (source.itemId != 'hair_front' && source.itemId != 'hair_back') return;
    for (final other in doc.layers) {
      if (other.id == source.id ||
          (other.itemId != 'hair_front' && other.itemId != 'hair_back')) {
        continue;
      }
      final inset =
          (source.kind == Kind.hairFront ? .08 : 0) -
          (other.kind == Kind.hairFront ? .08 : 0);
      final offset = inset * source.scale * .94;
      other.x = source.x - math.sin(source.rotation) * offset * 1.25;
      other.y = source.y + math.cos(source.rotation) * offset;
      other.scale = source.scale;
      other.rotation = source.rotation;
      other.widthScale = source.widthScale;
      other.snappedTo = source.snappedTo;
    }
  }

  void markGuided() {
    guideDone = true;
    unawaited(repo.setGuided().catchError((Object error) {}));
    notifyListeners();
  }

  void useCare(CanvasLayer layer) {
    final id = item(layer.itemId).id;
    if (id != 'patch' && id != 'serum') return;
    change(() {
      layer.activated = !layer.activated;
      if (layer.activated) {
        careKind = id;
        careEvent++;
      }
    });
  }

  void add(Item it, {Offset? at}) {
    final face = anchor('faceCenter');
    final care = it.id == 'patch' || it.id == 'serum';
    final nearFace =
        at != null &&
        (Offset((at.dx - face.dx) * .8, at.dy - face.dy)).distance < .10;
    final applyCare = care && (at == null || nearFace);
    if (applyCare && !guideDone) markGuided();
    change(() {
      final group = it.id == 'hair_back' || it.id == 'hair_front';
      final addItems = group
          ? items
                .where((i) => i.id == 'hair_back' || i.id == 'hair_front')
                .toList()
          : [it];
      for (final i in addItems) {
        if (group) {
          doc.layers.removeWhere((l) => l.kind == i.kind);
        }
        final l = CanvasLayer(
          id: newId(),
          itemId: i.id,
          kind: i.kind,
          order: doc.layers.length + 1,
          scale: i.id == 'patch'
              ? .03
              : i.id == 'serum'
              ? .12
              : i.kind == Kind.reference
              ? .4
              : .15,
        );
        snap(l);
        if (at != null) {
          final target = attachmentPoint(l);
          final nearAttachment =
              i.kind.anchor != null &&
              Offset((at.dx - target.dx) * .8, at.dy - target.dy).distance <
                  .10;
          if (!nearAttachment) {
            l.x = at.dx;
            l.y = at.dy;
            l.snappedTo = null;
          }
        } else if (i.kind.anchor == null) {
          l.x = i.id == 'patch' ? face.dx - .025 : .68;
          l.y = i.id == 'patch' ? face.dy + .012 : .48;
        }
        if (applyCare) {
          l.activated = true;
          careKind = i.id;
          careEvent++;
        }
        doc.layers.add(l);
        syncHair(l);
        selected = applyCare ? null : l.id;
      }
    });
  }

  void remove(String id) {
    change(() {
      final l = doc.layers.firstWhere((l) => l.id == id);
      if (l.itemId == 'hair_back' || l.itemId == 'hair_front') {
        doc.layers.removeWhere(
          (l) => l.itemId == 'hair_back' || l.itemId == 'hair_front',
        );
      } else {
        doc.layers.removeWhere((l) => l.id == id);
      }
      selected = null;
    });
  }

  void reorder(CanvasLayer l, bool front) {
    change(() {
      final orders = doc.layers.where((a) => a.z == l.z).map((a) => a.order);
      l.order =
          (front ? orders.reduce(math.max) : orders.reduce(math.min)) +
          (front ? 1 : -1);
    });
  }

  void finishGesture(CanvasLayer l, Size size) {
    doc.afterAsset = null;
    final a = l.kind.anchor;
    if (a != null) {
      final target = attachmentPoint(l);
      final d = Offset(
        (l.x - target.dx) * size.width,
        (l.y - target.dy) * size.height,
      ).distance;
      if (d <= 24) {
        // Reattach position without undoing the user's pinch or width edit.
        // Explicit "貼回錨點" and body updates still recalculate default sizing.
        l.x = target.dx;
        l.y = target.dy;
        l.snappedTo = a;
      }
    }
    syncHair(l);
    changed();
  }

  void fitAll() => change(() {
    for (final layer in doc.layers) {
      if (layer.kind.anchor != null) snap(layer);
    }
    selected = null;
  });

  void body(BodyProfile b) => change(() {
    doc.body = b;
    for (final l in doc.layers) {
      if (l.snappedTo != null) {
        snap(l);
      }
    }
  });
  void scene(String id, {double x = 0, double y = 0}) => change(() {
    doc.scene = id;
    doc.cropX = x;
    doc.cropY = y;
  });
  void theme() => change(() {
    doc.scene = 'cafe';
    doc.layers.removeWhere((l) => !item(l.itemId).custom);
    for (final id in [
      if (doc.body.appearance != 'photo') 'hair_back',
      if (doc.body.appearance != 'photo') 'hair_front',
      'tee_white',
      'jeans',
      'shoes_wine',
      'bag',
    ]) {
      final it = item(id);
      final l = CanvasLayer(
        id: newId(),
        itemId: id,
        kind: it.kind,
        order: doc.layers.length + 1,
      );
      snap(l);
      doc.layers.add(l);
    }
    selected = null;
  });
  bool stageDone(int stage) => switch (stage) {
    0 => true,
    1 => doc.layers.any((l) => l.kind == Kind.prop && l.activated),
    2 => doc.layers.any((l) => l.kind == Kind.hairFront),
    3 => doc.layers.any((l) => l.kind == Kind.top || l.kind == Kind.bottom),
    4 => doc.afterAsset != null,
    _ => false,
  };
  Future<void> saveOutfit() async {
    if (!await flush()) {
      throw StateError('草稿儲存失敗');
    }
    await repo.saveOutfit(doc.copy());
    try {
      await repo.collectGarbage();
    } catch (_) {
      status = '已儲存・空間清理稍後重試';
      notifyListeners();
    }
  }

  void open(CanvasDocument d) {
    _undo.clear();
    _redo.clear();
    doc = d.copy();
    selected = null;
    changed();
  }

  void duplicate(CanvasDocument d) {
    final copy = d.copy();
    copy.id = newId();
    copy.name = '${d.name}・副本';
    open(copy);
  }

  Future<void> fresh() async {
    if (!await flush()) {
      throw StateError('請先處理儲存失敗');
    }
    doc = CanvasDocument(body: doc.body.copy());
    _undo.clear();
    _redo.clear();
    selected = null;
    changed();
  }

  Future<void> addImported(Item it, Uint8List bytes) async {
    await repo.putAsset(it.assetId!, bytes);
    await repo.saveItem(it);
    items.add(it);
    notifyListeners();
  }

  Future<void> hide(Item it) async {
    await repo.hideItem(it);
    notifyListeners();
  }

  Future<void> rename(Item it, String name) async {
    it.name = name;
    await repo.saveItem(it);
    notifyListeners();
  }

  Future<void> welcome() async {
    await repo.setWelcomed();
    welcomed = true;
    notifyListeners();
  }

  Future<void> clearAll() async {
    if (_clearing) return;
    _clearing = true;
    try {
      _timer?.cancel();
      await _writes;
      await repo.clear();
      doc = CanvasDocument();
      items = builtinItems();
      _undo.clear();
      _redo.clear();
      selected = null;
      welcomed = false;
      guideDone = false;
      loadError = null;
      status = '已清除本機資料';
      notifyListeners();
    } finally {
      _clearing = false;
    }
  }

  String serialize() => jsonEncode(doc.toJson());
  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
