# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use ExtUtils::testlib;
use lib 't/lib','./blib/lib','./lib';
use Benchmark::Harness;
use Test::Simple tests => 2;

$VERSION = sprintf("%d.%02d", q$Revision: 1.07 $ =~ /(\d+)\.(\d+)/);

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { select STDERR; $| = 1; select STDOUT; $| = 1; }
END {
    }

# THIS ALSO SERVES AS AN EXAMPLE OF A FULLY FUNCTIONAL Benchmark::Harness CLIENT
    # Trace simple looping
    my @traceParameters = qw(Trace 1 -TestServer::M.* TestServer::Loop);
    my $traceHarness = new Benchmark::Harness(@traceParameters);
    TestServer::new(5,10,15,3,4); # Fire the server method,
    my $old = $traceHarness->old(); # and here's our result.
## THAT'S ALL THERE IS TO THE ILLUSTRATION!
    ok($old, 'Trace performed');
    
    # Save result for Glenn's easy viewing (before mangling below).
    if ( ($^O eq 'MSWin32') && ($ENV{USERNAME} eq 'woodg') ) {
        open XML, ">t/benchmarkTrace.temp.xml";
        print XML $$old; close XML;
    }

    # These attributes will not be the same for all tests, once each.
    $$old =~ s{\n}{}gs;
    for ( qw(n tm pid userid os) ) {
        $$old =~ s{ $_=(['"]).*?\1}{};
    }
    # These attributes will not be the same for all tests, many times.
    for ( qw(t f ps) ) {
        $$old =~ s{ $_=(['"]).*?\1}{}g;
    }

    # Compare our results with what is expected.
    if ( open TMP, "<t/benchmarkTrace.xml" ) {
        my $tmp = join '',<TMP>; close TMP;
        ok ( $tmp eq $$old, 'Result is as expected' ) ;
    } else {
        ok ( 0, 't/benchmarkTrace.xml not found' );
    }

    # Glenn's easy viewing.
    if ( ($^O eq 'MSWin32') && ($ENV{USERNAME} eq 'woodg') ) {
        open XML, ">t/benchmarkTrace.trimmed.xml";
        print XML $$old; close XML;
        system('t\\benchmarkTrace.temp.xml');
    }

__END__

