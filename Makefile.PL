use ExtUtils::MakeMaker;
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
      bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Mypp',
      repository => 'https://github.com/jhthorsen/app-mypp',
     #MailingList => 'some-mailing@list.org',
    },
  },
  test => {
    TESTS => 't/*.t',
  },
  EXE_FILES => ['bin/mypp'],
);
