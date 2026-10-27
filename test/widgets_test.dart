import 'dart:ui' as ui;
import 'package:flutter/material.dart';
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

void main() {
  // Sembast yields with real-time timers; disable only that scheduler for
  // WidgetTester fake time. Persistence operations and assertions remain real.
  setUpAll(disableSembastCooperator);
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
