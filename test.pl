# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use ExtUtils::testlib;
use lib 't/lib','./blib/lib','./lib';
use Benchmark::Harness;
use Test::Simple tests => 4;
use strict;
use Time::HiRes;
use vars qw($VERSION); $VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use vars qw($AuthenticationForTesting);
$AuthenticationForTesting = 'benchmark:password';

{ package Benchmark::Harness; # Override the Authenticate method for testing purposes
sub Authenticate {
    my ($self, $givenAuthentication) = @_;

# NOTE: You must code the required user/psw in the form "userId:password".
my $Authentication = $main::AuthenticationForTesting;
    return undef unless defined $Authentication;
    my ($rUserId, $rPassword) = split /\:/,$Authentication;
    my ($gUserId, $gPassword) = split /\:/,$givenAuthentication;
    return ($rUserId eq $gUserId) && ($rPassword eq $gPassword);
}
}

BEGIN { select STDERR; $| = 1; select STDOUT; $| = 1; }

my @Tests = qw(Trace TraceHighRes);
for my $handler ( @Tests ) {
    my $startTime = Time::HiRes::time();

# THIS ALSO SERVES AS AN EXAMPLE OF A FULLY FUNCTIONAL Benchmark::Harness CLIENT

    my @traceParameters = qw(TestServer::Loop (0)TestServer::Max (2|1)TestServer::M.*);
    my $traceHarness = new Benchmark::Harness($AuthenticationForTesting, $handler.'(1)', @traceParameters);
    for (my $i=0; $i<10; $i++ ) {
        TestServer::new(5,10,15,3,4); # Fire the server method,
    }

    my $old = $traceHarness->old(); # and here's our result.
## THAT'S ALL THERE IS TO THE ILLUSTRATION!

    ok($old, "$handler performed");
    print "Elapsed: ".(Time::HiRes::time() - $startTime)."\n";

    # Save result for Glenn's easy viewing (before mangling below).
    if ( ($^O eq 'MSWin32') && ($ENV{HSP_USERNAME} eq 'GlennWood') ) {
        open XML, ">t/benchmark.$handler.temp.xml" or die "Doh! $@$!";
        print XML $$old; close XML;
    }

    # These attributes will not be the same for all tests, once each.
    $$old =~ s{\n}{}gs;
    for ( qw(n tm pid userid os) ) {
        $$old =~ s{ $_=(['"]).*?\1}{};
    }
    # These attributes will not be the same for all tests, many times.
    for ( qw(t f p r s m u x) ) {
        $$old =~ s{ $_=(['"]).*?\1}{}g;
    }

    # Compare our results with what is expected.
    if ( open TMP, "<t/benchmark.$handler.xml" ) {
        my $tmp = join '',<TMP>; close TMP;
        my $success = $tmp eq $$old;
        ok ( $success, "Result cmp Expected (result ".($success?'eq':'ne')." t/benchmark.$handler.xml)" ) ;
    } else {
        ok ( 0, "t/benchmark.$handler.xml not found" );
    }

    # Glenn's easy viewing.
    if ( ($^O eq 'MSWin32') && ($ENV{HSP_USERNAME} eq 'GlennWood') ) {
        open XML, ">t/benchmark.$handler.trimmed.xml";
        print XML $$old; close XML;
    }
}
    # Glenn's easy viewing.
    if ( ($^O eq 'MSWin32') && ($ENV{HSP_USERNAME} eq 'GlennWood') ) {
        system("t\\benchmark.$Tests[0].temp.xml");
    }

__END__

