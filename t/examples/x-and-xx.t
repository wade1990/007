use Test;
use _007::Test;

my @lines = run-and-collect-lines("examples/x-and-xx.007");

is +@lines, 5, "correct number of lines";

is @lines[0], "testingtesting", "first line";
is @lines[1], "[1, 2, 3]", "second line";
is @lines[2], "[1, 2, 3, 1, 2, 3]", "third line";
is @lines[3], "[1, 1, 2, 3]", "fourth line";
is @lines[4], "44444", "fifth line";

done-testing;
