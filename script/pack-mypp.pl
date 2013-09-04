#!/usr/bin/perl
use Applify;
use strict;
use warnings;

my $OUT_FILE = q(script/mypp);
my $CLOSURE = 0;

{
  open my $APPLIFY, '<', $INC{'Applify.pm'} or die $!;
  open my $BIN, '<', 'bin/mypp' or die $!;
  open my $MODULE, '<', 'lib/App/Mypp.pm' or die $!;
  open my $OUT, '>', $OUT_FILE or die $!;

  print $OUT scalar <$BIN>; # she-bang
  print $OUT "BEGIN { \$INC{'Applify.pm'} = 'INCLUDED' }\n";
  print $OUT "BEGIN { \$INC{'App/Mypp.pm'} = 'INCLUDED' }\n";
  append($OUT, $APPLIFY);
  append($OUT, $BIN);
  append($OUT, $MODULE);
  chmod 0755, $OUT_FILE;
  print "App::Mypp packed to $OUT_FILE\n";
}

print "Starting $OUT_FILE...\n\n";
system $OUT_FILE;

sub append {
  my($WRITE, $READ) = @_;
  my $print = 1;
  my $__end__ = 0;

  $CLOSURE++;
  print $WRITE "CLOSURE_$CLOSURE: {\n";

  while(<$READ>) {
      next if /^use (?:strict|warnings)/; # already tested
      next if /^documentation '/; # skip documentation in bin/mypp

      if(/^=/) {
          $print = 0 
      }
      if(/^__[A-Z]+__$/) {
        print $WRITE "}\n";
        $__end__++;
      }
      if(/\S/ and $print) {
          print $WRITE $_;
      }
      if(/^=cut/ or /^}/) {
          $print = 1;
      }
  }

  print $WRITE "}\n" unless $__end__;
}
