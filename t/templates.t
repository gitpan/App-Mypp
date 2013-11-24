use strict;
use warnings;
use Test::More;
use App::Mypp;

plan skip_all => 'Windows?' if $^O =~ /win/i;
plan skip_all => 'cannot execute t/bin/git' unless -x 't/bin/git';

$ENV{USER} = "batman";
$ENV{PATH} ||= "";
$ENV{PATH} = "t/bin:$ENV{PATH}";
$ENV{MYPP_CONFIG} = 't/file/does/not/exist'; # avoid config()

my $mypp = bless { top_module => 'lib/Dummy/Module.pm' }, 'App::Mypp';
my @print;

{
  no warnings 'redefine';
  *App::Mypp::_write = sub {
    shift;
    shift;
    @print = @_;
  };
}

{
  is_deeply(
    [sort keys %{ $mypp->_templates }],
    [
      '.gitignore',
      'Changes',
      'MANIFEST.SKIP',
      'Makefile.PL',
      't/00-basic.t',
    ],
    '_templates defined'
  );

  ok !$mypp->_generate_file_from_template('t/00-basic.t'), 'file exists';

  $mypp->{force} = 1;
  ok $mypp->_generate_file_from_template('t/00-basic.t'), 'force overwrite';
}

for my $file (qw/ .gitignore MANIFEST.SKIP /) {
  my $n = $file eq '.gitignore' ? 13 : 10;
  $mypp->_generate_file_from_template($file);

  is int(split /\n/, $print[0]), $n, "$file contains x lines";
  like "@print", qr{^.?\.swp$}m, 'contains *.swp';
}

{
  $mypp->_generate_file_from_template('Changes');

  is int(split /\n/, $print[0]), 5, 'Changes contains x lines';
  like "@print", qr{Revision history for Dummy-Module}, 'contains Revision history for Dummy-Module';
}

{
  $mypp->_generate_file_from_template('Makefile.PL');

  if(eval { require Sub::Name }) {
    is int(split /\n/, $print[0]), 28, 'Makefile.PL contains 28 lines';
  }
  else {
    is int(split /\n/, $print[0]), 27, 'Makefile.PL contains 27 lines';
  }

  like "@print", qr{NAME => 'Dummy::Module',}, "contains NAME => 'Dummy::Module',";
  like "@print", qr{ABSTRACT_FROM => 'lib/Dummy/Module\.pm',}, "contains ABSTRACT_FROM => 'lib/Dummy/Module.pm',";
  like "@print", qr{VERSION_FROM => 'lib/Dummy/Module\.pm',}, "contains VERSION_FROM => 'lib/Dummy/Module.pm',";
  like "@print", qr{AUTHOR => 'Bruce Wayne <wayne\@industries>',}, "contains author and email";
  like "@print", qr{LICENSE => 'perl',}, "contains LICENSE => 'perl',";
  like "@print", qr{'Applify' => '\d+\.\d{2,4}',}, "contains 'Applify' => '...',";
  like "@print", qr{license => 'http://dev\.perl\.org/licenses/',}, "contains license => 'http://dev.perl.org/licenses/',";
  like "@print", qr{homepage => 'https://metacpan\.org/release/Dummy-Module',}, "contains homepage => 'https://metacpan.org/release/Dummy-Module',";
  like "@print", qr{bugtracker => 'https://github\.com/batman/dummy-module/issues',}, "contains bugtracker => 'https://github\.com/batman/dummy-module/issues";
  like "@print", qr{repository => 'https://github\.com/batman/dummy-module\.git',}, 'contains repository';
}

{
  $mypp->_generate_file_from_template('t/00-basic.t');

  is int(split /\n/, $print[0]), 29, 't/00-basic.t contains x lines';
  like "@print", qr{use \$module; 1}, 'contains use test';
  like "@print", qr{Test::Pod::pod_file_ok\(\$file\);}, 'contains pod test';
  like "@print", qr{Test::Pod::Coverage::pod_coverage_ok\(\$module\);}, 'contains pod coverage test';
}

done_testing;
