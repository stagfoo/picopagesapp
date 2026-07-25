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
            child: AppTileContent(entry: entry),
          ),
        ),
      ),
    ));

    expect(find.text('My Test App'), findsOneWidget);

    await tester.tap(find.byType(OrganizeTile));
    expect(tapped, isTrue);
  });

  testWidgets('selected OrganizeTile reports swipe direction as a move delta',
      (WidgetTester tester) async {
    final entry = AppEntry(
      id: 'test-id',
      title: 'My Test App',
      folderName: 'test-id',
      importedAt: DateTime(2026),
      order: 0,
      colSpan: 2,
    );
    int? dRow;
    int? dCol;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 200,
          child: OrganizeTile(
            id: entry.id,
            organizing: true,
            selected: true,
            onTap: () {},
            onLongPress: () {},
            onSwipeMove: (r, c) {
              dRow = r;
              dCol = c;
            },
            child: AppTileContent(entry: entry),
          ),
        ),
      ),
    ));

    await tester.fling(find.byType(OrganizeTile), const Offset(120, 0), 800);
    await tester.pumpAndSettle();
    expect(dRow, 0);
    expect(dCol, 1);

    await tester.fling(find.byType(OrganizeTile), const Offset(0, -120), 800);
    await tester.pumpAndSettle();
    expect(dRow, -1);
    expect(dCol, 0);
  });

  testWidgets('unselected OrganizeTile does not report swipes', (WidgetTester tester) async {
    final entry = AppEntry(
      id: 'test-id',
      title: 'My Test App',
      folderName: 'test-id',
      importedAt: DateTime(2026),
      order: 0,
    );
    var swiped = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 100,
          height: 100,
          child: OrganizeTile(
            id: entry.id,
            organizing: true,
            selected: false,
            onTap: () {},
            onLongPress: () {},
            onSwipeMove: (_, _) => swiped = true,
            child: AppTileContent(entry: entry),
          ),
        ),
      ),
    ));

    // Not pumpAndSettle: an unselected+organizing tile wiggles forever, so
    // that would never return.
    await tester.fling(find.byType(OrganizeTile), const Offset(80, 0), 800);
    await tester.pump(const Duration(milliseconds: 500));
    expect(swiped, isFalse);
  });
}
