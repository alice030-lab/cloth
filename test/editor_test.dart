import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/sembast_io.dart';
import 'package:outfit_canvas/core/models.dart';
import 'package:outfit_canvas/core/controller.dart';
import 'package:outfit_canvas/data/repository.dart';

class BrokenRepository extends Repository {
  BrokenRepository(super.db);
  @override
  Future<void> saveDraft(CanvasDocument doc) async =>
      throw const FileSystemException('simulated full disk');
}

class PausedClearRepository extends Repository {
  final started = Completer<void>(), release = Completer<void>();
  PausedClearRepository(super.db);
  @override
  Future<void> clear() async {
    started.complete();
    await release.future;
    await super.clear();
  }
}

void main() {
  late EditorController e;
  setUp(() async {
    e = EditorController(
      Repository(await databaseFactoryMemory.openDatabase('test_${newId()}')),
    );
    await e.initialize();
  });
  tearDown(() async {
    e.dispose();
    await e.repo.db.close();
  });
  test(
    'care applies on first tap and undo restores the previous used state',
    () {
      e.add(e.item('serum'));
      expect(e.stageDone(1), isTrue);
      expect(e.careKind, 'serum');
      e.useCare(e.doc.layers.single);
      expect(e.stageDone(1), isFalse);
      e.undo();
      expect(e.stageDone(1), isTrue);
      e.remove(e.doc.layers.single.id);
      expect(e.stageDone(1), isFalse);
      expect(
        builtinItems().where((i) => i.kind == Kind.prop).length,
        greaterThanOrEqualTo(8),
      );
    },
  );
  test(
    'a patch is small, placed on the cheek and applies in one undo step',
    () {
      e.add(e.item('patch'));
      final patch = e.doc.layers.single;
      expect(patch.scale, .03);
      expect(patch.activated, isTrue);
      expect(patch.x, lessThan(e.anchor('faceCenter').dx));
      expect(e.selected, isNull);
      expect(e.guideDone, isTrue);
      e.undo();
      expect(e.doc.layers, isEmpty);
    },
  );
  test('body values reject invalid measurements without mutating', () {
    final b = BodyProfile();
    expect(() => b.set('waist', double.nan), throwsArgumentError);
    expect(() => b.set('waist', -1), throwsArgumentError);
    expect(b.waist, 68);
  });
  test('photographic proportions deform locally and roundtrip appearance', () {
    final base = FigureGeometry(BodyProfile());
    final profile = BodyProfile(bust: 120);
    final bust = FigureGeometry(profile);
    expect(
      bust.deformPhotograph(.62, .29).dx,
      greaterThan(base.deformPhotograph(.62, .29).dx),
    );
    expect(
      (bust.deformPhotograph(.62, .49).dx - base.deformPhotograph(.62, .49).dx)
          .abs(),
      lessThan(.00001),
    );
    expect(BodyProfile.fromJson(profile.toJson()).appearance, 'photo');
    profile.appearance = 'illustration';
    expect(BodyProfile.fromJson(profile.toJson()).appearance, 'illustration');
  });
  test('photographic mesh stays ordered at supported measurement extremes', () {
    for (final upper in [false, true]) {
      final profile = BodyProfile();
      for (final entry in BodyProfile.ranges.entries) {
        profile.set(entry.key, upper ? entry.value.$2 : entry.value.$1);
      }
      final geometry = FigureGeometry(profile);
      for (var row = 0; row <= 80; row++) {
        var previous = double.negativeInfinity;
        for (var col = 0; col <= 32; col++) {
          final point = geometry.deformPhotograph(col / 32, row / 80);
          expect(point.dx.isFinite && point.dy.isFinite, isTrue);
          expect(point.dx, greaterThan(previous));
          previous = point.dx;
        }
      }
    }
  });
  test('chest waist hip control points vary independently', () {
    final b = BodyProfile(), g = FigureGeometry(BodyProfile());
    b.bust = 100;
    final changed = FigureGeometry(b);
    expect(changed.chest, greaterThan(g.chest));
    expect(changed.waist, g.waist);
    expect(changed.hip, g.hip);
    b.waist = 90;
    expect(FigureGeometry(b).waist, greaterThan(g.waist));
  });
  test('height and shoulder produce independent geometry', () {
    final b = BodyProfile(height: 180, shoulder: 45);
    final g = FigureGeometry(b), base = FigureGeometry(BodyProfile());
    expect(g.legEnd, greaterThan(base.legEnd));
    expect(g.shoulder, greaterThan(base.shoulder));
    expect(g.chest, base.chest);
  });
  test('all 14 anchors are finite and normalized', () {
    final g = FigureGeometry(BodyProfile());
    expect(g.anchors.length, 14);
    for (final name in g.anchors.keys) {
      final p = g.normalized(name);
      expect(p.dx, inInclusiveRange(0, 1));
      expect(p.dy, inInclusiveRange(0, 1));
    }
  });
  test('new shirt uses shoulder anchor and correct layer', () {
    e.add(e.item('tee_white'));
    final l = e.doc.layers.single;
    expect(l.z, 5);
    expect(l.snappedTo, 'shoulderCenter');
    expect(Offset(l.x, l.y), e.attachmentPoint(l));
  });
  test('drag-drop starts at free location', () {
    e.add(e.item('tee_white'), at: const Offset(.2, .3));
    expect(e.doc.layers.single.snappedTo, isNull);
    expect(e.doc.layers.single.x, .2);
  });
  test('snap uses logical pixel distance, free position remains outside', () {
    e.add(e.item('tee_white'));
    final l = e.doc.layers.single;
    final a = e.attachmentPoint(l);
    l.x = a.dx + 23 / 400;
    l.snappedTo = null;
    e.finishGesture(l, const Size(400, 600));
    expect(l.snappedTo, 'shoulderCenter');
    l.x = a.dx + 25 / 400;
    l.snappedTo = null;
    e.finishGesture(l, const Size(400, 600));
    expect(l.snappedTo, isNull);
  });
  test('body update resizes attached clothes but preserves free items', () {
    e.add(e.item('tee_white'));
    e.add(e.item('tee_rose'), at: const Offset(.2, .3));
    final old = e.doc.layers.first.scale;
    final b = e.doc.body.copy()..shoulder = 48;
    e.body(b);
    expect(e.doc.layers.first.scale, greaterThan(old));
    expect(e.doc.layers.last.x, .2);
    expect(e.doc.layers.last.y, .3);
  });
  test('all wearable defaults fit uniformly for every avatar gender', () {
    for (final gender in ['feminine', 'masculine', 'neutral']) {
      e.body(e.doc.body.copy()..gender = gender);
      for (final it in e.items.where((it) => it.kind.anchor != null)) {
        e.add(it);
        final layer = e.doc.layers.last;
        expect(layer.widthScale, 1, reason: '$gender ${it.id}');
        expect(Offset(layer.x, layer.y), e.attachmentPoint(layer));
        expect(layer.scale.isFinite && layer.scale > 0, true);
      }
    }
  });
  test('near-body drop attaches but distant drop stays free', () {
    e.add(e.item('tee_white'));
    final point = e.attachmentPoint(e.doc.layers.last);
    e.add(e.item('tee_rose'), at: point + const Offset(.01, .01));
    expect(e.doc.layers.last.snappedTo, 'shoulderCenter');
    expect(
      Offset(e.doc.layers.last.x, e.doc.layers.last.y),
      e.attachmentPoint(e.doc.layers.last),
    );
  });
  test('hair translates scales and rotates together in one undo', () {
    e.add(e.item('hair_front'));
    e.checkpoint();
    final front = e.doc.layers.last;
    final before = front.copy();
    front.x = .6;
    front.y = .13;
    front.scale = .4;
    front.rotation = .2;
    front.snappedTo = null;
    e.liveUpdate(front);
    final back = e.doc.layers.first;
    expect((back.x - front.x).abs(), lessThan(.01));
    expect(back.y, greaterThan(front.y));
    expect(back.scale, front.scale);
    expect(back.rotation, front.rotation);
    e.finishGesture(front, const Size(400, 500));
    e.undo();
    for (final layer in e.doc.layers) {
      expect(layer.x, before.x);
      expect(layer.scale, before.scale);
      expect(Offset(layer.x, layer.y), e.attachmentPoint(layer));
    }
  });
  test('fit all repairs old free wearables and undo restores user edits', () {
    e.add(e.item('bag'));
    final layer = e.doc.layers.single;
    layer.x = .2;
    layer.y = .7;
    layer.widthScale = 1.35;
    layer.rotation = .6;
    layer.snappedTo = null;
    e.fitAll();
    expect(layer.widthScale, 1);
    expect(layer.rotation, 0);
    expect(layer.snappedTo, 'shoulderRight');
    e.undo();
    expect(e.doc.layers.single.x, .2);
    expect(e.doc.layers.single.widthScale, 1.35);
  });
  test('imported aspect is preserved regardless of shape label', () {
    final item = Item(
      id: 'import',
      name: 'import',
      kind: Kind.bottom,
      shape: 'jeans',
      assetId: 'asset',
      aspect: .71,
    );
    expect(item.naturalAspect, .71);
  });
  test('pants waistband follows waist without stretching source pixels', () {
    e.add(e.item('jeans'));
    final layer = e.doc.layers.last;
    final aspect = layer.fittedAspect!;
    expect(aspect, greaterThan(e.item('jeans').naturalAspect));
    expect(layer.copy().fittedAspect, aspect);
    e.body(e.doc.body.copy()..waist = 100);
    expect(layer.fittedAspect, greaterThan(aspect));
    final saved = CanvasDocument.fromJson(e.doc.toJson());
    expect(saved.layers.last.fittedAspect, layer.fittedAspect);
  });
  test('legacy accessory center migrates once to top registration', () {
    final json = CanvasLayer(
      id: 'old',
      itemId: 'bag',
      kind: Kind.accessory,
      y: .4,
      scale: .2,
    ).toJson()..remove('fitted_aspect');
    final migrated = CanvasLayer.fromJson(json);
    expect(migrated.y, closeTo(.4 - .2 * .94 / 2, .00001));
    expect(migrated.copy().y, migrated.y);
  });
  test(
    'shoe stance survives detaching resizing and saving without stretching',
    () {
      e.body(e.doc.body.copy()..gender = 'masculine');
      e.add(e.item('shoes_wine'));
      final layer = e.doc.layers.last;
      final fitted = layer.fittedAspect;
      expect(fitted, greaterThan(e.item('shoes_wine').naturalAspect));
      layer.snappedTo = null;
      layer.x = .2;
      layer.y = .3;
      layer.scale *= 1.2;
      e.finishGesture(layer, const Size(400, 500));
      expect(layer.fittedAspect, fitted);
      expect(layer.widthScale, 1);
      expect(layer.copy().fittedAspect, fitted);
    },
  );
  test('hair pair remains split across body and is removed as pair', () {
    e.add(e.item('hair_front'));
    expect(e.doc.layers.map((l) => l.z), containsAll([1, 6]));
    e.remove(e.doc.layers.first.id);
    expect(e.doc.layers, isEmpty);
  });
  test('sorting cannot move rear hair above clothing', () {
    e.add(e.item('hair_front'));
    e.add(e.item('tee_white'));
    final rear = e.doc.layers.firstWhere((l) => l.kind == Kind.hairBack);
    e.reorder(rear, true);
    expect(e.doc.sorted.first.kind, Kind.hairBack);
  });
  test('one gesture transaction restores original transform', () {
    e.add(e.item('tee_white'));
    final original = e.doc.layers.single.copy();
    e.checkpoint();
    final l = e.doc.layers.single;
    l.x = .7;
    l.y = .6;
    l.rotation = .5;
    l.scale = .5;
    e.finishGesture(l, const Size(400, 600));
    e.undo();
    expect(e.doc.layers.single.toJson(), original.toJson());
    e.redo();
    expect(e.doc.layers.single.rotation, .5);
  });
  test('new edit clears redo and supports 50 history entries', () {
    e.add(e.item('tee_white'));
    e.undo();
    expect(e.canRedo, isTrue);
    e.add(e.item('jeans'));
    expect(e.canRedo, isFalse);
    for (var i = 0; i < 55; i++) {
      e.add(e.item('patch'));
    }
    for (var i = 0; i < 50; i++) {
      e.undo();
    }
    expect(e.canUndo, isFalse);
  });
  test('document roundtrip retains transforms assets body and framing', () {
    e.theme();
    e.doc.beforeAsset = 'before';
    e.doc.afterAsset = 'after';
    e.doc.cropX = .4;
    e.doc.cropY = -.3;
    e.doc.layers.first.rotation = .8;
    e.doc.layers.first.widthScale = 1.35;
    final copy = CanvasDocument.fromJson(e.doc.toJson());
    expect(copy.toJson(), e.doc.toJson());
  });
  test('unsupported schema fails explicitly', () {
    expect(
      () => CanvasDocument.fromJson({'schemaVersion': 99}),
      throwsFormatException,
    );
  });
  test('theme is one undo and preserves custom items', () async {
    final it = Item(
      id: 'custom',
      name: 'My shirt',
      kind: Kind.top,
      assetId: 'custom_image',
    );
    await e.addImported(it, Uint8List.fromList([1, 2, 3]));
    e.add(it);
    e.theme();
    expect(e.doc.layers.any((l) => l.itemId == 'custom'), isTrue);
    e.undo();
    expect(e.doc.layers.length, 1);
  });
  test(
    'wardrobe deletion retains images referenced by saved outfits',
    () async {
      final it = Item(
        id: 'custom',
        name: 'My shirt',
        kind: Kind.top,
        assetId: 'custom_image',
      );
      await e.addImported(it, Uint8List.fromList([1, 2, 3]));
      e.add(it);
      await e.saveOutfit();
      await e.hide(it);
      expect((await e.repo.outfits()).single.layers.single.itemId, 'custom');
      expect(await e.repo.asset('custom_image'), [1, 2, 3]);
    },
  );
  test('builtin rename and hidden status survive controller restart', () async {
    await e.rename(e.item('tee_white'), '我的白 T');
    await e.hide(e.item('tee_white'));
    final other = EditorController(e.repo);
    await other.initialize();
    expect(other.item('tee_white').name, '我的白 T');
    expect(other.item('tee_white').hidden, isTrue);
    other.dispose();
  });
  test(
    'garbage collection preserves hidden outfit references and removes orphan snapshots',
    () async {
      final it = Item(
        id: 'custom_gc',
        name: 'shirt',
        kind: Kind.top,
        assetId: 'image_gc',
      );
      await e.addImported(it, Uint8List.fromList([1, 2, 3]));
      e.add(it);
      await e.saveOutfit();
      await e.hide(it);
      await e.repo.putAsset('orphan', Uint8List.fromList([9]));
      await e.repo.collectGarbage();
      expect(await e.repo.asset('image_gc'), [1, 2, 3]);
      expect(await e.repo.asset('orphan'), isNull);
    },
  );
  test('autosave during clear cannot resurrect a removed draft', () async {
    final repo = PausedClearRepository(
      await databaseFactoryMemory.openDatabase('clear_race_${newId()}'),
    );
    final controller = EditorController(repo);
    await controller.initialize();
    controller.add(controller.item('tee_white'));
    await controller.flush();
    final clearing = controller.clearAll();
    await repo.started.future;
    expect(controller.hasPendingOperation, isTrue);
    expect(await controller.flush(), isFalse);
    repo.release.complete();
    await clearing;
    expect(controller.hasPendingOperation, isFalse);
    expect(await repo.draft(), isNull);
    controller.dispose();
    await repo.db.close();
  });
  test('clear removes documents binary assets and profile data', () async {
    await e.repo.putAsset('private', Uint8List.fromList([1, 2]));
    await e.welcome();
    e.theme();
    await e.saveOutfit();
    await e.clearAll();
    expect(await e.repo.outfits(), isEmpty);
    expect(await e.repo.asset('private'), isNull);
    expect(await e.repo.draft(), isNull);
    expect(await e.repo.welcomed(), isFalse);
  });
  test('save failure is surfaced and in-memory edits are retained', () async {
    final db = await databaseFactoryMemory.openDatabase('fail_${newId()}');
    final broken = EditorController(BrokenRepository(db));
    await broken.initialize();
    broken.add(broken.item('tee_white'));
    expect(await broken.flush(), isFalse);
    expect(broken.status, startsWith('儲存失敗'));
    expect(broken.doc.layers.length, 1);
    expect(() => broken.saveOutfit(), throwsStateError);
    broken.dispose();
    await db.close();
  });
  test(
    'actual file database restores editable draft after close/reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('outfit_test_');
      final path = '${dir.path}/db';
      var db = await databaseFactoryIo.openDatabase(path);
      final first = EditorController(Repository(db));
      await first.initialize();
      first.theme();
      first.doc.layers.last.x = .72;
      first.doc.layers.first.scale *= 1.2;
      first.doc.layers.first.widthScale = 1.35;
      await first.saveOutfit();
      final json = first.doc.toJson();
      first.dispose();
      await db.close();
      db = await databaseFactoryIo.openDatabase(path);
      final second = EditorController(Repository(db));
      await second.initialize();
      expect(second.doc.toJson(), json);
      expect((await second.repo.outfits()).single.toJson(), json);
      second.add(second.item('patch'));
      expect(second.doc.layers.length, (json['layers'] as List).length + 1);
      expect(second.doc.layers.last.itemId, 'patch');
      await second.flush();
      second.dispose();
      await db.close();
      await dir.delete(recursive: true);
    },
  );
}
