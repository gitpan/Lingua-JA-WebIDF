use strict;
use warnings;
use Lingua::JA::WebIDF;
use Test::More;
use Config::Pit qw/pit_get/;


unlink 'df.st';

my $config = pit_get('yahoo_premium_api') or die $!;

my $webidf = Lingua::JA::WebIDF->new(
    api      => 'YahooPremium',
    appid    => $config->{appid},
    fetch_df => 1,
    df_file  => 'df.st',
);

my $df = $webidf->df("テス\tト");
isnt($df, undef, 'not undef');
is($webidf->df('テス ト'), $df);

$df = $webidf->df('アア' . "\t" x 10 . 'ア');

$webidf = Lingua::JA::WebIDF->new(
    api      => 'Yahoo',
    appid    => 'test',
    fetch_df => 0,
    df_file  => 'df.st',
);

isnt($df, undef, 'not undef');
is($webidf->df('アア ア'), $df);

unlink 'df.st';

done_testing;
