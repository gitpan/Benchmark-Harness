package Benchmark::Harness::Handler;
use strict;
use vars qw($VERSION); $VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);
    use constant {
        ID          =>  0,
        HARNESS     =>  1,
        MODIFIERS   =>  2,
        NAME        =>  3,
        PACKAGE     =>  4,
        ORIGMETHOD  =>  5,
        HANDLED     =>  6,
        REPORT      =>  7,
        FILTER      =>  8,
        FILTERSTART =>  9,
        PROCESSIDX  => 10,  # used by TraceHighRes
    };

### ###########################################################################
# USAGE: new Benchmark::Harness::Handler(
#                       $parentHarness,
#                       modifiers_from_(...),
#                       package-name,
#                       subroutine-name)
sub new {
    my ($cls, $harness, $modifiers, $pckg, $subName) = @_;
    # If already defined, then we keep the original one
    #  ("the pen once writ . . .")
    return undef if $harness->FindHandler($pckg, $subName);

    my $self = bless [  $#{$harness->{EventList}}+1,
                        $harness,
                        $modifiers,
                        $subName,
                        $pckg,
                        undef,
                        0,
                     ], $cls;

    push @{$harness->{EventList}}, $self;
    return $self;
}

# Attached this event handler to this subroutine in the code
# Modifiers -
#           '0' : do not harness this method (even if asked to later in the parameters)
#           filter, filterStart : harness, but report only each filter-th event, starting
#                                 with the filterStart-th event. filterStart=0|undef reports
#                                 the first event, then each filter-th one thereafter.
sub Attach {
    my ($traceSubr) = @_;
    my ($modifiers, $pckg, $method) = ($traceSubr->[MODIFIERS], $traceSubr->[PACKAGE], $traceSubr->[NAME]);

    return if ( $modifiers eq '0' ); # (0) means do not harness . . .

    # Splitting handler parameters by '|' makes it easier to include them in a qw()
    my ($filter, $filterStart) = split /\s*\|\s*/, $modifiers;

    $traceSubr->[ORIGMETHOD] = \&{"$pckg\:\:$method"};

    my $newMethod;
    if ( defined $filter ) {

        $filter = $filter || 1;
        $filterStart = $filterStart || 1;
        $traceSubr->[FILTER] = $filter;
        $traceSubr->[FILTERSTART] = $filterStart;

        $newMethod = sub  {
            if ( $traceSubr->[FILTERSTART] ) {
                goto $traceSubr->[ORIGMETHOD] if ( --$traceSubr->[FILTERSTART] );
                $traceSubr->[FILTERSTART] = $traceSubr->[FILTER];
            }
            my @newArgs = $traceSubr->OnSubEntry(@_);
            $traceSubr->harnessPrintReport('E',$traceSubr);
            if (wantarray) {
                my @answer = $traceSubr->[ORIGMETHOD](@_);
                my $newAnswer = $traceSubr->OnSubExit(\@answer);
                $traceSubr->harnessPrintReport('X',$traceSubr);
                return @answer;
            } else {
                my $answer = $traceSubr->[ORIGMETHOD](@_);
                my $newAnswer = scalar $traceSubr->OnSubExit($answer);
                $traceSubr->harnessPrintReport('X',$traceSubr);
                return $answer;
            }
        };
    } else {
        $newMethod = sub {
            my @newArgs = $traceSubr->OnSubEntry(@_);
            $traceSubr->harnessPrintReport('E',$traceSubr);
            if (wantarray) {
                my @answer = $traceSubr->[ORIGMETHOD](@_);
                my $newAnswer = $traceSubr->OnSubExit(\@answer);
                $traceSubr->harnessPrintReport('X',$traceSubr);
                return @answer;
            } else {
                my $answer = $traceSubr->[ORIGMETHOD](@_);
                my $newAnswer = scalar $traceSubr->OnSubExit($answer);
                $traceSubr->harnessPrintReport('X',$traceSubr);
                return $answer;
            }
        };
    }
    eval "\*$pckg\:\:$method = \$newMethod";
    $traceSubr->[HANDLED] = 1;
}

sub Detach {
    my ($traceSubr) = @_;
    return unless $traceSubr->[HANDLED];
    my ($pckg, $method, $origMethod) = ($traceSubr->[PACKAGE],$traceSubr->[NAME],$traceSubr->[ORIGMETHOD]);
    eval "\*$pckg\:\:$method = \$origMethod";

}

### ###########################################################################
sub reportProcessInfo {
    my $self = shift;
    $self->[REPORT] = [undef,{},undef,undef] unless defined $self->[REPORT];
    my $rpt = $self->[REPORT];

    for ( @_ ) {
        my $typ = ref($_);
        if ( $typ ) {
            if ( $typ eq 'HASH' ) {
                my $hsh = $rpt->[1];
                for my $nam ( keys %$_ ) {
                    $hsh->{$nam} = $_->{$nam};
                }
            }
            elsif ( $typ eq 'ARRAY' ) {
                $rpt->[2] = [] unless defined $rpt->[2];
                push @{$rpt->[2]}, @$_;
            }
            else {
                $rpt->[3] .= $$_;
            }
        } else {
                $rpt->[0] = $_;
        }
    }
    return $self;
}

### ###########################################################################
sub harnessPrintReport {
    my $self = shift;
    return unless ref($self);
    my $harness = $self->[HARNESS];
    my ($mode, $trace) = @_;

    my $rpt = $self->[REPORT];
    return unless $rpt;

    my $fh = $harness->{_outFH};
    return unless $fh;

    print $fh '<'.(defined($rpt->[0])?$rpt->[0]:'T')." _i='$trace->[ID]' _m='$mode'";
    my $closeTag = '/>';

    my $hsh = $rpt->[1];
    map { print $fh " $_='$hsh->{$_}'" } keys %$hsh;

    if ( defined $rpt->[2] ) {
        print $fh '>'; $closeTag = '</'.(defined($rpt->[0])?$rpt->[0]:'T').'>';
        for ( @{$rpt->[2]} ) {

        }
    }

    if ( defined $rpt->[3] ) {
        print $fh '>'; $closeTag = '</'.(defined($rpt->[0])?$rpt->[0]:'T').'>';
        print $fh $rpt->[3];
    }

    print $fh $closeTag;
    $self->[REPORT] = undef;
}

### ###########################################################################
# USAGE: Invoked by attach()'d subroutine: see above.
# This is, presumably, overridden by the sub-harness.
sub OnSubEntry {
    my $self = shift;
    return @_;
}

### ###########################################################################
# USAGE: Invoked by attach()'d subroutine: see above.
# This is, presumably, overridden by the sub-harness.
sub OnSubExit {
    my $self = shift;
    return @_;
}

1;