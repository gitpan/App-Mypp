use strict;
use warnings;
use Test::More;
use App::Mypp;

my $mypp = bless {}, 'App::Mypp';
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
  my $n = $file eq '.gitignore' ? 13 : 9;
  $mypp->_generate_file_from_template($file);

  is int(split /\n/, $print[0]), $n, "$file contains x lines";
  like "@print", qr{^.?\.swp$}m, 'contains *.swp';
}

{
  $mypp->_generate_file_from_template('Changes');

  is int(split /\n/, $print[0]), 5, 'Changes contains x lines';
  like "@print", qr{Revision history for App-Mypp}, 'contains Revision history for App-Mypp';
}

{
  $mypp->_generate_file_from_template('Makefile.PL');

  is int(split /\n/, $print[0]), 29, 'Makefile.PL contains x lines';
  like "@print", qr{NAME => 'App-Mypp',}, "contains NAME => 'App-Mypp',";
  like "@print", qr{ABSTRACT_FROM => 'lib/App/Mypp\.pm',}, "contains ABSTRACT_FROM => 'lib/App/Mypp.pm',";
  like "@print", qr{VERSION_FROM => 'lib/App/Mypp\.pm',}, "contains VERSION_FROM => 'lib/App/Mypp.pm',";
  like "@print", qr{AUTHOR => '[^<]+<[^>]+>',}, "contains author and email";
  like "@print", qr{LICENSE => 'perl',}, "contains LICENSE => 'perl',";
  like "@print", qr{'Applify' => '\d+\.\d{2,4}',}, "contains 'Applify' => '...',";
  like "@print", qr{license => 'http://dev\.perl\.org/licenses/',}, "contains license => 'http://dev.perl.org/licenses/',";
  like "@print", qr{homepage => 'https://metacpan\.org/release/App-Mypp',}, "contains homepage => 'https://metacpan.org/release/App-Mypp',";
  like "@print", qr{bugtracker => 'http://rt\.cpan\.org/NoAuth/Bugs\.html\?Dist=App-Mypp',}, "contains bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Mypp',";
}

{
  $mypp->_generate_file_from_template('t/00-basic.t');

  is int(split /\n/, $print[0]), 29, 't/00-basic.t contains x lines';
  like "@print", qr{use \$module; 1}, 'contains use test';
  like "@print", qr{Test::Pod::pod_file_ok\(\$file\);}, 'contains pod test';
  like "@print", qr{Test::Pod::Coverage::pod_coverage_ok\(\$module\);}, 'contains pod coverage test';
}

done_testing;
