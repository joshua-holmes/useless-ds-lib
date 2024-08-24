const std = @import("std");
const print = std.debug.print;

pub const Cell = enum(u8) {
    start,
    end,
    wall,
};

const Point = struct {
    x: u32,
    y: u32,
};

pub fn Astar(size: comptime_int) type {
    return struct {
        grid: [size][size]?Cell,
        len: comptime_int = size,
        const Self = @This();

        fn new(start: Point, end: Point, walls: []const Point) Self {
            var grid = [_][size]?Cell{[_]?Cell{null} ** size} ** size;
            grid[start.y][start.x] = .start;
            grid[end.y][end.x] = .end;
            inline for (walls) |p| {
                grid[p.y][p.x] = .wall;
            }
            return Self{ .grid = grid };
        }

        fn print_grid(self: Self) void {
            for (self.len * 2 + 1) |_| print("_", .{});
            for (self.grid) |row| {
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
            for (self.len * 2 + 1) |_| print("-", .{});
            print("\n", .{});
        }
    };
}
fn build_grid_possible() Astar(7) {
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
    var walls = [_]Point{undefined} ** 6;
    inline for (.{ 1, 2, 3, 4, 5 }, 0..) |x, i| {
        walls[i] = Point{ .x = x, .y = 2 };
    }
    walls[5] = Point{ .x = 1, .y = 3 };
    return Astar(7).new(Point{ .x = 4, .y = 4 }, Point{ .x = 2, .y = 1 }, &walls);
}
fn build_grid_impossible() Astar(7) {
    // _____________
    //| | | | | | | |
    //| | |b| | | | |
    //|x|x|x|x|x|x|x|
    //| |x| | | | | |
    //| | | | |a| | |
    //| | | | | | | |
    //| | | | | | | |
    // _____________
    var walls = [_]Point{undefined} ** 8;
    inline for (.{ 0, 1, 2, 3, 4, 5, 6 }, 0..) |x, i| {
        walls[i] = Point{ .x = x, .y = 2 };
    }
    walls[7] = Point{ .x = 1, .y = 3 };
    return Astar(7).new(Point{ .x = 4, .y = 4 }, Point{ .x = 2, .y = 1 }, &walls);
}
test "print_grid" {
    const astar = build_grid_possible();
    astar.print_grid();
}
test "a_reaches_b" {}
test "shortest_path_is_correct_units_long" {}
test "shortest_path_is_correct_path" {}
test "a_does_not_reach_b_given_impossible_path" {}
