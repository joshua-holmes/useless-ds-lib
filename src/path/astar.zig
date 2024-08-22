fn build_grid_possible() void {
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
}
fn build_grid_impossible() void {
    // _____________
    //| | | | | | | |
    //| | |b| | | | |
    //|x|x|x|x|x|x|x|
    //| |x| | | | | |
    //| | | | |a| | |
    //| | | | | | | |
    //| | | | | | | |
    // _____________
}
test "a_reaches_b" {}
test "shortest_path_is_correct_units_long" {}
test "shortest_path_is_correct_path" {}
test "a_does_not_reach_b_given_impossible_path" {}
