{{flutter_js}}
{{flutter_build_config}}
// Keep unexpected glyph fallbacks on this origin as well. The app explicitly
// bundles its Traditional Chinese font and declares it for editorial labels.
_flutter.loader.load({config: {
  fontFallbackBaseUrl: new URL('assets/fonts/fallback/', document.baseURI).href
}});
