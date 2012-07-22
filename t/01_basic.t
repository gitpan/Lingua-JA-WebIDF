use strict;
use warnings;
use Lingua::JA::WebIDF;
use Test::More;
use Test::Warn;
use Test::Fatal;


can_ok('Lingua::JA::WebIDF', qw/new idf df db_open db_close purge/);

my $exception = exception { Lingua::JA::WebIDF->new; };
like($exception, qr/appid is needed/);

$exception = exception { Lingua::JA::WebIDF->new(document => 1000); };
like($exception, qr/Unknown option: document/);

my $webidf = Lingua::JA::WebIDF->new( appid => 'てすと' );
$webidf    = Lingua::JA::WebIDF->new({ appid => 'てすと', fetch_df => 0, documents => 250_0000_0000 });
isa_ok($webidf, 'Lingua::JA::WebIDF');

my $score;

warning_is { $score = $webidf->df }
'Undefined word has been set', 'df: undefined word';
is($score, undef);

warning_is { $score = $webidf->idf }
'Undefined word has been set', 'idf: undefined word';
is($score, undef);

warning_is { $score = $webidf->idf(undef, 'df') }
'Undefined df has been set', 'idf: undefined df';
is($score, undef);

my $default_df = 5000;
isnt($webidf->df('川'), undef,       'fetch_df from default df_file');
isnt($webidf->df('川'), $default_df, 'fetch df from default df_file');

is($webidf->idf(100, 'df'), log(250_0000_0000 / 100), 'calculate idf with df');

done_testing;
