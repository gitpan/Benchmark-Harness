use strict;
use Benchmark::Harness;
package Benchmark::Harness::Trace;
use base qw(Benchmark::Harness);
use vars qw($VERSION); $VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

### ###########################################################################
sub Initialize {
  my $self = Benchmark::Harness::Initialize(@_);

# Things we get for the ProcessInfo element:
#
# W32 Linux   attr : meaning
#  X    X      'm' : virtual memory size (kilobytes)
#       X      'r' : resident set size (kilobytes)
#       X      'u' : user mode time (milliseconds)
#       X      's' : kernel mode time (milliseconds)
#       X      'x' : user + kernal time
#  ?    ?      't' : system time, since process started, from time()
#       X      'p' : percent cpu used since process started

if ( $^O eq 'MSWin32' ) {

  $self->{XmlTempFilename} = 'C:/TEMP/benchmark_harness';
  eval 'use Win32::Process::Info';
  $self->{procInfo} = Win32::Process::Info->new(undef,'NT');

  *Benchmark::Harness::Handler::Trace::reportProcessInfo =
      sub {
            my $self = shift;
            my $proc = ($self->[Benchmark::Harness::Handler::HARNESS]->{procInfo}->GetProcInfo({no_user_info=>1},$$))[0];
            Benchmark::Harness::Handler::reportProcessInfo($self,
                {
                     'm' => $proc->{WorkingSetSize}/1024
                    ,'s' => $proc->{KernelModeTime} || '0'
                    ,'t' => (time() - $self->[Benchmark::Harness::Handler::HARNESS]->{_startTime})
                    ,'u' => $proc->{UserModeTime}
                }
                ,@_
              );
          };
}
else { # Assume Linux, for now . . .

  $self->{XmlTempFilename} = '/tmp/benchmark_harness';

  *Benchmark::Harness::Handler::Trace::reportProcessInfo =
      sub {
          my $self = shift;

          my $ps = `ps -l -p $$`;
          my ($pMem, $pTimeH, $pTimeM, $pTimeS) = ($ps =~ m{CMD(?:\s+\S+){9}\s+(\S+)(?:\s+\S+){2}\s+(\d+):(\d+):(\d+)}s);
          my $pTime = ( $pTimeH*60 + $pTimeM*60 ) + $pTimeS;

          Benchmark::Harness::Handler::reportProcessInfo($self,
            {
               'm' => $pMem
              ,'t' => (time() - $self->[Benchmark::Harness::Handler::HARNESS]->{_startTime})
              ,'u' => $pTime
            }
            ,@_
          );
      };
}
  return $self;
}

package Benchmark::Harness::Handler::Trace;
use base qw(Benchmark::Harness::Handler);
use strict;

=pod

=head1 Benchmark::Harness::Trace

=head2 SYNOPSIS

(stay tuned . . . )

=head2 Impact

=over 8

=item1 MSWin32

Approximately 0.7 millisecond per trace.

=item1 Linux

=back

=head2 Available

=over 8

These process parameters are also available via this code, but are not transferred to the harness report.

=item1 MSWin32

  'Caption',
  'CommandLine',
  'CreationClassName',
  'CreationDate',
  'CSCreationClassName',
  'CSName',
  'Description',
  'ExecutablePath',
  'ExecutionState',
  'Handle',
  'HandleCount',
  'InstallDate',
  'KernelModeTime' => @s
  'MaximumWorkingSetSize',
  'MinimumWorkingSetSize',
  'Name',
  'OSCreationClassName',
  'OSName',
  'OtherOperationCount',
  'OtherTransferCount',
  'PageFaults',
  'PageFileUsage',
  'ParentProcessId',
  'PeakPageFileUsage',
  'PeakVirtualSize',
  'PeakWorkingSetSize',
  'Priority',
  'PrivatePageCount',
  'ProcessId',
  'QuotaNonPagedPoolUsage',
  'QuotaPagedPoolUsage',
  'QuotaPeakNonPagedPoolUsage',
  'QuotaPeakPagedPoolUsage',
  'ReadOperationCount',
  'ReadTransferCount',
  'SessionId',
  'Status',
  'TerminationDate',
  'ThreadCount',
  'UserModeTime' => @u
  'VirtualSize',
  'WindowsVersion',
  'WorkingSetSize' => @m
  'WriteOperationCount',
  'WriteTransferCount'

=item1 Linux



=back

=cut

### ###########################################################################
sub OnSubEntry {
  my $self = shift;
  $self->reportProcessInfo();#(shift, caller(1));
  return @_; # return the input arguments unchanged.
}

### ###########################################################################
sub OnSubExit {
  my $self = shift;
  $self->reportProcessInfo();#(shift, caller(1));
  return @_; # return the input arguments unchanged.
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