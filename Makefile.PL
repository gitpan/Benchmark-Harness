
# $Name:  $

use ExtUtils::MakeMaker;

{   package MM;
sub new {
    my $self = shift;
    $self->SUPER::new(@_);
}
}
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $prereq_pm = { 'Devel::Peek' => 1.01
                 ,'Devel::Size' => 0.58
                };
if ( $^O eq 'MSWin32' ) {
    $prereq_pm->{'Win32::Process::Info'} = 1.002;
    $prereq_pm->{'Win32::OLE'} = 0.1403;
}

WriteMakefile(
    'NAME'	=> 'Benchmark::Harness',
    'VERSION_FROM' => "lib/Benchmark/Harness.pm", # finds $VERSION
    # test.pl uses this hash, also, to poll all modules we depend on
    'PREREQ_PM' => $prereq_pm,
    ($] ge '5.005') ? (
                     'AUTHOR' => 'Glenn Wood http://search.cpan.org/search?mode=author&query=GLENNWOOD',
                     'ABSTRACT' => 'Test/Profile harness for general purpose peeking',
                    ) : (),
);

