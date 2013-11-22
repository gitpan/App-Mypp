use strict;
use warnings;
use Test::More;
use App::Mypp;
use Cwd;

plan skip_all => 'Windows?' if $^O =~ /win/i;

my $mypp = do 'bin/mypp';
$App::Mypp::SILENT = defined $ENV{MYPP_SILENT} ? $ENV{MYPP_SILENT} : 1;
$App::Mypp::PAUSE_FILENAME = 't/pause.info';
$ENV{MYPP_CONFIG} = 't/file/does/not/exist'; # avoid config()

plan skip_all => 'PAUSE_FILENAME is required' unless -r $App::Mypp::PAUSE_FILENAME;

{
  is_deeply $mypp->pause_info, { user => 'john', password => 's3cret' }, 'got pause_info';

  is $mypp->share_extension, 'CPAN::Uploader', 'default share_extension';
  delete $mypp->{share_extension};

  local $ENV{MYPP_SHARE_MODULE} = 'Y::Ikes';
  is $mypp->share_extension, 'Y::Ikes', 'share_extension from environment';
  delete $mypp->{share_extension};
}

{
  mock_cpan_uploaded();
  $mypp->_share_via_extension;
  is $::upload[0], 'CPAN::Uploader', 'share via CPAN::Uploader';
  like $::upload[1], qr{^App-Mypp-}, 'pushing the right file';
  is_deeply $::upload[2], { user => 'john', password => 's3cret' }, 'with user+password';
}

done_testing;

sub mock_cpan_uploaded {
eval <<'MOCK';
  package CPAN::Uploader;
  sub upload_file { @::upload = @_ }
  $INC{'CPAN/Uploader.pm'} = 'MOCK';
MOCK
}
