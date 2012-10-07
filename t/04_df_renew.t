use strict;
use warnings;
use utf8;
use Lingua::JA::WebIDF;
use Test::More;
use Test::Warn;
use Test::TCP;
use Storable;
use Encode qw/decode_utf8/;
use Test::Requires qw/Plack::Loader Plack::Builder Plack::Request/;

binmode Test::More->builder->$_ => ':utf8'
    for qw/output failure_output todo_output/;


my $IS_TOKYOCABINET_INSTALLED = eval 'use TokyoCabinet; 1;';

my $PSGI_YAHOO         = './t/psgi/Yahoo.psgi';
my $PSGI_YAHOO_PREMIUM = './t/psgi/YahooPremium.psgi';
my $PSGI_404           = './t/psgi/404.psgi';
my $PSGI_500           = './t/psgi/500.psgi';

my $YAHOO_HIT         = 12345;
my $YAHOO_PREMIUM_HIT = 2000;

my $STATUS_OK       = '200';
my @API             = qw/Yahoo YahooPremium/;
my @DRIVER          = qw/Storable TokyoCabinet/;
my @FETCH_DF        = qw/0 1/;
my @STATUS_CODE     = qw/200 404 500/;
my @WORD            = qw/超古い ナウい 29日前 30日前 31日前 YahooのAPIでunavailableを引き起こす単語 NOHIT/;

my $STORABLE_FILE     = './df/idf_t.st';
my $TOKYOCABINET_FILE = './df/idf_t.tch';

my %DF_FILE_OF = (
    Storable     => $STORABLE_FILE,
    TokyoCabinet => $TOKYOCABINET_FILE,
);

test_tcp(
    server => sub {

        my $port = shift;

        my $server = Plack::Loader->auto(
            port => $port,
            host => '127.0.0.1',
        );

        my $app = builder {
            mount '/yahoo/'         => Plack::Util::load_psgi($PSGI_YAHOO),
            mount '/yahoo_premium/' => Plack::Util::load_psgi($PSGI_YAHOO_PREMIUM),
            mount '/404/'           => Plack::Util::load_psgi($PSGI_404),
            mount '/500/'           => Plack::Util::load_psgi($PSGI_500),
        };

        $server->run($app);
    },
    client => sub {

        my $port = shift;

        for my $api (@API)
        {
            for my $driver (@DRIVER)
            {
                for my $fetch_df (@FETCH_DF)
                {
                    for my $status_code (@STATUS_CODE)
                    {
                        for my $word (@WORD)
                        {
                            my $test_pattern
                                = "\napi: $api\ndriver: $driver\nfetch_df: $fetch_df\nstatus_code: $status_code\nword: $word";

                            subtest $test_pattern => sub {

                                binmode Test::More->builder->$_ => ':utf8'
                                    for qw/output failure_output todo_output/;

                                plan skip_all =>  "TokyoCabinet is not installed."
                                    if (!$IS_TOKYOCABINET_INSTALLED && $driver eq 'TokyoCabinet');

                                unlink $STORABLE_FILE;
                                unlink $TOKYOCABINET_FILE;

                                db_init();

                                $Lingua::JA::WebIDF::API::Yahoo::BASE_URL        = "http://127.0.0.1:$port/yahoo/";
                                $Lingua::JA::WebIDF::API::YahooPremium::BASE_URL = "http://127.0.0.1:$port/yahoo_premium/";

                                my $df_file = $DF_FILE_OF{$driver};

                                my %config = (
                                    api        => $api,
                                    appid      => 'test',
                                    df_file    => $df_file,
                                    driver     => $driver,
                                    fetch_df   => $fetch_df,
                                    expires_in => 30,
                                );

                                my $webidf = Lingua::JA::WebIDF->new(%config);

                                $webidf->db_open('write') if $driver eq 'TokyoCabinet';

                                my $test_pattern
                                = "\napi: $api\ndriver: $driver\nfetch_df: $fetch_df\nstatus_code: $status_code\nword: $word";

                                if ($status_code ne $STATUS_OK)
                                {
                                    local $Lingua::JA::WebIDF::API::Yahoo::BASE_URL        = "http://127.0.0.1:$port/$status_code/";
                                    local $Lingua::JA::WebIDF::API::YahooPremium::BASE_URL = "http://127.0.0.1:$port/$status_code/";

                                    my $df;

                                    if ($fetch_df)
                                    {
                                        if
                                        (
                                            $word eq $WORD[0]
                                            || $word eq $WORD[3]
                                            || $word eq $WORD[4]
                                            || $word eq $WORD[5]
                                            || $word eq $WORD[6]
                                        )
                                        {
                                            warning_like { $df = $webidf->df($word); }
                                            qr/^$api: $status_code/, $test_pattern;
                                        }
                                        else
                                        {
                                            warning_is { $df = $webidf->df($word); }
                                            '', $test_pattern;
                                        }

                                    }
                                    else # fetch_df: false
                                    {
                                        if ($word eq $WORD[6])
                                        {
                                            warning_like { $df = $webidf->df($word); }
                                            qr/use fetch_df/, $test_pattern;
                                        }
                                        else
                                        {
                                            warning_is { $df = $webidf->df($word); }
                                            '', $test_pattern;
                                        }
                                    }

                                    is($df, 10000, $test_pattern) if $word eq $WORD[0];
                                    is($df, 1000,  $test_pattern) if $word eq $WORD[1];
                                    is($df, 29,    $test_pattern) if $word eq $WORD[2];
                                    is($df, 30,    $test_pattern) if $word eq $WORD[3];
                                    is($df, 31,    $test_pattern) if $word eq $WORD[4];
                                    is($df, 100,   $test_pattern) if $word eq $WORD[5];
                                    is($df, undef, $test_pattern) if $word eq $WORD[6];
                                }
                                else # 200 ok
                                {
                                    if ($fetch_df)
                                    {
                                        my $df;

                                        if ($word eq $WORD[5])
                                        {
                                            warning_like { $df = $webidf->df($word); }
                                            qr/unavailable/, $test_pattern;
                                        }
                                        else
                                        {
                                            warning_is { $df = $webidf->df($word); }
                                            '', $test_pattern;
                                        }

                                        if ($api eq 'Yahoo')
                                        {
                                            is($df, $YAHOO_HIT, $test_pattern) if $word eq $WORD[0];
                                            is($df, 1000,       $test_pattern) if $word eq $WORD[1];
                                            is($df, 29,         $test_pattern) if $word eq $WORD[2];
                                            is($df, $YAHOO_HIT, $test_pattern) if $word eq $WORD[3];
                                            is($df, $YAHOO_HIT, $test_pattern) if $word eq $WORD[4];
                                            is($df, 100,        $test_pattern) if $word eq $WORD[5];
                                            is($df, 0,          $test_pattern) if $word eq $WORD[6];
                                        }
                                        else
                                        {
                                            is($df, $YAHOO_PREMIUM_HIT, $test_pattern) if $word eq $WORD[0];
                                            is($df, 1000,               $test_pattern) if $word eq $WORD[1];
                                            is($df, 29,                 $test_pattern) if $word eq $WORD[2];
                                            is($df, $YAHOO_PREMIUM_HIT, $test_pattern) if $word eq $WORD[3];
                                            is($df, $YAHOO_PREMIUM_HIT, $test_pattern) if $word eq $WORD[4];
                                            is($df, 100,                $test_pattern) if $word eq $WORD[5];
                                            is($df, 0,                  $test_pattern) if $word eq $WORD[6];
                                        }
                                    }
                                    else # fetch_df: false
                                    {
                                        my $df;

                                        if ($word eq $WORD[6])
                                        {
                                            warning_like { $df = $webidf->df($word); }
                                            qr/use fetch_df/, $test_pattern;
                                        }
                                        else
                                        {
                                            warning_is { $df = $webidf->df($word); }
                                            '', $test_pattern;
                                        }

                                        is($df, 10000, $test_pattern) if $word eq $WORD[0];
                                        is($df, 1000,  $test_pattern) if $word eq $WORD[1];
                                        is($df, 29,    $test_pattern) if $word eq $WORD[2];
                                        is($df, 30,    $test_pattern) if $word eq $WORD[3];
                                        is($df, 31,    $test_pattern) if $word eq $WORD[4];
                                        is($df, 100,   $test_pattern) if $word eq $WORD[5];
                                        is($df, undef, $test_pattern) if $word eq $WORD[6];
                                    }
                                }

                                $webidf->db_close if $driver eq 'TokyoCabinet';
                            };
                        }
                    }
                }
            }
        }
    },
);

sub db_init
{
    my $before_29days = time - (60 * 60 * 24 * 29);
    my $before_30days = time - (60 * 60 * 24 * 30);
    my $before_31days = time - (60 * 60 * 24 * 31);

    my $df = {
        '超古い' => "10000\t0",
        'ナウい' => "1000\t" . time,
        '29日前' => "29\t$before_29days",
        '30日前' => "30\t$before_30days",
        '31日前' => "31\t$before_31days",
        'YahooのAPIでunavailableを引き起こす単語' => "100\t0",
    };

    Storable::nstore($df, $STORABLE_FILE) or die $!;

    if ($IS_TOKYOCABINET_INSTALLED)
    {
        my $hdb = TokyoCabinet::HDB->new;

        $hdb->open($TOKYOCABINET_FILE, $hdb->OWRITER | $hdb->OCREAT)
            or die $hdb->errmsg($hdb->ecode);

        for my $key (keys %{$df})
        {
            $hdb->put( $key, $df->{$key} ) or die $hdb->errmsg($hdb->ecode);
        }

        $hdb->close;
    }
}

done_testing;
