import 'dart:js_interop';

@JS('globalThis.__outfitPrepareReload')
external set _prepareReload(JSFunction callback);

/// Called only after a user chooses to install an available Web update.
void installReloadGuard(Future<bool> Function() prepare) {
  _prepareReload = (() => prepare().then((ok) => ok.toJS).toJS).toJS;
}
