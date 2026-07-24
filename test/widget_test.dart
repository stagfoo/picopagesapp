import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:picopages/models/app_entry.dart';
import 'package:picopages/widgets/app_tile.dart';
import 'package:picopages/widgets/organize_tile.dart';

void main() {
  testWidgets('OrganizeTile shows a big tile\'s title and responds to tap', (WidgetTester tester) async {
    final entry = AppEntry(
      id: 'test-id',
      title: 'My Test App',
      folderName: 'test-id',
      importedAt: DateTime(2026),
      order: 0,
      colSpan: 2,
    );
    var tapped = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 200,
          child: OrganizeTile(
            id: entry.id,
            organizing: false,
            selected: false,
            onTap: () => tapped = true,
            onLongPress: () {},
            onDroppedOnto: (_) {},
            child: AppTileContent(entry: entry),
          ),
        ),
      ),
    ));

    expect(find.text('My Test App'), findsOneWidget);

    await tester.tap(find.byType(OrganizeTile));
    expect(tapped, isTrue);
  });
}
