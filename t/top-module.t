use strict;
use warnings;
use Test::More;
use App::Mypp;

plan skip_all => 'Windows?' if $^O =~ /win/i;
my $mypp = bless {}, 'App::Mypp';

$ENV{MYPP_CONFIG} = 't/file/does/not/exist'; # avoid config()

for my $name (qw( App-Mypp-0.19 )) {
  $mypp->{name} = $name;
  delete $mypp->{top_module};

  eval {
    is $mypp->top_module, 'lib/App/Mypp.pm', "got top_module from $name";
    is $mypp->top_module_name, 'App::Mypp', "got top_module_name from $name";
  } or do {
    diag $@;
  }
}

done_testing;
