use inc::Module::Install;

name q(App-Mypp);
all_from q(lib/App/Mypp.pm);

test_requires q(Test::More) => 0.94;

bugtracker q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Mypp);
homepage q(http://search.cpan.org/dist/App-Mypp);
repository q(git://github.com/jhthorsen/app-mypp.git);

install_script q(bin/mypp);
auto_install;
WriteAll;
