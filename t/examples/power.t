use Test;
use _007::Test;

my @lines = run-and-collect-lines("examples/power.007");

is +@lines, 5, "correct number of lines of output";
is @lines[0], "8", "line #1 correct";
is @lines[1], "9", "line #2 correct";
is @lines[2], "1", "line #3 correct";
is @lines[3], "42", "line #4 correct";
is @lines[4], "256", "line #5 correct";

done-testing;
