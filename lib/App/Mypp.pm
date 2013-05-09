package App::Mypp;

=head1 NAME

App::Mypp - Maintain Your Perl Project

=head1 VERSION

0.16

=head1 DESCRIPTION

C<mypp> is a result of me getting tired of doing the same stuff - or
rather forgetting to do the same stuff - for each of my Perl projects.
mypp does not feature the same things as L<Dist::Zilla>, but I would
like to think of mypp vs dzil as cpanm vs CPAN - or at least that
is what I'm aiming for. (!) What I don't want to do is configure
anything, so 1) it should just work 2) it might not work as you want it to.

Want to try it out? Run the line below in your favourite terminal:

    wget -q http://github.com/jhthorsen/app-mypp/raw/master/script/mypp-packed -O - | perl -

Running that line will start the experimental code from github - meaning
the latest release. Run at own risk - and don't forget to put your files
under version control first!

=head1 SYNOPSIS

Actions are also available with out "--", such as "init", "update", "test",
"clean", "build" and "share".

    mypp [action];
    mypp --action;
    mypp --force update Makefile.PL
    mypp update t/00-load.t

=head1 SAMPLE CONFIG FILE

    ---
    # Default to a converted version of top_module
    name: Foo-Bar

    # Default to a converted version of the project folder
    # Example: ./foo-bar/lib/Foo/Bar.pm, were "foo-bar" is the
    # project folder.
    top_module: lib/Foo/Bar.pm

    # Default to a converted version of top_module.
    top_module_name: Foo::Bar

    # Default to CPAN::Uploader. Can also be set through
    # MYPP_SHARE_MODULE environment variable.
    share_extension: AnyModuleName

    # Not in use if share_extension == CPAN::Uploader. Usage:
    # share_extension->upload_file($dist_file, share_params);
    share_params: [ { answer: 42 } ]

All config params are optional, since mypp tries to figure out the
information for you.

=head1 SHARING THE MODULE

By default the L<CPAN::Uploader> module is used to upload the module to CPAN.
This module uses C<$HOME/.pause> to find login details:

    user your_pause_username
    password your_secret_pause_password

It also uses git to push changes and tag a new release:

    git commit -a -m "$message_from_changes_file"
    git tag "$latest_version_in_changes_file"
    git push origin $current_branch
    git push --tags origin

The commit and tagging is done with C<-dist>, while pushing the changes to
origin is done with C<-share>.

=head1 CHANGES FILE

The expected format in C<Changes> is:

    Some random header, for Example:
    Revision history for Foo-Bar

    0.02
       * Fix something
       * Add something else

    0.01 Tue Apr 20 19:34:15 2010
       * First release
       * Add some feature

C<mypp> automatically adds the date before creating a dist.

=cut

use strict;
use warnings;
use Cwd;
use File::Basename;
use File::Find;

our $VERSION = '0.16';
our $SILENT = $ENV{MYPP_SILENT} || $ENV{SILENT} || 0;
our $PAUSE_FILENAME = $ENV{HOME} .'/.pause';
our $VERSION_RE = qr/\d+ \. [\d_]+/x;

open my $OLDOUT, '>&STDOUT';
open my $OLDERR, '>&STDERR';

sub _from_config ($&) {
    my($name, $sub) = @_;

    no strict 'refs';

    *$name = sub {
        my $self = shift;
        return $self->{$name} ||= $self->config->{$name} || $self->$sub(@_);
    };
}

sub _attr ($&) {
    my($name, $sub) = @_;

    no strict 'refs';

    *$name = sub {
        my $self = shift;
        return $self->{$name} ||= $self->$sub(@_);
    };
}

=head1 ATTRIBUTES

=head2 config

 $hash = $self->config;

Holds the config from C<mypp.yml> or C<MYPP_CONFIG> environment variable.

=cut

_attr config => sub {
    my $self = shift;
    my $file = $ENV{MYPP_CONFIG} || 'mypp.yml';
    my $config;

    return {} unless(-e $file);

    eval "use YAML::Tiny; 1;" or do {
        die <<"ERROR";

YAML::Tiny is not installed, meaning '$file' will not be read.
Use one of the commands below to install it:

\$ aptitude install libyaml-tiny-perl
\$ wget -q http://xrl.us/cpanm -O - | perl - YAML::Tiny

ERROR
    };

    $config = YAML::Tiny->read($file);

    return $config->[0] if($config and $config->[0]);
    return {};
};

=head2 name

Holds the project name. The project name is extracted from the
L</top_module>, unless set in config file. Example: C<foo-bar>.

=cut

_from_config name => sub {
    my $self = shift;
    my $name;

    $name = join '-', split '/', $self->top_module;
    $name =~ s,^.?lib-,,;
    $name =~ s,\.pm$,,;

    return $name;
};

=head2 repository

Holds the project repository url. The url is extracted from the origin git repo
unless set.

=cut

_from_config repository => sub {
    my $repo = (qx/git remote show -n origin/ =~ /URL: (.*)$/m)[0] || 'git://github.com/';
    chomp $repo;
    return $repo;
};

=head2 top_module

Holds the top module location. This path is extracted from either
C<name> in the config file or the basename of the project. Example value:
C<lib/Foo/Bar.pm>.

The project might look like this:

 ./foo-bar/lib/Foo/Bar.pm

Where "foo-bar" is the basename.

=cut

_from_config top_module => sub {
    my $self = shift;
    my $name = $self->config->{name} || basename getcwd;
    my @path = split /-/, $name;
    my $path = 'lib';
    my $file;

    $path[-1] .= '.pm';

    for my $p (@path) {
        opendir my $DH, $path or die "Cannot find top module from project name '$name': $!\n";
        for my $f (readdir $DH) {
            if(lc $f eq lc $p) {
                $path = "$path/$f";
                last;
            }
        }
    }

    unless(-f $path) {
        die "Cannot find top module from project name '$name': $path is not a plain file\n";
    }

    return $path;
};

=head2 top_module_name

Returns the top module name, extracted from L</top_module>. Example value:
C<Foo::Bar>.

=cut

_from_config top_module_name => sub {
    local $_ = $_[0]->top_module;
    s,\.pm,,; s,^/?lib/,,g; s,/,::,g;
    return $_;
};

=head2 changes

Holds the latest information from C<Changes>. Example:

    {
        text => qq(0.03 .... \n * Something has changed),
        version => 0.03,
    }

=cut

_attr changes => sub {
    my $self = shift;
    my($text, $version);

    $self->_generate_file_from_template('Changes');
    open my $CHANGES, '<', 'Changes' or die "Read Changes: $!\n";

    while(<$CHANGES>) {
        if($text) {
            last if /^$/;
            $text .= $_;
        }
        elsif(/^($VERSION_RE)/) {
            $version = $1;
            $text = $_;
        }
    }

    unless($text and $version) {
        die "Could not find commit message nor version info from Changes\n";
    }

    return {
        text => $text,
        version => $version,
    };
};

=head2 dist_file

Returns the name of the target dist file.

=cut

_attr dist_file => sub {
    my $self = shift;
    return sprintf '%s-%s.tar.gz', $self->name, $self->changes->{version};
};

=head2 pause_info

Holds information from C<$HOME/.pause>. See L<CPAN::Uploader> for details.
Example:

    {
        user => 'johndoe',
        password => 's3cret',
    }

=cut

_attr pause_info => sub {
    open my $PAUSE, '<', $PAUSE_FILENAME or die "Read $PAUSE_FILENAME: $!\n";
    my %info = map { my($k, $v) = split /\s+/, $_, 2; chomp $v; ($k, $v) } <$PAUSE>;

    $info{user} or die "'user <name>' is not set in $PAUSE_FILENAME\n";
    $info{password} or die "'password <mysecret>' is not set in $PAUSE_FILENAME\n";

    return \%info;
};

=head2 share_extension

Holds the classname of the module which should be used for sharing. This
value can either come from the config file or the C<MYPP_SHARE_MODULE> environment
variable, or fallback to L<CPAN::Uploader>.

=cut

_attr share_extension => sub {
    my $self = shift;

    return $ENV{MYPP_SHARE_MODULE} if($ENV{MYPP_SHARE_MODULE});
    return $self->config->{share_extension} if($self->config->{share_extension});
    return 'CPAN::Uploader';
};

=head2 share_params

This attribute must hold an array ref, since it is flattened into a list when
used as an argument to L</share_extension>'s C<upload_file()> method.

=cut

_from_config share_params => sub {
    return;
};

=head2 force

Set by C<--force>

=cut

sub force { 0 }

my %TEMPLATES;
sub _templates {
    unless(%TEMPLATES) {
        my($key, $text);
        while(<DATA>) {
            if(/\%\% (\S+)/) {
                $TEMPLATES{$key} = $text if($key);
                $key = $1;
                $text = '';
            }
            else {
                $text .= $_;
            }
        }
        $TEMPLATES{$key} = $text
    }
    return \%TEMPLATES;
}

sub _build {
    my $self = shift;
    my(@rollback, $e);

    $self->_make('clean');

    eval {
        $self->_update_version_info;
        $self->_generate_file_from_template('MANIFEST.SKIP');
        $self->_system(sprintf '%s %s > %s', 'perldoc -tT', $self->top_module, 'README');
        eval { $self->_system('rm ' .$self->name .'* 2>/dev/null') }; # don't care if this fail

        push @rollback, sub { rename 'Changes.old', 'Changes' };
        $self->_timestamp_to_changes;

        push @rollback, sub { $self->_git(reset => 'HEAD^') };
        $self->_git(commit => -a => -m => $self->_changes_to_commit_message);

        push @rollback, sub { $self->_git(tag => -d => $self->changes->{version}) };
        $self->_git(tag => $self->changes->{version});

        $self->_make('manifest');
        $self->_make('dist');
        1;
    } or do {
        $e = $@ || 'Not sure what went wrong';
        $_->() for reverse @rollback;
        die $e;
    };
}

sub _changes_to_commit_message {
    my $self = shift;
    my $text = $self->changes->{text};
    my $version = $self->changes->{version};

    # need to add extra line
    $text =~ s/.*\n/Released version $version\n\n/;
    $text;
}

sub _timestamp_to_changes {
    my $self = shift;
    my $date = localtime;
    my($changes, $pm);

    rename 'Changes', 'Changes.old' or die $!;
    open my $OLD, '<', 'Changes.old' or die "Read Changes.old: $!\n";
    open my $NEW, '>', 'Changes' or die "Write Changes: $!\n";
    { local $/; $changes = <$OLD> };

    if($changes =~ s/\n($VERSION_RE)\s*$/{ sprintf "\n%-7s  %s", $1, $date }/em) {
        print $NEW $changes;
        delete $self->{changes}; # need to re-read changes
        $self->_log("Add timestamp '$date' to Changes");
        return 1;
    }

    die "Unable to update Changes with timestamp\n";
}

sub _update_version_info {
    my $self = shift;
    my $top_module = $self->top_module;
    my $version = $self->changes->{version};
    my $top_module_text;

    open my $MODULE, '+<', $top_module or die "Read/write $top_module: $!\n";
    { local $/; $top_module_text = <$MODULE> }
    seek $MODULE, 0, 0;

    $top_module_text =~ s/=head1 VERSION.*?\n=/=head1 VERSION\n\n$version\n\n=/s;
    $top_module_text =~ s/^((?:our)?\s*\$VERSION)\s*=.*$/$1 = '$version';/m;

    print $MODULE $top_module_text;
    $self->_log("Update version in $top_module to $version");

    return 1;
}

sub _requires {
    my $self = shift;
    my(%requires, %test_requires, @requires, $corelist);
    my $wanted = sub {
                    return if(!-f $_);
                    return if(/\.swp/);
                    open my $REQ, '-|', "$^X -MApp::Mypp::ShowINC '$_' 2>/dev/null";
                    while(<$REQ>) {
                        my($m, $v) = split /=/;
                        chomp $v;
                        $_[0]->{$m} = $v unless($requires{$m});
                    }
                };

    # required to skip core modules
    eval "use Module::CoreList; 1" and $corelist = 1;

    finddepth({ no_chdir => 1, wanted => sub { $wanted->(\%requires) } }, 'bin') if(-d 'bin');
    finddepth({ no_chdir => 1, wanted => sub { $wanted->(\%requires) } }, 'lib');
    finddepth({ no_chdir => 1, wanted => sub { $wanted->(\%test_requires) } }, 't');

    for my $m (sort keys %requires) {
        my $v = $requires{$m};
        next if($self->_got_parent_module($m, \%requires));
        next if($corelist and Module::CoreList->first_release($m));
        push @requires, $v ? "requires q($m) => $v;" : "# requires q($m) => ??;";
    }

    if(%test_requires) {
        push @requires, '';
    }

    for my $m (sort keys %test_requires) {
        my $v = $test_requires{$m};
        next if($self->_got_parent_module($m, \%requires));
        next if($corelist and Module::CoreList->first_release($m));
        push @requires, $v ? "test_requires q($m) => $v;" : "# test_requires q($m) => ??;";
    }

    return join "\n", @requires;
}

sub _got_parent_module {
    my($self, $module, $map) = @_;

    for my $m (keys %$map) {
        next unless($map->{$m});
        next unless($module =~ /^$m\::/);
        next unless(!$map->{$module} or $map->{$module} eq $map->{$m});
        return 1;
    }

    return;
}

sub _share_via_extension {
    my $self = shift;
    my $file = $self->dist_file;
    my $share_extension = $self->share_extension;

    eval "use $share_extension; 1" or die "This feature requires $share_extension to be installed";

    # might die...
    if($share_extension eq 'CPAN::Uploader') {
        $share_extension->upload_file($file, {
            user => $self->pause_info->{user},
            password => $self->pause_info->{password},
        });
    }
    else {
        $share_extension->upload_file($file, @{ $self->share_params || [] });
    }

    return 1;
}

sub _generate_file_from_template {
    my($self, $file) = @_;
    my $content;

    if(-e $file and !$self->force) {
        $self->_log("$file already exists. (Skipping)");
        return;
    }

    $content = $self->_templates->{$file} or die "No such template defined: $file";
    $content =~ s!\$\{(\w+)\}!{ $self->$1 }!ge;
    mkdir dirname $file;
    open my $FH, '>', $file or die "Write $file: $!";
    print $FH $content;
    $self->_log("$file was generated");
}

sub _system {
    shift->_log("\$ @_");
    open STDERR, '>', '/dev/null' if $SILENT;
    open STDOUT, '>', '/dev/null' if $SILENT;
    system @_; $_ = $?;
    open STDERR, '>&', $OLDERR if $SILENT;
    open STDOUT, '>&', $OLDOUT if $SILENT;
    die "system(@_) == $_" if $_;
    return 1;
}

sub _git {
    shift->_system(git => @_);
}

sub _make {
    my $self = shift;
    $self->_generate_file_from_template('Makefile.PL');
    $self->_system(perl => 'Makefile.PL') unless(-e 'Makefile');
    $self->_system(make => @_);
    return 1;
}

sub _log {
    return if $SILENT;
    print $_[1], "\n";
}

=head1 SEE ALSO

=over

=item * L<App::Cpanminus>

=item * L<Dist::Zilla>

=item * L<Shipit>

=item * L<http://jhthorsen.github.com/app-mypp>

=back

=head1 BUGS

Report bugs and issues at L<http://github.com/jhthorsen/app-mypp/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2007-2010 Jan Henning Thorsen, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHOR

Jan Henning Thorsen, C<jhthorsen at cpan.org>

=cut

1;
__DATA__
%% t/00-load.t ==============================================================
use lib 'lib';
use Test::More;
eval 'use Test::Compile; 1' or plan skip_all => 'Test::Compile required';
all_pm_files_ok();
%% t/00-pod.t ===============================================================
use lib 'lib';
use Test::More;
eval 'use Test::Pod; 1' or plan skip_all => 'Test::Pod required';
all_pod_files_ok();
%% t/00-pod-coverage.t ======================================================
use lib 'lib';
use Test::More;
eval 'use Test::Pod::Coverage; 1' or plan skip_all => 'Test::Pod::Coverage required';
all_pod_coverage_ok({ also_private => [ qr/^[A-Z_]+$/ ] });
%% MANIFEST.SKIP ============================================================
^mypp.yml
.git
\.old
\.swp
~$
^blib/
^Makefile$
^MANIFEST.*
^${name}
%% .gitignore ===============================================================
/META.yml
/MYMETA.*
/blib/
/inc/
/pm_to_blib
/MANIFEST
/MANIFEST.bak
/Makefile
/Makefile.old
*.old
*.swp
~$
/${name}*tar.gz
%% Changes ==================================================================
Revision history for ${name}

0.01
       * Started project
       * Add cool feature
%% Makefile.PL ==============================================================
use inc::Module::Install;

name q(${name});
all_from q(${top_module});

${_requires}

bugtracker q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=${name});
homepage q(https://metacpan.org/release/${name});
repository q(${repository});

# install_script glob('bin/*');
auto_install;
WriteAll;
ll;
