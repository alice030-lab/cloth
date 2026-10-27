"""Idempotently connect local ML adapters to generated Flutter platform runners."""
from pathlib import Path
import shutil
root = Path(__file__).resolve().parent.parent
android = root / 'android/app/build.gradle.kts'
if android.exists():
    text = android.read_text()
    text = text.replace('minSdk = flutter.minSdkVersion', 'minSdk = 24')
    marker = 'com.google.android.gms:play-services-mlkit-subject-segmentation:16.0.0-beta1'
    if marker not in text:
        text += '\ndependencies {\n    implementation("' + marker + '")\n}\n'
    android.write_text(text)
    target = root / 'android/app/src/main/kotlin/com/outfitcanvas/outfit_canvas/MainActivity.kt'
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(root / 'native/android/MainActivity.kt', target)
    manifest = root / 'android/app/src/main/AndroidManifest.xml'
    text = manifest.read_text()
    if 'android.permission.INTERNET' not in text:
        text = text.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
    text = text.replace('android:label="outfit_canvas"', 'android:label="穿搭預演"')
    manifest.write_text(text)
ios = root / 'ios/Runner/AppDelegate.swift'
if ios.exists():
    # Inline plugin class so default Runner target includes it without PBX edits.
    text = ios.read_text()
    if 'final class SegmentationPlugin' not in text:
        text += '\n' + (root / 'native/ios/SegmentationPlugin.swift').read_text()
    if 'SegmentationPlugin.register(with:' not in text:
        # Flutter current implicit-engine lifecycle or legacy launch lifecycle.
        if 'didInitializeImplicitFlutterEngine' in text:
            key = 'GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)'
            text = text.replace(key, key + '\n    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OutfitSegmentation") {\n      SegmentationPlugin.register(with: registrar.messenger())\n    }')
        else:
            key = 'GeneratedPluginRegistrant.register(with: self)'
            text = text.replace(key, key + '\n    if let controller = window?.rootViewController as? FlutterViewController {\n      SegmentationPlugin.register(with: controller.binaryMessenger)\n    }')
    ios.write_text(text)
    info = root / 'ios/Runner/Info.plist'
    text = info.read_text()
    for key, value in [('NSPhotoLibraryUsageDescription', '選擇你想試搭的衣服或場景，圖片只留在裝置。'), ('NSPhotoLibraryAddUsageDescription', '將完成的穿搭圖片儲存到相簿。')]:
        if key not in text:
            text = text.replace('</dict>\n</plist>', f'<key>{key}</key><string>{value}</string>\n</dict>\n</plist>')
    text = text.replace('<string>outfit_canvas</string>', '<string>穿搭預演</string>')
    info.write_text(text)
print('Native adapters configured. Build and device validation are still required.')
