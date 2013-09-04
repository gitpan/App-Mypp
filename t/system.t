use strict;
use warnings;
use Test::More;
use App::Mypp;

plan skip_all => '.git dir is required' unless -d '.git';

my $mypp = bless {}, 'App::Mypp';
$App::Mypp::SILENT = defined $ENV{MYPP_SILENT} ? $ENV{MYPP_SILENT} : 1;

{
  is $mypp->_system('echo foo'), 1, 'echo foo';
  eval { $mypp->_system('invalid-command-that-does-not-exists') };

  like $@, qr{system\(invalid-command-that-does-not-exists\) == -1}, 'invalid-command-that-does-not-exists';
  is $mypp->_git('branch'), 1, 'git branch';

  eval { $mypp->_git('invalid') };
  like $@, qr{system\(git invalid\) == 256}, 'git invalid';

  eval { $mypp->_make('invalid') };
  like $@, qr{system\(make invalid\) == 512}, 'make invalid';
}

done_testing;
