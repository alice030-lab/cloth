import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:outfit_canvas/core/models.dart';
import 'package:outfit_canvas/core/images.dart';
import 'package:outfit_canvas/core/controller.dart';
import 'package:outfit_canvas/data/repository.dart';
import 'package:outfit_canvas/main.dart';
import 'package:outfit_canvas/features/panels.dart';
import 'package:outfit_canvas/features/canvas_view.dart';
import 'package:outfit_canvas/features/import_editor.dart';
import 'package:outfit_canvas/painting/fashion.dart';

void main() {
  // Sembast yields with real-time timers; disable only that scheduler for
  // WidgetTester fake time. Persistence operations and assertions remain real.
  setUpAll(() async {
    disableSembastCooperator();
    // Decode real sprite pixels outside WidgetTester fake time. Hit tests use
    // the real transparency mask, not a placeholder or a mocked rectangle.
    await Future.wait(
      [
        'garments',
        'extras',
        'accessories',
        'footwear',
        'avatar',
        'scenes',
      ].map(FashionImages.load),
    );
  });
  tearDownAll(enableSembastCooperator);
  late EditorController editor;
  setUp(() async {
    editor = EditorController(
      Repository(await databaseFactoryMemory.openDatabase('widget_${newId()}')),
    );
    await editor.initialize();
    await editor.welcome();
  });
  Future<void> drain(WidgetTester tester, Future<dynamic> future) async {
    var done = false;
    future.whenComplete(() => done = true);
    for (var i = 0; i < 100 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    expect(
      done,
      isTrue,
      reason:
          'Storage must complete while both real and fake event queues are drained',
    );
    await future;
  }

  Future<void> cleanup(WidgetTester tester) async {
    await drain(tester, editor.flush());
    editor.dispose();
    await tester.runAsync(() => editor.repo.db.close());
  }

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('editor fits ${size.width}×${size.height}', (tester) async {
      addTearDown(() => cleanup(tester));
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(OutfitApp(editor: editor));
      await tester.pumpAndSettle();
      expect(find.text('完成穿搭'), findsOneWidget);
      expect(find.text('我的替身'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('text scale 1.5 keeps primary actions accessible', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(OutfitApp(editor: editor));
    await tester.pumpAndSettle();
    expect(find.text('完成穿搭'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('body cancel leaves document untouched; apply is undoable', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    await tester.pumpWidget(OutfitApp(editor: editor));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的替身'));
    await tester.pumpAndSettle();
    expect(find.byType(BodyPanel), findsOneWidget);
    await tester.tap(find.byTooltip('取消'));
    await tester.pumpAndSettle();
    expect(editor.doc.body.height, 165);
    await tester.tap(find.text('我的替身'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('套用'));
    await tester.pumpAndSettle();
    expect(editor.canUndo, isTrue);
  });
  testWidgets('saved outfit list reopens editable layers', (tester) async {
    addTearDown(() => cleanup(tester));
    await tester.runAsync(() async {
      editor.theme();
      await editor.saveOutfit();
    });
    final count = editor.doc.layers.length;
    await tester.pumpWidget(OutfitApp(editor: editor));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('作品集'));
    await tester.pumpAndSettle();
    expect(find.text('我的週末穿搭'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.checkroom));
    await drain(tester, editor.flush());
    await tester.pumpAndSettle();
    expect(find.text('完成穿搭'), findsOneWidget);
    expect(editor.doc.layers.length, count);
    editor.add(editor.item('patch'));
    await tester.pumpAndSettle();
    expect(editor.doc.layers.length, count + 1);
    await drain(tester, editor.flush());
  });
  testWidgets('canvas pointer drag changes position and releases snap', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    editor.theme();
    await tester.pumpWidget(OutfitApp(editor: editor));
    await tester.pumpAndSettle();
    final original = editor.doc.layers
        .firstWhere((l) => l.itemId == 'tee_white')
        .copy();
    final target = find.byWidgetPredicate(
      (w) => w is GestureLayer && w.layer.itemId == 'tee_white',
    );
    await tester.drag(target, const Offset(35, 60));
    await tester.pumpAndSettle();
    final current = editor.doc.layers.firstWhere(
      (l) => l.itemId == 'tee_white',
    );
    expect(current.x, isNot(original.x));
    expect(current.y, greaterThan(original.y));
    expect(current.snappedTo, isNull);
    await drain(tester, editor.flush());
  });
  testWidgets('two pointers translate scale rotate and undo as one gesture', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    editor.add(editor.item('tee_white'), at: const Offset(.5, .4));
    final original = editor.doc.layers.single.copy();
    await tester.pumpWidget(OutfitApp(editor: editor));
    await tester.pumpAndSettle();
    final target = find.byWidgetPredicate(
      (w) => w is GestureLayer && w.layer.itemId == 'tee_white',
    );
    final center = tester.getCenter(target);
    final first = await tester.startGesture(
      center - const Offset(14, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(14, 0),
      pointer: 2,
    );
    await first.moveTo(center + const Offset(-20, 20));
    await second.moveTo(center + const Offset(35, 50));
    await tester.pump();
    final transformed = editor.doc.layers.single;
    expect(transformed.scale, greaterThan(original.scale));
    expect(transformed.rotation.abs(), greaterThan(.1));
    expect(transformed.y, greaterThan(original.y));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    editor.undo();
    expect(editor.doc.layers.single.toJson(), original.toJson());
    await tester.pumpAndSettle();
    await drain(tester, editor.flush());
  });
  testWidgets('pinching an attached shirt keeps its size after snapping', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    editor.add(editor.item('tee_white'));
    final original = editor.doc.layers.single.copy();
    await tester.pumpWidget(OutfitApp(editor: editor));
    await tester.pumpAndSettle();
    final target = find.byWidgetPredicate(
      (w) => w is GestureLayer && w.layer.itemId == 'tee_white',
    );
    final center = tester.getCenter(target);
    final first = await tester.startGesture(
      center - const Offset(14, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(14, 0),
      pointer: 2,
    );
    await first.moveTo(center - const Offset(30, 0));
    await second.moveTo(center + const Offset(30, 0));
    await tester.pump();
    await first.moveTo(center - const Offset(42, 0));
    await second.moveTo(center + const Offset(42, 0));
    await tester.pump();
    expect(editor.doc.layers.single.scale, greaterThan(original.scale));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    final resized = editor.doc.layers.single;
    expect(resized.scale, greaterThan(original.scale));
    expect(resized.snappedTo, 'shoulderCenter');
    expect(Offset(resized.x, resized.y), editor.anchor('shoulderCenter'));
    editor.undo();
    expect(editor.doc.layers.single.toJson(), original.toJson());
    await drain(tester, editor.flush());
  });
  testWidgets('visible corner scales rotates and undoes as a single action', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    editor.add(editor.item('tee_white'));
    final original = editor.doc.layers.single.copy();
    await tester.pumpWidget(OutfitApp(editor: editor));
    await tester.pumpAndSettle();
    final handle = find.byTooltip('拖曳縮放與旋轉，點選精確調整');
    final start = tester.getCenter(handle);
    final gesture = await tester.startGesture(start);
    await gesture.moveTo(start + const Offset(35, 25));
    await tester.pump();
    expect(editor.hasPendingOperation, isTrue);
    await gesture.moveTo(start + const Offset(120, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(editor.doc.layers.single.scale, greaterThan(original.scale));
    expect(editor.doc.layers.single.rotation.abs(), greaterThan(.05));
    expect(editor.hasPendingOperation, isFalse);
    editor.undo();
    expect(editor.doc.layers.single.toJson(), original.toJson());
    await drain(tester, editor.flush());
  });
  testWidgets('selected item exposes adjust remove and undo controls', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    editor.add(editor.item('tee_white'));
    await tester.pumpWidget(OutfitApp(editor: editor));
    await tester.pumpAndSettle();
    expect(find.text('儲存'), findsOneWidget);
    await tester.tap(find.byTooltip('調整選取單品'));
    await tester.pumpAndSettle();
    expect(find.byType(LayerAdjustment), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('移除選取單品'));
    await tester.pumpAndSettle();
    expect(editor.doc.layers, isEmpty);
    await tester.tap(find.byTooltip('復原'));
    await tester.pumpAndSettle();
    expect(editor.doc.layers.single.itemId, 'tee_white');
    await drain(tester, editor.flush());
  });
  testWidgets(
    'one tap adds clothing without waiting for a double tap timeout',
    (tester) async {
      addTearDown(() => cleanup(tester));
      await tester.pumpWidget(OutfitApp(editor: editor));
      await tester.pumpAndSettle();
      await tester.tap(find.text('奶油白短版上衣'));
      await tester.pump();
      expect(editor.doc.layers.single.itemId, 'tee_white');
      await drain(tester, editor.flush());
    },
  );
  testWidgets('toolbar long press drop creates a free layer on the canvas', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    await tester.pumpWidget(OutfitApp(editor: editor));
    await tester.pumpAndSettle();
    final tile = find.byType(LongPressDraggable<Item>).first;
    final start = tester.getCenter(tile),
        end = tester.getCenter(find.byType(CanvasView));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 650));
    await gesture.moveTo(end);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(editor.doc.layers.length, 1);
    expect(editor.doc.layers.single.snappedTo, isNull);
    expect(editor.doc.layers.single.x, inInclusiveRange(.02, .98));
    await drain(tester, editor.flush());
  });
  testWidgets('transparent sprite openings pass pointer hits to lower layers', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    final alpha = Uint8List.fromList(List.filled(16, 255));
    for (final index in [5, 6, 9, 10]) {
      alpha[index] = 0;
    }
    var selected = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => selected = 'shirt',
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.deferToChild,
                    onTap: () => selected = 'hair',
                    child: SpriteHitRegion(
                      key: const ValueKey('mask'),
                      mask: SpriteMask(4, 4, alpha),
                      region: const Rect.fromLTWH(0, 0, 1, 1),
                      child: const ColoredBox(color: Colors.brown),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final target = find.byKey(const ValueKey('mask'));
    await tester.tapAt(tester.getCenter(target));
    expect(selected, 'shirt');
    await tester.tapAt(tester.getTopLeft(target) + const Offset(5, 5));
    expect(selected, 'hair');
  });
  testWidgets(
    'changing stored image releases the old handle and renders the new one',
    (tester) async {
      addTearDown(() => cleanup(tester));
      Uint8List png(int r, int b) => Uint8List.fromList(
        img.encodePng(
          img.fill(
            img.Image(width: 8, height: 8, numChannels: 4),
            color: img.ColorRgba8(r, 0, b, 255),
          ),
        ),
      );
      await tester.runAsync(() async {
        await editor.repo.putAsset('red', png(200, 0));
        await editor.repo.putAsset('blue', png(0, 200));
      });
      Widget view(String id) => MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 100,
            child: AssetImageView(
              key: const ValueKey('stored-image'),
              editor: editor,
              id: id,
              alphaHitTest: true,
            ),
          ),
        ),
      );
      await tester.pumpWidget(view('red'));
      await drain(
        tester,
        waitForCanvasAssets(tester.element(find.byType(AssetImageView))),
      );
      await tester.pump();
      await tester.pumpWidget(view('blue'));
      expect(tester.takeException(), isNull);
      await drain(
        tester,
        waitForCanvasAssets(tester.element(find.byType(AssetImageView))),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final image = tester.widget<RawImage>(find.byType(RawImage)).image!;
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        expect(pixels[0], 0);
        expect(pixels[2], 200);
      });
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: captureKey,
              child: SizedBox(
                width: 200,
                height: 100,
                child: ItemArt(
                  editor: editor,
                  item: Item(
                    id: 'custom-blue',
                    name: 'blue',
                    kind: Kind.top,
                    assetId: 'blue',
                    shape: 'image',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await drain(
        tester,
        waitForCanvasAssets(tester.element(find.byType(AssetImageView))),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final boundary =
            captureKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        expect(
          pixels[2],
          200,
          reason: 'Width adjustment must fill the imported layer',
        );
        expect(pixels[3], 255);
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('bounded codec keeps tall images within output budget', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 40, 200),
        Paint()..color = Colors.blue,
      );
      final picture = recorder.endRecording();
      final source = await picture.toImage(40, 200);
      picture.dispose();
      final bytes = (await source.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      source.dispose();
      final decoded = await decodeBounded(bytes, longestEdge: 50);
      expect(decoded.width, 10);
      expect(decoded.height, 50);
      final pixels = (await decoded.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      expect(pixels[3], 255);
      decoded.dispose();
    });
  });
  testWidgets(
    'eraser creates transparency and restore restores original pixels',
    (tester) async {
      addTearDown(() => cleanup(tester));
      await tester.runAsync(() async {
        final rec = ui.PictureRecorder(), canvas = Canvas(rec);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 40, 40),
          Paint()..color = Colors.red,
        );
        final picture = rec.endRecording();
        final original = await picture.toImage(40, 40);
        picture.dispose();
        final strokes = [
          BrushStroke([const Offset(.5, .5)], .6, false),
        ];
        Future<ui.Image> render() async {
          final rec = ui.PictureRecorder(), canvas = Canvas(rec);
          MaskPainter(original, strokes).paint(canvas, const Size(40, 40));
          final p = rec.endRecording();
          final im = await p.toImage(40, 40);
          p.dispose();
          return im;
        }

        var output = await render();
        var data = (await output.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        expect(data[(20 * 40 + 20) * 4 + 3], 0);
        expect(data[3], 255);
        output.dispose();
        strokes.add(BrushStroke([const Offset(.5, .5)], .4, true));
        output = await render();
        data = (await output.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        expect(data[(20 * 40 + 20) * 4 + 3], 255);
        output.dispose();
        original.dispose();
      });
    },
  );
}
