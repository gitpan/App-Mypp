use strict;
use warnings;
use Cwd;
use File::Path ();
use Test::More;
use App::Mypp;

my $work_dir = '/tmp/my-test-project';
my $mypp = join '/', Cwd::getcwd, '/bin/mypp';
$ENV{PERL5LIB} = join '/', Cwd::getcwd, '/lib';
File::Path::rmtree($work_dir);

unless(eval 'require File::Copy::Recursive; 1') {
    plan skip_all => 'File::Copy::Recursive is required';
}
unless(File::Copy::Recursive::dircopy('t/my-test-project', $work_dir)) {
    plan skip_all => "Could not create $work_dir";
}

chdir $work_dir;
system git => 'init';

unless(-d '.git') {
  plan skip_all => 'cannot run test without .git repo';
}

$mypp = do $mypp;
$App::Mypp::SILENT = defined $ENV{MYPP_SILENT} ? $ENV{MYPP_SILENT} : 1;

{
  unlink 'MANIFEST';
  unlink 'MANIFEST.SKIP';
  unlink 'My-Test-Project-42.01.tar.gz';
  unlink 'README';
}

{
  $mypp->_build;
  ok -s 'MANIFEST', 'MANIFEST created';
  ok -s 'MANIFEST.SKIP', 'MANIFEST.SKIP created';
  ok -s 'My-Test-Project-42.01.tar.gz', 'My-Test-Project-42.01.tar.gz';
  ok -s 'README', 'README created';
}

{
  open my $FH, '<', 'lib/My/Test/Project.pm' or die $!;
  my $top_module_text = do { local $/; <$FH> };
  like $top_module_text, qr/^42\.01/m, 'version was added to top pod';
  like $top_module_text, qr/^our \$VERSION = '42\.01';/m, 'VERSION was added to top module';
}

{
  open my $FH, '<', 'Changes' or die $!;
  like do { local $/; <$FH> }, qr/42\.01\s{4}\w+\s+\w+\s+\d{1,2}\s/, 'timestamp was added to Changes';
  like $mypp->changes->{text}, qr/^42\.01\s{4}[^\n]+\n[^C]+Cool feature/s, 'changes->text is set';
  is $mypp->_changes_to_commit_message, "Released version 42\.01\n\n       * Cool feature\n", 'commit message got extra line';
}

{
  # cannot be tested in system.t, because it mess up the original repo
  is $mypp->_make('clean'), 1, 'make clean';
}

done_testing;
