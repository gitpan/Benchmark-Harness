package Benchmark::Harness::Values;
use base qw(Benchmark::Harness::Trace);
use strict;
use vars qw($CVS_VERSION); $CVS_VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);


=pod

=head1 Benchmark::Harness::Trace

=head2 SYNOPSIS

(stay tuned . . . )

=cut

### ###########################################################################
### ###########################################################################
### ###########################################################################
package Benchmark::Harness::Handler::Values;
use base qw(Benchmark::Harness::Handler::Trace);
use Benchmark::Harness::Constants;

### ###########################################################################
#sub reportTraceInfo {
#    return Benchmark::Harness::Handler::Trace::reportTraceInfo(@_);
#}

### ###########################################################################
#sub reportValueInfo {
#    return Benchmark::Harness::Handler::Trace::reportValueInfo(@_);
#}

### ###########################################################################
# USAGE: Benchmark::Trace::MethodArguments('class::method', [, 'class::method' ] )
sub OnSubEntry {
  my $self = shift;
  my $origMethod = shift;

  my $i=1;
  for ( @_ ) {
    $self->NamedObjects($i, $_) if defined $_;
    last if ( $i++ == 20 );
  }
  if ( scalar(@_) > 20 ) {
    #$self->print("<G n='".scalar(@_)."'/>");
  };
  $self->reportTraceInfo();#(shift, caller(1));
  return @_; # return the input arguments unchanged.
}

### ###########################################################################
# USAGE: Benchmark::Trace::MethodReturn('class::method', [, 'class::method' ] )
sub OnSubExit {
  my $self = shift;
  my $origMethod = shift;

  if (wantarray) {
    my $i=1;
    for ( @_ ) {
      $self->NamedObjects($i, $_) if defined $_;
      last if ( $i++ == 20 );
    }
    if ( scalar(@_) > 20 ) {
      #$self->print("<G n='".scalar(@_)."'/>");
    };
  } else {
    scalar $self->NamedObjects('0', $_[0]) if defined $_[0];
    return $_[0];
  }
  return @_;
}

### ###########################################################################

=head1 AUTHOR

Glenn Wood, <glennwood@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2004 Glenn Wood. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

1;