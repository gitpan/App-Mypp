use ExtUtils::MakeMaker;

unless($ENV{FORCE_INSTALL}) {
  eval "require File::Spec; 1" or die $@;
  for my $dir (File::Spec->path, split /\,/, $ENV{Aliases}) {
    $found = -x File::Spec->catfile($dir, 'git') and last;
    $found = -x File::Spec->catfile($dir, 'git.exe') and last;
  }
  unless($found) {
    warn <<"    MESSAGE";

I searched and searched for "git" and "git.exe", but I could not
find the executable. If you you know you got git installed, you
can run the installer again with FORCE_INSTALL=1.

NA: Unable to build distribution on this platform.

    MESSAGE

    exit 0;
  }
}

WriteMakefile(
  NAME => 'App::Mypp',
  ABSTRACT_FROM => 'lib/App/Mypp.pm',
  VERSION_FROM => 'lib/App/Mypp.pm',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  LICENSE => 'perl',
  PREREQ_PM => {
    'Applify' => '0.0501',
  },
  BUILD_REQUIRES => {
    'Test::More' => '0.90',
  },
  META_MERGE => {
    resources => {
      license => 'http://dev.perl.org/licenses/',
      homepage => 'https://metacpan.org/release/App-Mypp',
      bugtracker => 'https://github.com/jhthorsen/app-mypp/issues',
      repository => 'https://github.com/jhthorsen/app-mypp',
     #MailingList => 'some-mailing@list.org',
    },
  },
  test => {
    TESTS => 't/*.t',
  },
  EXE_FILES => ['bin/mypp'],
);
