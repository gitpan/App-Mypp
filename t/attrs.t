use strict;
use warnings;
use Test::More;
use App::Mypp;

plan skip_all => '.git dir is required' unless -d '.git';
plan skip_all => 'YAML::Tiny is required' unless eval 'require YAML::Tiny; 1';
plan skip_all => 'Windows?' if $^O =~ /win/i;

my $mypp = bless {}, 'App::Mypp';

{
    is ref $mypp->config, 'HASH', 'attr config is a hash ref';
    is $mypp->config->{just_to_make_test_work}, 42, 'attr config is read';
    is $mypp->name, 'App-Mypp', 'attr name = App-Mypp';
    is $mypp->top_module, 'lib/App/Mypp.pm', 'attr top_module = lib/App/Mypp.pm';
    is $mypp->top_module_name, 'App::Mypp', 'attr top_module_name = App::Mypp';
    is ref $mypp->changes, 'HASH', 'attr changes is a hash ref';
    like $mypp->changes->{text}, qr/^0\.\d{2,4}.*(?:Fix|Add|Will)/s, 'changes->text is set';
    like $mypp->changes->{version}, qr/^0\.\d{2,4}$/, 'changes->version is set';
    like $mypp->dist_file, qr/^App-Mypp-0\.\d{2,4}.tar.gz$/, 'dist_file is set';
}

done_testing;
