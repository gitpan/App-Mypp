use strict;
use warnings;
use lib q(lib);
use Test::More;
use App::Mypp;

plan tests =>
      1
    + 9 # attributes
    + 5 # various
    + 6 # makefile
    + 3 # manifest
    + 4 # methods
    + 3 # pause_info
    + 4 # share_via_extension
;

-d '.git' or BAIL_OUT 'cannot run test without .git repo';

init();
my $app;

eval {
    $app = App::Mypp->new;
    ok($app, 'App::Mypp instace constructed');
} or BAIL_OUT 'Cannot construct object';

eval { # attributes
    is(ref $app->config, 'HASH', 'attr config is a hash ref');
    is($app->config->{'just_to_make_test_work'}, 42, 'attr config is read');
    is($app->name, 'App-Mypp', 'attr name = App-Mypp');
    is($app->top_module, 'lib/App/Mypp.pm', 'attr top_module = lib/App/Mypp.pm');
    is($app->top_module_name, 'App::Mypp', 'attr top_module_name = App::Mypp');
    is(ref $app->changes, 'HASH', 'attr changes is a hash ref');
    like($app->changes->{'text'}, qr{^0\.01.*Init repo}s, 'changes->text is set');
    is($app->changes->{'version'}, '0.01', 'changes->version is set');
    is($app->dist_file, 'App-Mypp-0.01.tar.gz', 'dist_file is set');

    1;
} or diag $@;

eval { # various
    ok($app->timestamp_to_changes, 'timestamp_to_changes() succeeded');
    ok($app->update_version_info, 'update_version_info() succeeded');
    ok($app->generate_readme, 'generate_readme() succeeded');

    TODO: {
        todo_skip 'will this disrupt test? possible race condition', 1;
        ok($app->clean, 'clean() succeeded');
    };

    1;
} or diag $@;

eval {
    local $App::Mypp::MAKEFILE_FILENAME = 't/Makefile.test';
    ok($app->makefile, 'makefile() succeeded');
    ok(-e $App::Mypp::MAKEFILE_FILENAME, 'Makefile.PL created');
    open my $MAKEFILE, '<', $App::Mypp::MAKEFILE_FILENAME or die $!;
    my $makefile = do { local $/; <$MAKEFILE> };
    my $name = $app->name;
    my $top_module = $app->top_module;
    like($makefile, qr{name q\($name\)}, 'name is part of Makefile.PL');
    like($makefile, qr{all_from q\($top_module\)}, 'all_from is part of Makefile.PL');
    like($makefile, qr{bugtracker q\(http://rt.cpan.org/NoAuth/Bugs.html\?Dist=$name\);}, 'bugtracker is part of Makefile.PL');
    like($makefile, qr{homepage q\(http://search.cpan.org/dist/$name\);}, 'homepage is part of Makefile.PL');
    #like($makefile, qr{repository q\(git://github.com/\);}, 'repository is part of Makefile.PL');

    1;
} or diag $@;

TODO: {
    todo_skip 'difficult to make stable', 3;
    unlink 'MANIFEST', 'MANIFEST.SKIP';
    ok($app->manifest, 'manifest() succeeded');
    ok(-e 'MANIFEST', 'MANIFEST exists');
    ok(-e 'MANIFEST.SKIP', 'MANIFEST.SKIP exists');
}

eval {
    unlink 't/00-load.t';
    unlink 't/99-pod.t';
    unlink 't/99-pod-coverage.t';
    ok($app->t_load, 't_load() succeeded');
    ok(-e 't/00-load.t', 't/00-load.t created');
    ok($app->t_pod, 't_load() succeeded');
    ok(-e 't/99-pod.t', 't/99-pod.t created');
    ok(-e 't/99-pod-coverage.t', 't/99-pod-coverage.t created');

    1;
} or diag $@;

eval {
    is(ref $app->pause_info, 'HASH', 'pause_info is a hashref');
    is($app->pause_info->{'user'}, 'john', 'pause_info->username is set');
    is($app->pause_info->{'password'}, 's3cret', 'pause_info->password is set');

    1;
} or diag $@;

eval {
    is($app->share_extension, 'CPAN::Uploader', 'share_extension has default value');
    local $ENV{'MYPP_SHARE_MODULE'} = 'Foo::Share::Module';
    $app->{'share_extension'} = undef;
    is($app->share_extension, 'Foo::Share::Module', 'share_extension has environment value');

    $INC{'Foo/Share/Module.pm'} = 1;
    eval '
        package Foo::Share::Module;
        our $INPUT;
        sub upload_file { $INPUT = [@_] }
        1;
    ' or die $@;

    ok($app->share_via_extension, 'share_via_extension() succeeded');
    is_deeply($Foo::Share::Module::INPUT, ['Foo::Share::Module', 'App-Mypp-0.01.tar.gz'], 'Foo::Share::Module->upload_file was called');

    1;
} or diag $@;

#==============================================================================
sub init {
    $App::Mypp::SILENT = 1;
    $App::Mypp::CHANGES_FILENAME = 't/Changes.test';
    $App::Mypp::PAUSE_FILENAME = 't/pause.test';

    open my $CHANGES, '>', $App::Mypp::CHANGES_FILENAME or BAIL_OUT 'cannot write to t/Changes.test';
    open my $PAUSE, '>', $App::Mypp::PAUSE_FILENAME or BAIL_OUT 'cannot write to t/pause.test';

    print $CHANGES <<'CHANGES';
Revision history for App-Mypp

0.01
 * Init repo

CHANGES

    print $PAUSE <<'PAUSE';
user john
password s3cret
PAUSE
}

END {
    unlink 't/Changes.test';
    unlink 't/Makefile.test';
    unlink 't/pause.test';
    system rm => -rf => 't/inc';
}
