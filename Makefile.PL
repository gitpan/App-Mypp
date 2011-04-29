use inc::Module::Install;

name q(App-Mypp);
all_from q(lib/App/Mypp.pm);

requires q(Cwd) => 3.3;
requires q(File::Basename) => 2.7;
requires q(File::Find) => 1.1;
requires q(Test::Compile) => 0.11;
requires q(Test::Pod::Coverage) => 0.11;

test_requires q(YAML::Tiny) => 1.4;
test_requires q(Test::More) => 0.9;

bugtracker q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Mypp);
homepage q(http://jhthorsen.github.com/app-mypp);
repository q(git://github.com/jhthorsen/app-mypp.git);

install_script q(bin/mypp);
auto_install;
WriteAll;
