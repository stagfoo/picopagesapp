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
    test('moves into an empty cell directly', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      final item = _item('a', row: 2, col: 2);
      final items = [item];

      final moved = placement.moveByDelta(items, item, 0, 1);

      expect(moved, [item]);
      expect((item.row, item.col), (2, 3));
    });

    test('jumps past a single occupied cell to the next free one', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      final a = _item('a', row: 0, col: 0);
      final blocker = _item('blocker', row: 0, col: 1);
      final items = [a, blocker];

      final moved = placement.moveByDelta(items, a, 0, 1);

      // Jumps straight to (0, 2), the first free cell — blocker is left
      // exactly where it was, not swapped.
      expect(moved, [a]);
      expect((a.row, a.col), (0, 2));
      expect((blocker.row, blocker.col), (0, 1));
    });

    test('jumps past several consecutive occupied rows to the next free one', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      final a = _item('a', row: 0, col: 0);
      final blockers = [
        _item('b1', row: 1, col: 0),
        _item('b2', row: 2, col: 0),
        _item('b3', row: 3, col: 0),
      ];
      final items = [a, ...blockers];

      final moved = placement.moveByDelta(items, a, 1, 0);

      // Rows 1-3 are all occupied; row 4 is the first free one.
      expect(moved, [a]);
      expect((a.row, a.col), (4, 0));
      for (final b in blockers) {
        expect(b.row, lessThan(4));
      }
    });

    test('jumps past a differently-sized blocking tile', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      // wide occupies (0,1) and (0,2); small tries to move right into it.
      final wide = _item('wide', row: 0, col: 1, colSpan: 2);
      final small = _item('small', row: 0, col: 0);
      final items = [wide, small];

      final moved = placement.moveByDelta(items, small, 0, 1);

      // (0,1) and (0,2) are both occupied by wide; (0,3) is the first free
      // cell — small jumps there rather than being blocked by wide's size.
      expect(moved, [small]);
      expect((small.row, small.col), (0, 3));
      expect((wide.row, wide.col), (0, 1));
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

    test('is blocked moving right when no free cell exists before the edge', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      final a = _item('a', row: 0, col: 0);
      final blockerB = _item('blockerB', row: 0, col: 1);
      final blockerC = _item('blockerC', row: 0, col: 2);
      final blockerD = _item('blockerD', row: 0, col: 3);
      final items = [a, blockerB, blockerC, blockerD];

      final moved = placement.moveByDelta(items, a, 0, 1);

      expect(moved, isEmpty);
      expect((a.row, a.col), (0, 0));
    });

    test('has no vertical limit moving down', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      final a = _item('a', row: 40, col: 0);
      final items = [a];

      final moved = placement.moveByDelta(items, a, 1, 0);

      expect(moved, [a]);
      expect((a.row, a.col), (41, 0));
    });
  });

  group('canResize', () {
    test('allows growing into empty space', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      final item = _item('a', row: 0, col: 0);
      final items = [item];

      expect(placement.canResize(items, item, 2, 2), isTrue);
    });

    test('blocks growing into a neighboring tile', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      final item = _item('a', row: 0, col: 0);
      final neighbor = _item('b', row: 0, col: 1);
      final items = [item, neighbor];

      // Growing to colSpan 2 would reach into neighbor's cell (0, 1).
      expect(placement.canResize(items, item, 2, 1), isFalse);
    });

    test('blocks growing past the right edge of the grid', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      final item = _item('a', row: 0, col: 3);
      final items = [item];

      expect(placement.canResize(items, item, 2, 1), isFalse);
    });

    test('always allows shrinking', () {
      final placement = const GridPlacement(crossAxisCount: 4);
      final item = _item('a', row: 0, col: 0, colSpan: 4, rowSpan: 4);
      final items = [item];

      expect(placement.canResize(items, item, 1, 1), isTrue);
    });
  });
}
