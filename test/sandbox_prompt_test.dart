import 'package:flutter_test/flutter_test.dart';
import 'package:picopages/services/sandbox_prompt.dart';

void main() {
  test('with nothing enabled, only localStorage is documented', () {
    final text = buildSandboxPromptText({});

    expect(text, contains('1. localStorage'));
    expect(text, isNot(contains('/uploads')));
    expect(text, isNot(contains('/sets')));
    expect(text, isNot(contains('/share')));
    expect(text, isNot(contains('/speak')));
    expect(text, contains('only localStorage actually persist'));
  });

  test('enabling uploads adds its sections and the persistence rule', () {
    final text = buildSandboxPromptText({'uploads'});

    expect(text, contains('1. localStorage'));
    expect(text, contains('2. Upload/save a file'));
    expect(text, contains('3. List previously uploaded files'));
    expect(text, contains('4. Delete an uploaded file'));
    expect(text, contains('only localStorage and /uploads actually persist'));
    expect(text, isNot(contains('/sets')));
  });

  test('capabilities are numbered in a stable order regardless of enable order', () {
    final textAB = buildSandboxPromptText({'uploads', 'share'});
    final textBA = buildSandboxPromptText({'share', 'uploads'});

    expect(textAB, textBA);
    // uploads comes before share in allSandboxCapabilities.
    expect(textAB.indexOf('Upload/save a file'), lessThan(textAB.indexOf('Share text and/or a file')));
  });

  test('three or more persisting capabilities use an Oxford-comma-free list', () {
    final text = buildSandboxPromptText({'uploads', 'sets', 'share'});

    // share has no persistenceNote, so only localStorage/uploads/sets count.
    expect(text, contains('only localStorage, /uploads and /sets actually persist'));
  });

  test('microformats capability has no persistence note and adds no rule text', () {
    final text = buildSandboxPromptText({'microformats'});

    expect(text, contains('microformats2 class names'));
    expect(text, contains('only localStorage actually persist'));
  });

  test('every declared capability key is unique', () {
    final keys = allSandboxCapabilities.map((c) => c.key).toList();
    expect(keys.toSet().length, keys.length);
  });
}
