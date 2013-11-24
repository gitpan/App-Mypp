package App::Mypp::ShowINC;

=head1 NAME

App::Mypp::ShowINC - Figure out what modules a script requires

=head1 DESCRIPTION

This module will print which dependencies a script or module has.

=head1 SYNOPSIS

    perl -MApp::Mypp::ShowINC some/script/or/module.nn

=cut

use strict;
use warnings;

CHECK {
    for my $m (keys %INC) {
        $m =~ s!/!::!g;
        $m =~ s!\.pm$!!;
        $m eq __PACKAGE__ and next;
        my $version = eval { $m->VERSION } or next;
        printf "%s=%s\n", $m, $version;
    }
    die '%INC was printed'
}

=head1 AUTHOR

See L<App::Mypp>.

=cut

1;
