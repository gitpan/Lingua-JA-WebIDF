use strict;
use warnings;
use Lingua::JA::WebIDF;
use Test::More;
use Test::Warn;
use Test::Fatal;

can_ok('Lingua::JA::WebIDF', qw/new idf df/);

like(exception { Lingua::JA::WebIDF->new },                   qr/appid is needed/);
like(exception { Lingua::JA::WebIDF->new(document => 1000) }, qr/Unknown option: document/);

my $webidf = Lingua::JA::WebIDF->new( appid => 'てすと' );
$webidf    = Lingua::JA::WebIDF->new({ appid => 'てすと', fetch_df => 0 });
isa_ok($webidf, 'Lingua::JA::WebIDF');

my $score;

warning_is { $score = $webidf->df }
'Undefined word was set to df method', 'df: undefined word';
is($score, undef);

warning_is { $score = $webidf->idf }
'Undefined word was set to idf method', 'idf: undefined word';
is($score, undef);

isnt($webidf->df('川'), 5000, 'fetch df from default df_file');

done_testing;
