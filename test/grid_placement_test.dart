import 'package:flutter_test/flutter_test.dart';
import 'package:picopages/models/grid_item.dart';
import 'package:picopages/models/sticker_entry.dart';
import 'package:picopages/services/grid_placement.dart';

GridItem _item(String id, {int order = 0, int colSpan = 1, int rowSpan = 1, int row = -1, int col = -1}) {
  return StickerGridItem(StickerEntry(
    id: id,
    order: order,
    colSpan: colSpan,
    rowSpan: rowSpan,
    row: row,
    col: col,
  ));
}

void main() {
  group('assignMissingPositions', () {
    test('places unplaced items first-fit in order, left to right then down', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      final items = [
        for (var i = 0; i < 5; i++) _item('a$i', order: i),
      ];

      placement.assignMissingPositions(items);

      expect(items.map((i) => (i.row, i.col)), [
        (0, 0),
        (0, 1),
        (0, 2),
        (0, 3),
        (1, 0),
      ]);
    });

    test('does not disturb items that already have a real position', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      final anchored = _item('anchored', order: 0, row: 5, col: 2);
      final unplaced = _item('new', order: 1);

      placement.assignMissingPositions([anchored, unplaced]);

      expect((anchored.row, anchored.col), (5, 2));
      // First-fit skips row 0 col 0..1 fine (anchored is at row 5), so the
      // new item still lands at the very first open cell.
      expect((unplaced.row, unplaced.col), (0, 0));
    });

    test('skips cells already occupied by a wide anchored item', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      final wide = _item('wide', order: 0, colSpan: 4, row: 0, col: 0);
      final next = _item('next', order: 1);

      placement.assignMissingPositions([wide, next]);

      expect((next.row, next.col), (1, 0));
    });
  });

  group('moveByDelta', () {
    test('moves into an empty cell with no collision', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      final item = _item('a', row: 2, col: 2);
      final items = [item];

      final moved = placement.moveByDelta(items, item, 0, 1);

      expect(moved, [item]);
      expect((item.row, item.col), (2, 3));
    });

    test('swaps with exactly one blocking item', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      final a = _item('a', row: 0, col: 0);
      final b = _item('b', row: 0, col: 1);
      final items = [a, b];

      final moved = placement.moveByDelta(items, a, 0, 1);

      expect(moved.toSet(), {a, b});
      expect((a.row, a.col), (0, 1));
      expect((b.row, b.col), (0, 0));
    });

    test('is blocked moving left past column 0', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      final a = _item('a', row: 0, col: 0);
      final items = [a];

      final moved = placement.moveByDelta(items, a, 0, -1);

      expect(moved, isEmpty);
      expect((a.row, a.col), (0, 0));
    });

    test('is blocked moving right past the last column', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      final a = _item('a', row: 0, col: 3);
      final items = [a];

      final moved = placement.moveByDelta(items, a, 0, 1);

      expect(moved, isEmpty);
      expect((a.row, a.col), (0, 3));
    });

    test('has no vertical limit moving down', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      final a = _item('a', row: 40, col: 0);
      final items = [a];

      final moved = placement.moveByDelta(items, a, 1, 0);

      expect(moved, [a]);
      expect((a.row, a.col), (41, 0));
    });

    test('is blocked when the destination is occupied by more than one item', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      final wide = _item('wide', row: 0, col: 0, colSpan: 2);
      final blockerA = _item('blockerA', row: 0, col: 1);
      final blockerB = _item('blockerB', row: 0, col: 2);
      final items = [wide, blockerA, blockerB];

      final moved = placement.moveByDelta(items, wide, 0, 1);

      expect(moved, isEmpty);
      expect((wide.row, wide.col), (0, 0));
    });
  });
}
