const std = @import("std");
const print = std.debug.print;

const Cell = enum(u8) {
    start,
    end,
    wall,
};

fn print_grid(comptime size: u32, grid: []const [size]?Cell) void {
    for (grid.len * 2 + 1) |_| print("_", .{});
    for (grid) |row| {
        print("\n", .{});
        for (row) |cell| {
            var char: u8 = ' ';
            if (cell) |c| {
                if (c == .start) char = 'a' else if (c == .end) char = 'b' else char = 'x';
            }
            print("|{c}", .{char});
        }
        print("|", .{});
    }
    print("\n", .{});
    for (grid.len * 2 + 1) |_| print("-", .{});
    print("\n", .{});
}
fn build_grid_possible() [7][7]?Cell {
    // _____________
    //| | | | | | | |
    //| | |b|*|*|*| |
    //| |x|x|x|x|x|*|
    //| |x| | | |*| |
    //| | | | |a| | |
    //| | | | | | | |
    //| | | | | | | |
    // _____________
    //
    // each square is 1 unit in width and height
    // squares are sqrt(2) units away from each other, diagonally
    // correct shortest path is marked by * but will not be shown in the returned data structure
    var grid = [_][7]?Cell{[_]?Cell{null} ** 7} ** 7;
    inline for (.{ 1, 2, 3, 4, 5 }) |x| {
        grid[2][x] = .wall;
    }
    grid[3][1] = .wall;
    grid[4][4] = .start;
    grid[1][2] = .end;
    return grid;
}
fn build_grid_impossible() [7][7]?Cell {
    // _____________
    //| | | | | | | |
    //| | |b| | | | |
    //|x|x|x|x|x|x|x|
    //| |x| | | | | |
    //| | | | |a| | |
    //| | | | | | | |
    //| | | | | | | |
    // _____________
    var grid = [_][7]?Cell{[_]?Cell{null} ** 7} ** 7;
    inline for (.{ 0, 1, 2, 3, 4, 5, 6 }) |x| {
        grid[2][x] = .wall;
    }
    grid[3][1] = .wall;
    grid[4][4] = .start;
    grid[1][2] = .end;
    return grid;
}
test "print_grid" {
    const grid = build_grid_possible();
    print_grid(grid.len, &grid);
}
test "a_reaches_b" {}
test "shortest_path_is_correct_units_long" {}
test "shortest_path_is_correct_path" {}
test "a_does_not_reach_b_given_impossible_path" {}
