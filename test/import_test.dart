import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:outfit_canvas/features/import_editor.dart';

Uint8List fixture() {
  final image = img.Image(width: 100, height: 100, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(50, 100, 200, 255));
  return Uint8List.fromList(img.encodePng(image));
}

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 150 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(ready(), isTrue, reason: 'Real image decoding and export must finish');
}

void main() {
  for (final restore in [false, true]) {
    testWidgets(
      'single tap ${restore ? 'restore' : 'erase'} exports correct alpha',
      (tester) async {
        ImportedImage? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await Navigator.push<ImportedImage>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ImportEditor(
                          bytes: fixture(),
                          filename: 'blue.png',
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pump();
        await waitFor(
          tester,
          () => find.byKey(const ValueKey('mask-canvas')).evaluate().isNotEmpty,
        );
        await tester.pump(const Duration(milliseconds: 400));
        final canvas = find.byKey(const ValueKey('mask-canvas'));
        await tester.tapAt(tester.getCenter(canvas));
        await tester.pump();
        if (restore) {
          await tester.tap(find.text('還原'));
          await tester.pump();
          await tester.tapAt(tester.getCenter(canvas));
          await tester.pump();
        }
        await tester.tap(find.text('加入衣櫥'));
        await waitFor(tester, () => result != null);
        final output = img.decodePng(result!.bytes)!;
        expect(output.getPixel(50, 50).a, restore ? 255 : 0);
        expect(output.getPixel(1, 1).a, 255);
        if (restore) expect(output.getPixel(50, 50).b, 200);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('invalid image shows an actionable error and cannot submit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ImportEditor(
          bytes: Uint8List.fromList([1, 2, 3]),
          filename: 'broken.png',
        ),
      ),
    );
    await waitFor(
      tester,
      () => find.text('無法解碼這張圖片，請改用 JPEG 或 PNG。').evaluate().isNotEmpty,
    );
    await tester.tap(find.text('加入衣櫥'));
    await tester.pump();
    expect(find.byType(ImportEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('cancel ignores late native segmentation and retains original', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final delayed = Completer<Uint8List>();
    const channel = MethodChannel('outfit_canvas/segmentation');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) => delayed.future,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ImportEditor(bytes: fixture(), filename: 'blue.png'),
      ),
    );
    await waitFor(
      tester,
      () => find.byKey(const ValueKey('mask-canvas')).evaluate().isNotEmpty,
    );
    await tester.ensureVisible(find.text('嘗試裝置端自動去背'));
    await tester.tap(find.text('嘗試裝置端自動去背'));
    await waitFor(tester, () => find.text('取消處理').evaluate().isNotEmpty);
    await tester.tap(find.text('取消處理'));
    await tester.pump();
    expect(find.text('已取消處理，原圖與編輯仍保留。'), findsOneWidget);
    // A cancelled native response must not clear edits or lock the editor again.
    delayed.complete(fixture());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('取消處理'), findsNothing);
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<MaskPainter>()
        .single;
    expect(painter.baseline, isNull);
    expect(painter.image.width, 100);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 26));
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
