use strict;
use warnings;
use lib q(lib);
use Test::More;
use App::Mypp;

$ENV{MYPP_TEST_WAS_RUN} = 0;
-d '.git' or plan skip_all => 'cannot run test without .git repo';

$ENV{PERL5LIB} = Cwd::getcwd .'/lib';
$ENV{MYPP_TEST_WAS_RUN} = 1;
$App::Mypp::SILENT = 1;
$App::Mypp::PAUSE_FILENAME = 'pause.info';
my $app = bless {}, 'App::Mypp';

chdir 't/my-test-project/' or die $!;

{
    is(ref $app->config, 'HASH', 'attr config is a hash ref');
    is($app->config->{just_to_make_test_work}, 42, 'attr config is read');
    is($app->name, 'My-Test-Project', 'attr name = My-Test-Project');
    is($app->top_module, 'lib/My/Test/Project.pm', 'attr top_module = lib/My/Test/Project.pm');
    is($app->top_module_name, 'My::Test::Project', 'attr top_module_name = My::Test::Project');
    is(ref $app->changes, 'HASH', 'attr changes is a hash ref');
    like($app->changes->{text}, qr{^42\.01.*Init repo}s, 'changes->text is set');
    is($app->changes->{version}, '42.01', 'changes->version is set');
    is($app->dist_file, 'My-Test-Project-42.01.tar.gz', 'dist_file is set');

    is($app->_got_parent_module('App::Mypp', { 'App' => $App::Mypp::VERSION }), 1, 'App::Mypp got parent module');
    is($app->_got_parent_module('App::Mypp', { 'App' => 0 }), undef, 'App::Mypp does not have parent module');
    is($app->_got_parent_module('App::Mypp', { 'App' => 42, 'App::Mypp' => 24 }), undef, 'App::Mypp does not have parent module');

    is($app->_system('echo foo'), 1, 'echo foo');
    eval { $app->_system('invalid-command-that-does-not-exists') };
    like($@, qr{system\(invalid-command-that-does-not-exists\) == -1}, 'invalid-command-that-does-not-exists');
    is($app->_git('branch'), 1, 'git branch');
    eval { $app->_git('invalid') };
    like($@, qr{system\(git invalid\) == 256}, 'git invalid');
    is($app->_make('clean'), 1, 'make clean');
    eval { $app->_make('invalid') };
    like($@, qr{system\(make invalid\) == 512}, 'make invalid');

    is_deeply(
        [sort keys %{ $app->_templates }],
        [
            '.gitignore',
            'Changes',
            'MANIFEST.skip',
            'Makefile.PL',
            't/00-load.t',
            't/00-pod-coverage.t',
            't/00-pod.t',
        ],
        '_templates defined'
    );

    like(
        $app->_requires,
        qr{requires q\(App::Mypp\).*requires q\(Applify\)}s,
        'found deps'
    );
}

{
    $app->_timestamp_to_changes;
    open my $FH, '<', 'Changes' or die $!;
    like(do { local $/; <$FH> }, qr/42\.01\s{4}\w+\s+\w+\s+\d{1,2}\s/, 'timestamp was added to Changes');
    $app->_git(checkout => 'Changes');
}

{
    $app->_update_version_info;
    open my $FH, '<', 'lib/My/Test/Project.pm' or die $!;
    like(do { local $/; <$FH> }, qr/^42\.01.*/m, 'timestamp was added to Project.pm');
}

{
    $app->_build;
    ok(-e 'My-Test-Project-42.01.tar.gz', 'My-Test-Project-42.01.tar.gz') and $app->_git(reset => 'HEAD^');
    ok(-e 'MANIFEST', 'MANIFEST created');
    ok(-e 'README', 'README created');
}

done_testing;

END {
    if($ENV{MYPP_TEST_WAS_RUN}) {
        system git => tag => -d => '42.01';
        system git => checkout => 'Changes';
        system git => checkout => 'lib/My/Test/Project.pm';
        unlink 'META.yml';
        unlink 'MYMETA.json';
        unlink 'MYMETA.yml';
        unlink 'Makefile';
        unlink 'Makefile.PL';
        unlink 'Makefile.old';
        unlink 'Changes.old';
        unlink 'MANIFEST';
        unlink 'MANIFEST.skip';
        unlink 'README';
        unlink 'My-Test-Project-42.01.tar.gz';
        system rm => -rf => 'inc';
    }
}
