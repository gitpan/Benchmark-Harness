
use vars qw($VERSION); $VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

print "1..2\n";

use Benchmark::Harness::Trace;
print "ok Benchmark::Harness::Trace\n";
use Benchmark::Harness::TraceHighRes;
print "ok Benchmark::Harness::TraceHighRes\n";

1;
