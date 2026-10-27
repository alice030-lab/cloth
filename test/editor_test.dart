import 'dart:io';
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
  test('body values reject invalid measurements without mutating', () {
    final b = BodyProfile();
    expect(() => b.set('waist', double.nan), throwsArgumentError);
    expect(() => b.set('waist', -1), throwsArgumentError);
    expect(b.waist, 68);
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
    expect(Offset(l.x, l.y), e.anchor('shoulderCenter'));
  });
  test('drag-drop starts at free location', () {
    e.add(e.item('tee_white'), at: const Offset(.2, .3));
    expect(e.doc.layers.single.snappedTo, isNull);
    expect(e.doc.layers.single.x, .2);
  });
  test('snap uses logical pixel distance, free position remains outside', () {
    e.add(e.item('tee_white'));
    final l = e.doc.layers.single, a = e.anchor('shoulderCenter');
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
      expect(second.doc.layers.length, 7);
      await second.flush();
      second.dispose();
      await db.close();
      await dir.delete(recursive: true);
    },
  );
}
