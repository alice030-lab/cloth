"""Helper-script tests only; these do not compile or execute the Flutter app."""
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

class ToolingTests(unittest.TestCase):
    def fixture(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        (root / 'tool').mkdir()
        for name in ['configure_native.py', 'generate_offline_worker.py']:
            shutil.copy(ROOT / 'tool' / name, root / 'tool' / name)
        shutil.copytree(ROOT / 'native', root / 'native')
        return root

    def configure(self, root):
        subprocess.run(['python3', str(root / 'tool/configure_native.py')], check=True, capture_output=True)

    def test_current_native_configuration_is_idempotent(self):
        root = self.fixture()
        runner = root / 'ios/Runner'
        runner.mkdir(parents=True)
        app = 'import Flutter\nclass AppDelegate {\nfunc didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {\nGeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)\n}\n}\n'
        (runner / 'AppDelegate.swift').write_text(app)
        (runner / 'Info.plist').write_text('<?xml version="1.0"?><plist version="1.0"><dict>\n<key>CFBundleName</key><string>outfit_canvas</string>\n</dict>\n</plist>')
        android = root / 'android/app'
        (android / 'src/main').mkdir(parents=True)
        (android / 'build.gradle.kts').write_text('android { defaultConfig { minSdk = flutter.minSdkVersion } }')
        (android / 'src/main/AndroidManifest.xml').write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="outfit_canvas" /></manifest>')
        self.configure(root)
        once = {p.relative_to(root): p.read_bytes() for p in root.rglob('*') if p.is_file() and ('ios' in p.parts or 'android' in p.parts)}
        self.configure(root)
        for path, content in once.items():
            self.assertEqual((root / path).read_bytes(), content)
        self.assertEqual((runner / 'AppDelegate.swift').read_text().count('SegmentationPlugin.register(with:'), 1)
        self.assertIn('minSdk = 24', (android / 'build.gradle.kts').read_text())
        self.assertIn('android.permission.INTERNET', (android / 'src/main/AndroidManifest.xml').read_text())
        self.assertIn('NSPhotoLibraryUsageDescription', (runner / 'Info.plist').read_text())

    def test_legacy_ios_registration(self):
        root = self.fixture()
        runner = root / 'ios/Runner'
        runner.mkdir(parents=True)
        (runner / 'AppDelegate.swift').write_text('import Flutter\nclass AppDelegate {\nfunc launch() { GeneratedPluginRegistrant.register(with: self) }\n}\n')
        (runner / 'Info.plist').write_text('<plist><dict>\n</dict>\n</plist>')
        self.configure(root)
        self.assertIn('controller.binaryMessenger', (runner / 'AppDelegate.swift').read_text())

    def test_offline_worker_tracks_content_versions(self):
        root = self.fixture()
        built = root / 'build/web'
        built.mkdir(parents=True)
        (built / 'main.dart.js').write_text('// TEST FIXTURE, NOT A COMPILED APP')
        (built / 'index.html').write_text('<html>test fixture</html>')
        command = ['python3', str(root / 'tool/generate_offline_worker.py')]
        subprocess.run(command, check=True, capture_output=True)
        once = (built / 'offline_worker.js').read_text()
        subprocess.run(command, check=True, capture_output=True)
        self.assertEqual(once, (built / 'offline_worker.js').read_text())
        (built / 'main.dart.js').write_text('// updated test fixture')
        subprocess.run(command, check=True, capture_output=True)
        self.assertNotEqual(once, (built / 'offline_worker.js').read_text())
        subprocess.run(['node', '--check', str(built / 'offline_worker.js')], check=True, capture_output=True)

if __name__ == '__main__':
    unittest.main()
