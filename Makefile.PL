use inc::Module::Install;

name     'Lingua-JA-WebIDF';
all_from 'lib/Lingua/JA/WebIDF.pm';

requires 'Carp';
requires 'Module::Load' => 0.22; # less than 0.22 has a security problem
requires 'URI';
requires 'Furl::HTTP';
requires 'JSON';
requires 'Storable';

test_requires 'Test::More' => 0.98;
test_requires 'Test::Fatal';
test_requires 'Test::Warn' => 0.20;
test_requires 'Test::TCP'  => 1.15;
test_requires 'Test::Requires';

tests 't/*.t';
author_tests 'xt';

readme_from 'lib/Lingua/JA/WebIDF.pm';

resources(
    license    => 'http://dev.perl.org/licenses',
    repository => 'https://github.com/pawa-/Lingua-JA-WebIDF',
    bugtracker => 'https://github.com/pawa-/Lingua-JA-WebIDF/issues',
);

WriteAll;
