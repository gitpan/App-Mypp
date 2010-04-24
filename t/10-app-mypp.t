use strict;
use warnings;
use lib q(lib);
use Test::More;
use App::Mypp;

-d '.git' or plan skip_all => 'cannot run test without .git repo';

plan tests =>
      1
    + 10 # attributes
    + 2 # requires
    + 8 # timestamp_to_changes, update_version_info, generate_readme, clean
    + 7 # makefile
    + 3 # manifest
    + 5 # t_load + t_pod
    + 3 # pause_info
    + 4 # share_via_extension
    + 2 # git
;

$App::Mypp::SILENT = 1;
$App::Mypp::PAUSE_FILENAME = 'pause.info';
$Foo::Share::Module::INPUT = 0; # Name "Foo::Share::Module::INPUT" used only once: possible typo
my $app;

chdir 't/my-test-project/' or die $!;

eval {
    $app = App::Mypp->new;
    ok($app, 'App::Mypp instace constructed');
} or BAIL_OUT 'Cannot construct object';

eval { # attributes
    is(ref $app->config, 'HASH', 'attr config is a hash ref');
    is($app->config->{'just_to_make_test_work'}, 42, 'attr config is read');
    is($app->name, 'My-Test-Project', 'attr name = My-Test-Project');
    is($app->top_module, 'lib/My/Test/Project.pm', 'attr top_module = lib/My/Test/Project.pm');
    is($app->top_module_name, 'My::Test::Project', 'attr top_module_name = My::Test::Project');
    is(ref $app->changes, 'HASH', 'attr changes is a hash ref');
    like($app->changes->{'text'}, qr{^0\.01.*Init repo}s, 'changes->text is set');
    is($app->changes->{'version'}, '0.01', 'changes->version is set');
    is($app->dist_file, 'My-Test-Project-0.01.tar.gz', 'dist_file is set');
    is(ref $app->_eval_package_requires, 'ARRAY', '_eval_package_requires returned ARRAY');

    1;
} or diag "attributes failed: $@";

eval {
    my %req;

    %req = $app->requires('lib');
    is_deeply([sort keys %req], [qw/POSIX Symbol Tie::Hash base/], 'lib/ requires ok');

    %req = $app->requires('t');
    is_deeply([sort keys %req], [qw/Test::More/], 't/ requires ok');

    1;
} or diag "requires failed: $@";

eval { # timestamp_to_changes, update_version_info, generate_readme, clean
    my $date = qx/date/;
    local $/;

    $date =~ s/^(\w+\s\w+\s\w+).*\n+$/$1/;

    ok($app->timestamp_to_changes, 'timestamp_to_changes() succeeded');
    open my $CHANGES, '<', 'Changes' or die $!;
    do { $_ = scalar <$CHANGES> };
    like($_, qr{0\.01\s+$date\s}, 'Changes got timestamp');

    ok($app->update_version_info, 'update_version_info() succeeded');
    open my $MODULE, '<', $app->top_module or die $!;
    do { $_ = scalar <$MODULE> };
    like($_, qr{^0\.01}m, 'top module got new version');

    ok($app->generate_readme, 'generate_readme() succeeded');
    ok(-e 'README', 'README generated');

    open my $MANIFEST, '>', 'MANIFEST' or die $!;
    print $MANIFEST "foo\n";
    close $MANIFEST;
    ok($app->clean, 'clean() succeeded'); # need more testing
    ok(!-e 'MANIFEST', 'MANIFEST got cleaned');

    1;
} or diag "timestamp_to_changes/update_version_info/generate_readme/clean failed: $@";

eval {
    local $INC{'Catalyst.pm'} = 1;
    ok($app->makefile, 'makefile() succeeded');
    ok(-e 'Makefile.PL', 'Makefile.PL created');
    open my $MAKEFILE, '<', 'Makefile.PL' or die $!;
    my $makefile = do { local $/; <$MAKEFILE> };
    my $name = $app->name;
    my $top_module = $app->top_module;
    like($makefile, qr{name q\($name\)}, 'name is part of Makefile.PL');
    like($makefile, qr{all_from q\($top_module\)}, 'all_from is part of Makefile.PL');
    like($makefile, qr{bugtracker q\(http://rt.cpan.org/NoAuth/Bugs.html\?Dist=$name\);}, 'bugtracker is part of Makefile.PL');
    like($makefile, qr{homepage q\(http://search.cpan.org/dist/$name\);}, 'homepage is part of Makefile.PL');
    like($makefile, qr{catalyst;}, 'catalyst; is part of Makefile.PL');
    #like($makefile, qr{repository q\(git://github.com/\);}, 'repository is part of Makefile.PL');

    1;
} or diag "makefile failed: $@";

eval {
    ok($app->manifest, 'manifest() succeeded');
    ok(-e 'MANIFEST', 'MANIFEST exists');
    ok(-e 'MANIFEST.SKIP', 'MANIFEST.SKIP exists');
} or diag "manifest failed: $@";

eval {
    ok($app->t_load, 't_load() succeeded');
    ok(-e 't/00-load.t', 't/00-load.t created');
    ok($app->t_pod, 't_load() succeeded');
    ok(-e 't/99-pod.t', 't/99-pod.t created');
    ok(-e 't/99-pod-coverage.t', 't/99-pod-coverage.t created');

    1;
} or diag "create test failed: $@";

eval {
    is(ref $app->pause_info, 'HASH', 'pause_info is a hashref');
    is($app->pause_info->{'user'}, 'john', 'pause_info->username is set');
    is($app->pause_info->{'password'}, 's3cret', 'pause_info->password is set');

    1;
} or diag "pause info failed: $@";

eval {
    is($app->share_extension, 'CPAN::Uploader', 'share_extension has default value');
    local $ENV{'MYPP_SHARE_MODULE'} = 'Foo::Share::Module';
    $app->{'share_extension'} = undef;
    is($app->share_extension, 'Foo::Share::Module', 'share_extension has environment value');

    $INC{'Foo/Share/Module.pm'} = 1;
    eval '
        package Foo::Share::Module;
        our $INPUT = 1;
        sub upload_file { $INPUT = [@_] }
        1;
    ' or die $@;

    ok($app->share_via_extension, 'share_via_extension() succeeded');
    is_deeply($Foo::Share::Module::INPUT, ['Foo::Share::Module', 'My-Test-Project-0.01.tar.gz'], 'Foo::Share::Module->upload_file was called');

    1;
} or diag "share: $@";

TODO: {
    todo_skip 'need to override git', 2;
    $app->tag_and_commit;
    $app->share_via_git;
}

$app->clean;
system git => checkout => '.';
system rm => -r => qw(
    Makefile.PL
    README
    t/00-load.t
    t/99-pod-coverage.t
    t/99-pod.t
);
