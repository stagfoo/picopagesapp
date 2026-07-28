import '../models/grid_item.dart';

/// Grid coordinate math for the home screen: assigning first-fit positions
/// to newly-created (or pre-migration) items, and moving an item in a
/// direction by jumping straight to the nearest free spot that way.
///
/// Positions are absolute (row, col) — unlike a flow/packing layout, moving
/// an item away from a spot leaves it empty rather than reflowing everything
/// to close the gap. There's no maximum row; the grid grows downward as far
/// as items are placed.
class GridPlacement {
  final int crossAxisCount;

  const GridPlacement({this.crossAxisCount = 4});

  /// All (row, col) cells an item with this footprint occupies.
  Set<(int, int)> cellsFor(int row, int col, int colSpan, int rowSpan) {
    final cells = <(int, int)>{};
    for (var r = row; r < row + rowSpan; r++) {
      for (var c = col; c < col + colSpan; c++) {
        cells.add((r, c));
      }
    }
    return cells;
  }

  bool _fits(Set<(int, int)> occupied, int row, int col, int colSpan, int rowSpan) {
    if (row < 0 || col < 0) return false;
    if (col + colSpan > crossAxisCount) return false;
    return cellsFor(row, col, colSpan, rowSpan).every((cell) => !occupied.contains(cell));
  }

  /// Whether [item] could be resized to [newColSpan] x [newRowSpan] at its
  /// current position without overlapping another tile or running off the
  /// grid horizontally. Doesn't mutate anything — shrinking always passes,
  /// since a smaller footprint is a subset of the current (already valid)
  /// one; growing can fail if it would run into a neighboring tile.
  bool canResize(List<GridItem> items, GridItem item, int newColSpan, int newRowSpan) {
    if (item.col + newColSpan > crossAxisCount) return false;
    final newFootprint = cellsFor(item.row, item.col, newColSpan, newRowSpan);
    for (final other in items) {
      if (other.id == item.id) continue;
      final otherCells = cellsFor(other.row, other.col, other.colSpan, other.rowSpan);
      if (newFootprint.any(otherCells.contains)) return false;
    }
    return true;
  }

  /// Assigns a real (row, col) to any item whose position is the "unplaced"
  /// sentinel (row < 0), first-fit scanning in [order] order, without
  /// disturbing items that already have a real position. Mutates items in
  /// place and returns the ones that were actually (re)placed.
  List<GridItem> assignMissingPositions(List<GridItem> items) {
    final occupied = <(int, int)>{};
    for (final item in items) {
      if (item.row >= 0 && item.col >= 0) {
        occupied.addAll(cellsFor(item.row, item.col, item.colSpan, item.rowSpan));
      }
    }

    final unplaced = items.where((i) => i.row < 0 || i.col < 0).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final placed = <GridItem>[];
    for (final item in unplaced) {
      var row = 0;
      var col = 0;
      while (!_fits(occupied, row, col, item.colSpan, item.rowSpan)) {
        col++;
        if (col >= crossAxisCount) {
          col = 0;
          row++;
        }
      }
      item.row = row;
      item.col = col;
      occupied.addAll(cellsFor(row, col, item.colSpan, item.rowSpan));
      placed.add(item);
    }
    return placed;
  }

  /// Moves [item] in the given direction (dRow/dCol is a unit step — one of
  /// up/down/left/right), scanning cell by cell past anything in the way
  /// until it finds the nearest free spot [item]'s own footprint actually
  /// fits in, and jumps straight there. This deliberately isn't a swap or a
  /// single-cell nudge: a tile boxed in on one side shouldn't require
  /// relocating everything around it first just to move past it. Blocked
  /// (returns empty, nothing mutated) only if the scan runs off the grid —
  /// horizontally bounded by crossAxisCount, upward bounded by row 0 — before
  /// finding a free spot. Moving down has no bound: the grid grows as far as
  /// items are placed, so a free spot always exists eventually.
  ///
  /// Returns the set of items that were mutated (just [item] — empty if
  /// blocked).
  List<GridItem> moveByDelta(List<GridItem> items, GridItem item, int dRow, int dCol) {
    final occupied = <(int, int)>{};
    for (final other in items) {
      if (other.id == item.id) continue;
      occupied.addAll(cellsFor(other.row, other.col, other.colSpan, other.rowSpan));
    }

    var row = item.row;
    var col = item.col;
    while (true) {
      row += dRow;
      col += dCol;
      if (row < 0 || col < 0 || col + item.colSpan > crossAxisCount) return const [];
      if (_fits(occupied, row, col, item.colSpan, item.rowSpan)) {
        item.row = row;
        item.col = col;
        return [item];
      }
    }
  }
}
