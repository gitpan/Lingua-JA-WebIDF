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
my $PRE_PUTTED_WORD = 'df_fileにあらかじめ入っている単語';
my $PRE_PUTTED_DF   = 555;
my @WORD            = ($PRE_PUTTED_WORD, qw/正常にフェッチされる単語 YahooのAPIでunavailableを引き起こす単語 NOHIT/);

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

                                make_new_df_file();

                                $Lingua::JA::WebIDF::API::Yahoo::BASE_URL        = "http://127.0.0.1:$port/yahoo/";
                                $Lingua::JA::WebIDF::API::YahooPremium::BASE_URL = "http://127.0.0.1:$port/yahoo_premium/";

                                my $df_file = $DF_FILE_OF{$driver};

                                my %config = (
                                    api      => $api,
                                    appid    => 'test',
                                    df_file  => $df_file,
                                    driver   => $driver,
                                    fetch_df => $fetch_df,
                                );

                                my $webidf = Lingua::JA::WebIDF->new(%config);

                                $webidf->db_open('write') if $driver eq 'TokyoCabinet';

                                if ($status_code ne $STATUS_OK)
                                {
                                    local $Lingua::JA::WebIDF::API::Yahoo::BASE_URL        = "http://127.0.0.1:$port/$status_code/";
                                    local $Lingua::JA::WebIDF::API::YahooPremium::BASE_URL = "http://127.0.0.1:$port/$status_code/";

                                    if ($fetch_df)
                                    {
                                        my $df;

                                        if ($word eq $PRE_PUTTED_WORD)
                                        {
                                            warning_is { $df = $webidf->df($word); }
                                            '', $test_pattern;

                                            is($df, $PRE_PUTTED_DF, $test_pattern);
                                        }
                                        else
                                        {
                                            warning_like { $df = $webidf->df($word); }
                                            qr/^$api: $status_code/, "$status_code error";

                                            is($df, undef, $test_pattern);
                                        }
                                    }
                                    else # fetch_df: false
                                    {
                                        my $df;

                                        if ($word eq $PRE_PUTTED_WORD)
                                        {
                                            warning_is { $df = $webidf->df($word); }
                                            '', $test_pattern;

                                            is($df, $PRE_PUTTED_DF, $test_pattern);
                                        }
                                        else
                                        {
                                            warning_like { $df = $webidf->df($word); }
                                            qr/use fetch_df/, $test_pattern;

                                            is($df, undef, $test_pattern);
                                        }
                                    }
                                }
                                else # 200 ok
                                {
                                    if ($fetch_df)
                                    {
                                        my $df;

                                        if ($word eq $WORD[3])
                                        {
                                            warning_is { $df = $webidf->df($word); }
                                            '', $test_pattern;

                                            is($df, 0, $test_pattern);
                                        }
                                        elsif ($word eq $WORD[2])
                                        {
                                            warning_like { $df = $webidf->df($word); }
                                            qr/unavailable/, $test_pattern;

                                            is($df, undef, $test_pattern);
                                        }
                                        elsif ($word eq $WORD[1])
                                        {
                                            my $hit;

                                            warning_is { $df = $webidf->df($word); }
                                            '', $test_pattern;

                                            if ($api eq 'Yahoo') { $hit = $YAHOO_HIT;         }
                                            else                 { $hit = $YAHOO_PREMIUM_HIT; }

                                            is( $df, $hit, $test_pattern );
                                        }
                                        else
                                        {
                                            warning_is { $df = $webidf->df($word); }
                                            '', $test_pattern;

                                            is( $df, $PRE_PUTTED_DF, $test_pattern );
                                        }
                                    }
                                    else # fetch_df: false
                                    {
                                        my $df;

                                        if ($word eq $WORD[3])
                                        {
                                            warning_like { $df = $webidf->df($word); }
                                            qr/use fetch_df/, $test_pattern;

                                            is($df, undef, $test_pattern);
                                        }
                                        elsif ($word eq $WORD[2])
                                        {
                                            warning_like { $df = $webidf->df($word); }
                                            qr/use fetch_df/, $test_pattern;

                                            is($df, undef, $test_pattern);
                                        }
                                        elsif ($word eq $WORD[1])
                                        {
                                            warning_like { $df = $webidf->df($word); }
                                            qr/use fetch_df/, $test_pattern;

                                            is( $df, undef, $test_pattern );
                                        }
                                        else
                                        {
                                            warning_is { $df = $webidf->df($word); }
                                            '', $test_pattern;

                                            is( $df, $PRE_PUTTED_DF, $test_pattern );
                                        }
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

sub make_new_df_file
{
    my $storable_df = {
        $PRE_PUTTED_WORD => "$PRE_PUTTED_DF\t" . time,
    };

    Storable::nstore($storable_df, $STORABLE_FILE) or die $!;

    if ($IS_TOKYOCABINET_INSTALLED)
    {
        my $hdb = TokyoCabinet::HDB->new;

        $hdb->open($TOKYOCABINET_FILE, $hdb->OWRITER | $hdb->OCREAT)
            or die $hdb->errmsg($hdb->ecode);

        $hdb->put($PRE_PUTTED_WORD, "$PRE_PUTTED_DF\t" . time)
            or die $hdb->errmsg($hdb->ecode);

        $hdb->close;
    }
}

done_testing;
