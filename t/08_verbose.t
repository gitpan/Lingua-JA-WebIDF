use strict;
use warnings;
use Lingua::JA::WebIDF;
use Test::More;
use Test::Warn;


my $df_file = './df/utf8.st';

my $webidf = Lingua::JA::WebIDF->new(
    driver  => 'Storable',
    df_file => $df_file,
    verbose => 1,
);

warnings_like { $webidf->idf('ほげ' x 10); }
qr/use fetch_df/, 'verbose: 1';


$webidf = Lingua::JA::WebIDF->new(
    driver  => 'Storable',
    df_file => $df_file,
    verbose => 0
);

warning_is { $webidf->idf('ほげ' x 20); }
'', 'verbose: 0';

done_testing;
