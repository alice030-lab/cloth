import 'package:flutter/material.dart';
import 'data/database.dart';
import 'data/repository.dart';
import 'core/controller.dart';
import 'features/editor_page.dart';
import 'painting/art.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final repo = Repository(await openDatabase());
    final editor = EditorController(repo);
    await editor.initialize();
    runApp(OutfitApp(editor: editor));
  } catch (_) {
    runApp(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storage_outlined, size: 48, color: wine),
                    const SizedBox(height: 20),
                    const Text('本機儲存空間無法開啟', style: TextStyle(fontSize: 22)),
                    const SizedBox(height: 12),
                    const Text('請確認瀏覽器允許網站儲存，或裝置有可用空間，再重新開啟。你的資料沒有被清除。'),
                    const SizedBox(height: 20),
                    FilledButton(onPressed: main, child: const Text('重試')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'NotoSansTC',
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: wine,
    primary: wine,
    surface: paper,
    onSurface: ink,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: paper,
    foregroundColor: ink,
    centerTitle: false,
    elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    isDense: true,
    filled: true,
    fillColor: const Color(0xfffffcf8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xffd8c8bf)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(44, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(44, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
  ),
);

class OutfitApp extends StatelessWidget {
  final EditorController editor;
  const OutfitApp({super.key, required this.editor});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '穿搭預演',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: EditorPage(editor: editor),
  );
}
