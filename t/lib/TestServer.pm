package TestServer;
use strict;

my ($MinValue, $MaxValue) = (999999,0);

sub new {
    my $cls = shift;
    my @ary = Loop(@_);
    return Loop(@_);
}

sub Loop {
    map { Max($_) } @_;
    map { Min($_) } @_;
    return ($MinValue, $MaxValue) if wantarray;
    return [$MinValue, $MaxValue];
}

sub Max {
    $MaxValue = ($MaxValue > $_[0])?$MaxValue:$_[0];
    return $MaxValue;
}

sub Min {
    $MinValue = ($MinValue < $_[0])?$MinValue:$_[0];
    return $MinValue;
}

1;