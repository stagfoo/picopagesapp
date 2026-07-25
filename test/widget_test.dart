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
            feedbackWidth: 200,
            feedbackHeight: 200,
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

  testWidgets('selected OrganizeTile reports swipe direction as a resize delta',
      (WidgetTester tester) async {
    final entry = AppEntry(
      id: 'test-id',
      title: 'My Test App',
      folderName: 'test-id',
      importedAt: DateTime(2026),
      order: 0,
      colSpan: 2,
    );
    int? colDelta;
    int? rowDelta;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 200,
          child: OrganizeTile(
            id: entry.id,
            organizing: true,
            selected: true,
            feedbackWidth: 200,
            feedbackHeight: 200,
            onTap: () {},
            onLongPress: () {},
            onDroppedOnto: (_) {},
            onColSpanSwipe: (delta) => colDelta = delta,
            onRowSpanSwipe: (delta) => rowDelta = delta,
            child: AppTileContent(entry: entry),
          ),
        ),
      ),
    ));

    await tester.fling(find.byType(OrganizeTile), const Offset(120, 0), 800);
    await tester.pumpAndSettle();
    expect(colDelta, 1);
    expect(rowDelta, isNull);

    await tester.fling(find.byType(OrganizeTile), const Offset(0, -120), 800);
    await tester.pumpAndSettle();
    expect(rowDelta, -1);
  });
}
