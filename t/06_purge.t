use strict;
use warnings;
use utf8;
use Lingua::JA::WebIDF;
use Test::More;
use Test::Fatal;
use Storable;
use Encode qw/decode_utf8/;
use Test::Requires qw/TokyoCabinet/;

binmode Test::More->builder->$_ => ':utf8'
    for qw/output failure_output todo_output/;


my $STORABLE_FILE     = './df/idf_t.st';
my $TOKYOCABINET_FILE = './df/idf_t.tch';
my $EXPIRES_IN        = 365;

unlink $STORABLE_FILE;
unlink $TOKYOCABINET_FILE;

db_init();

subtest 'Storable' => sub {

    my $webidf = Lingua::JA::WebIDF->new(
        driver     => 'Storable',
        df_file    => $STORABLE_FILE,
        expires_in => $EXPIRES_IN,
    );

    my $exception = exception { $webidf->purge };
    like($exception, qr/called without arguments/, 'called without aruguments');

    $webidf->purge($EXPIRES_IN);

    my $df = Storable::lock_retrieve($STORABLE_FILE);

    for my $key (keys %{$df})
    {
        is(scalar keys %{$df}, 2, 'num of record');
        ok($key eq '新鮮' || $key eq '賞味期限切れる１日前', 'purged');
    }
};

subtest 'TokyoCabinet' => sub {

    my $webidf = Lingua::JA::WebIDF->new(
        driver     => 'TokyoCabinet',
        df_file    => $TOKYOCABINET_FILE,
        expires_in => $EXPIRES_IN,
    );

    $webidf->db_open('write');

    my $exception = exception { $webidf->purge };
    like($exception, qr/called without arguments/, 'called without aruguments');

    $webidf->purge($EXPIRES_IN);

    $webidf->db_close;

    my $hdb = TokyoCabinet::HDB->new;

    $hdb->open($TOKYOCABINET_FILE, $hdb->OWRITER | $hdb->OCREAT)
        or die $hdb->errmsg($hdb->ecode);

    $hdb->iterinit;

    while( defined(my $key = $hdb->iternext) )
    {
        $key = decode_utf8($key);
        is($hdb->rnum, 2, 'num of record');
        ok($key eq '新鮮' || $key eq '賞味期限切れる１日前', 'purged');
    }

    $hdb->close;
};

done_testing;


sub db_init
{
    my $prev_day_time = time - 60 * 60 * 24 * ($EXPIRES_IN - 1);
    my $next_day_time = time - 60 * 60 * 24 * ($EXPIRES_IN + 1);
    my $just_day_time = time - 60 * 60 * 24 * $EXPIRES_IN;

    my %data = (
        '賞味期限切れ'         => "1000\t0",
        '新鮮'                 => "100\t" . time,
        '賞味期限切れる１日前' => "10\t$prev_day_time",
        '賞味期限切れて１日後' => "1\t$next_day_time",
        'ちょうど切れたとこ'   => "7\t$just_day_time",
    );

    Storable::nstore(\%data, $STORABLE_FILE) or die $!;

    my $hdb = TokyoCabinet::HDB->new;

    $hdb->open($TOKYOCABINET_FILE, $hdb->OWRITER | $hdb->OCREAT)
        or die $hdb->errmsg($hdb->ecode);

    for my $key (keys %data)
    {
        $hdb->put( $key, $data{$key} ) or die hdb->errmsg($hdb->ecode);
    }

    $hdb->close;
}
