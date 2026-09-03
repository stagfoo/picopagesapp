import 'package:flutter_test/flutter_test.dart';
import 'package:picopages/services/sandbox_prompt.dart';
import 'package:picopages/services/screen_profile.dart';

void main() {
  const pixel = ScreenProfile(
    widthCssPx: 393,
    heightCssPx: 728,
    devicePixelRatio: 2.75,
  );

  group('ScreenProfile', () {
    test('states the measured viewport in CSS pixels', () {
      expect(pixel.promptSection, contains('393 × 728 CSS pixels'));
    });

    test('derives the physical resolution from the pixel ratio', () {
      expect(pixel.physicalWidth, 1081);
      expect(pixel.physicalHeight, 2002);
      expect(pixel.promptSection, contains('1081 × 2002 physical pixels'));
    });

    test('reads a whole-number ratio as an integer, not 3.0', () {
      const whole = ScreenProfile(
        widthCssPx: 360,
        heightCssPx: 640,
        devicePixelRatio: 3,
      );
      expect(whole.promptSection, contains('device pixel ratio of 3 —'));
      expect(whole.promptSection, isNot(contains('3.0')));
    });

    test('names the orientation it measured', () {
      expect(pixel.promptSection, contains('(portrait)'));
      expect(
        const ScreenProfile(
          widthCssPx: 728,
          heightCssPx: 393,
          devicePixelRatio: 2.75,
        ).promptSection,
        contains('(landscape)'),
      );
    });

    test('a square viewport counts as portrait rather than neither', () {
      const square = ScreenProfile(
        widthCssPx: 400,
        heightCssPx: 400,
        devicePixelRatio: 2,
      );
      expect(square.isPortrait, isTrue);
    });

    test('demands the viewport meta tag, without which the numbers are wrong', () {
      expect(pixel.promptSection, contains('width=device-width, initial-scale=1'));
      expect(pixel.promptSection, contains('980px'));
    });

    test('tells the AI not to bother with responsive breakpoints', () {
      expect(pixel.promptSection, contains('No media queries'));
    });

    test('covers the phone-specific traps: dvh, touch targets, canvas scale', () {
      expect(pixel.promptSection, contains('100dvh'));
      expect(pixel.promptSection, contains('44 CSS pixels'));
      expect(pixel.promptSection, contains('<canvas>'));
    });

    test('compares by value so a rebuild at the same size is not a change', () {
      expect(
        pixel,
        const ScreenProfile(
          widthCssPx: 393,
          heightCssPx: 728,
          devicePixelRatio: 2.75,
        ),
      );
      expect(
        pixel,
        isNot(const ScreenProfile(
          widthCssPx: 393,
          heightCssPx: 729,
          devicePixelRatio: 2.75,
        )),
      );
    });
  });

  group('buildSandboxPromptText with a screen', () {
    test('includes the screen block between the sections and the rules', () {
      final text = buildSandboxPromptText({'uploads'}, screen: pixel);
      expect(text, contains('393 × 728 CSS pixels'));
      expect(
        text.indexOf('Delete an uploaded file'),
        lessThan(text.indexOf('Screen — this app runs')),
      );
      expect(
        text.indexOf('Screen — this app runs'),
        lessThan(text.indexOf('Rules:')),
      );
    });

    test('omits the block entirely when there is nothing to measure', () {
      final text = buildSandboxPromptText({'uploads'});
      expect(text, isNot(contains('CSS pixels')));
      expect(text, isNot(contains('Screen —')));
    });

    test('does not disturb the capability numbering', () {
      final text = buildSandboxPromptText({'uploads'}, screen: pixel);
      expect(text, contains('1. localStorage'));
      expect(text, contains('2. Upload/save a file'));
      expect(text, contains('4. Delete an uploaded file'));
    });

    test('still closes with the persistence rule', () {
      final text = buildSandboxPromptText({'uploads'}, screen: pixel);
      expect(text, contains('only localStorage and /uploads actually persist'));
    });
  });
}
