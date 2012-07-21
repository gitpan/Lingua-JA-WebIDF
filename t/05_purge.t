use strict;
use warnings;
use utf8;
use Lingua::JA::WebIDF;
use Storable;
use Encode qw/decode_utf8/;
use Test::More;
use Test::Fatal;
use Test::Requires qw/TokyoCabinet/;

binmode Test::More->builder->$_ => ':utf8'
    for qw/output failure_output todo_output/;


unlink 'df.st';
unlink 'df.tch';

my $expires_in = 365;

preparation();

my $webidf = Lingua::JA::WebIDF->new(
    appid    => 'test',
    fetch_df => 0,
    driver   => 'Storable',
    df_file  => 'df.st',
);

my $exception = exception { $webidf->purge };
like($exception, qr/called without arguments/, 'called without aruguments');

$webidf->purge($expires_in);

$webidf = Lingua::JA::WebIDF->new(
    appid    => 'test',
    fetch_df => 0,
    driver   => 'TokyoCabinet',
    df_file  => 'df.tch',
);

$webidf->db_open('write');
$webidf->purge($expires_in);
$webidf->db_close;

my $hdb = TokyoCabinet::HDB->new;

$hdb->open('df.tch', $hdb->OWRITER | $hdb->OCREAT)
    or die( $hdb->errmsg($hdb->ecode) );

$hdb->iterinit;

while( defined(my $key = $hdb->iternext) )
{
    $key = decode_utf8($key);
    like($key, qr/^(?:新鮮|賞味期限切れる１日前)$/, 'purge@TokyoCabinet');
}

$hdb->close or die( $hdb->errmsg($hdb->ecode) );

my $df = Storable::lock_retrieve('df.st');

for my $key (keys %{$df})
{
    like($key, qr/^(?:新鮮|賞味期限切れる１日前)$/, 'purge@Storable');
}

unlink 'df.st';
unlink 'df.tch';

done_testing;


sub preparation
{
    my $prev_day_time = time - 60 * 60 * 24 * ($expires_in - 1);
    my $next_day_time = time - 60 * 60 * 24 * ($expires_in + 1);

    my %data = (
        '賞味期限切れ'         => "1000\t0",
        '新鮮'                 => "100\t" . time,
        '賞味期限切れる１日前' => "10\t$prev_day_time",
        '賞味期限切れて１日後' => "1\t$next_day_time",
    );

    Storable::nstore(\%data, 'df.st');

    my $hdb = TokyoCabinet::HDB->new;

    $hdb->open('df.tch', $hdb->OWRITER | $hdb->OCREAT)
        or die( $hdb->errmsg($hdb->ecode) );

    for my $key (keys %data)
    {
        $hdb->put($key, $data{$key}) or warn( $hdb->errmsg($hdb->ecode) );
    }

    $hdb->close or die( $hdb->errmsg($hdb->ecode) );
}
