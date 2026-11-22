.pragma library

function days(month) {
    var first = new Date(month.getFullYear(), month.getMonth(), 1, 12);
    var monday = (first.getDay() + 6) % 7;
    var grid = [];
    for (var index = 0; index < 42; index++)
        grid.push(new Date(first.getFullYear(), first.getMonth(), index - monday + 1, 12));
    return grid;
}
