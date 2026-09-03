/// The size of the box an imported app actually gets to draw in, in the
/// units its CSS will be written in.
///
/// PicoPages apps only ever run on this one phone, in this one WebView, so
/// the AI writing them doesn't have to guess at a range of screens — it can
/// be told the exact numbers and design to them. That only works if the
/// numbers are the real viewport, which is why [ScreenProfile] is measured
/// from the live layout rather than assumed.
///
/// Pure Dart with no Flutter import, so the prompt text it produces is
/// testable without pumping a widget.
library;

class ScreenProfile {
  const ScreenProfile({
    required this.widthCssPx,
    required this.heightCssPx,
    required this.devicePixelRatio,
  });

  /// Width of the WebView in CSS pixels.
  ///
  /// Flutter's logical pixel and the WebView's CSS pixel are both 1/160 inch
  /// on Android, so a measured Flutter width is the CSS width directly — as
  /// long as the page declares `width=device-width`, which is why the prompt
  /// insists on the viewport meta tag.
  final int widthCssPx;

  final int heightCssPx;

  final double devicePixelRatio;

  int get physicalWidth => (widthCssPx * devicePixelRatio).round();

  int get physicalHeight => (heightCssPx * devicePixelRatio).round();

  bool get isPortrait => heightCssPx >= widthCssPx;

  /// The block that goes into the AI prompt.
  String get promptSection => '''Screen — this app runs in one WebView on one known phone, so design for these exact numbers rather than for a range of unknown screens:
- Viewport: $widthCssPx × $heightCssPx CSS pixels (${isPortrait ? 'portrait' : 'landscape'}), at a device pixel ratio of ${_ratio()} — $physicalWidth × $physicalHeight physical pixels.
- Put <meta name="viewport" content="width=device-width, initial-scale=1"> in the <head>. Without it Android's WebView lays the page out at 980px wide and scales it down, and every size below stops meaning anything.
- No media queries or responsive breakpoints are needed. One fixed layout tuned to $widthCssPx × $heightCssPx is the right answer here.
- Use 100dvh (not 100vh) for a full-height layout, so it stays correct when the on-screen keyboard opens.
- This is a touch screen: no hover-only interactions, and keep tap targets at least 44 CSS pixels.
- If you draw to a <canvas>, set its width/height attributes to the CSS size × ${_ratio()} and scale the context by the same, or it will render soft.''';

  /// Trims a trailing `.0` so a ratio of 3 doesn't read as "3.0".
  String _ratio() {
    final rounded = double.parse(devicePixelRatio.toStringAsFixed(2));
    return rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is ScreenProfile &&
      other.widthCssPx == widthCssPx &&
      other.heightCssPx == heightCssPx &&
      other.devicePixelRatio == devicePixelRatio;

  @override
  int get hashCode => Object.hash(widthCssPx, heightCssPx, devicePixelRatio);

  @override
  String toString() =>
      'ScreenProfile($widthCssPx×$heightCssPx @${devicePixelRatio}x)';
}
