use strict;
use warnings;
use Test::More;
use App::Mypp;

plan skip_all => 'Windows?' if $^O =~ /win/i;
plan skip_all => '.git dir is required' unless -d '.git';

$ENV{MYPP_CONFIG} = 't/file/does/not/exist'; # avoid config()
my $mypp = bless {}, 'App::Mypp';

{
  is $mypp->_got_parent_module('App::Mypp', { 'App' => $App::Mypp::VERSION }), 1, 'App::Mypp got parent module';
  is $mypp->_got_parent_module('App::Mypp', { 'App' => 0 }), undef, 'App::Mypp does not have parent module';
  is $mypp->_got_parent_module('App::Mypp', { 'App' => 42, 'App::Mypp' => 24 }), undef, 'App::Mypp does not have parent module';

  like(
    $mypp->_project_requires('run'),
    qr{'Applify' => '\d\.\d+',}s,
    'found run deps'
  );
}

done_testing;
