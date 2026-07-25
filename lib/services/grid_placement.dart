import '../models/grid_item.dart';

/// Grid coordinate math for the home screen: assigning first-fit positions
/// to newly-created (or pre-migration) items, and moving an item by one
/// cell at a time with swap-on-collision semantics.
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

  /// Moves [item] by one cell in the given direction. If the destination is
  /// occupied by exactly one other item, they swap — but only if the
  /// blocking item's span fits within [item]'s old footprint (anchored at
  /// the same top-left corner). That's the exact safety condition: [item]'s
  /// old spot is guaranteed free of anything else, so anything no bigger
  /// than it fits there without touching a third tile. A same-size swap
  /// always qualifies; a *smaller* tile swapping into a *larger* tile's
  /// spot also works (it just doesn't fill all of it). The other direction
  /// — a small tile trying to displace a larger one — doesn't fit and is
  /// blocked, since the larger tile would spill outside the small tile's
  /// one-cell footprint and overlap whatever's next to it. Also blocked:
  /// more than one tile in the way, or the destination running off the
  /// grid horizontally. There's no vertical limit — moving down always
  /// succeeds.
  ///
  /// Returns the set of items that were mutated (empty if blocked).
  List<GridItem> moveByDelta(List<GridItem> items, GridItem item, int dRow, int dCol) {
    final newRow = item.row + dRow;
    final newCol = item.col + dCol;
    if (newRow < 0 || newCol < 0 || newCol + item.colSpan > crossAxisCount) return const [];

    final destination = cellsFor(newRow, newCol, item.colSpan, item.rowSpan);
    final blocking = <GridItem>{};
    for (final other in items) {
      if (other.id == item.id) continue;
      final otherCells = cellsFor(other.row, other.col, other.colSpan, other.rowSpan);
      if (destination.any(otherCells.contains)) blocking.add(other);
    }

    if (blocking.isEmpty) {
      item.row = newRow;
      item.col = newCol;
      return [item];
    }

    if (blocking.length == 1) {
      final swapWith = blocking.first;
      final fitsInVacatedSpot = swapWith.colSpan <= item.colSpan && swapWith.rowSpan <= item.rowSpan;
      if (!fitsInVacatedSpot) return const [];

      final oldRow = item.row;
      final oldCol = item.col;
      item.row = newRow;
      item.col = newCol;
      swapWith.row = oldRow;
      swapWith.col = oldCol;
      return [item, swapWith];
    }

    return const [];
  }
}
