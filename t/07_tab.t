use strict;
use warnings;
use utf8;
use Lingua::JA::WebIDF;
use Test::More;
use Test::TCP;
use Storable;
use Test::Requires qw/TokyoCabinet Plack::Loader Plack::Builder Plack::Request/;

binmode Test::More->builder->$_ => ':utf8'
    for qw/output failure_output todo_output/;


my $PSGI_YAHOO        = './t/psgi/Yahoo.psgi';
my $PSGI_404          = './t/psgi/404.psgi';
my $YAHOO_HIT         = 12345;
my $STORABLE_FILE     = './df/idf_t.st';
my $TOKYOCABINET_FILE = './df/idf_t.tch';

unlink $STORABLE_FILE;
unlink $TOKYOCABINET_FILE;

db_init();

test_tcp(
    server => sub {

        my $port = shift;

        my $server = Plack::Loader->auto(
            port => $port,
            host => '127.0.0.1',
        );

        my $app = builder {
            mount '/yahoo/' => Plack::Util::load_psgi($PSGI_YAHOO),
            mount '/404/'   => Plack::Util::load_psgi($PSGI_404),
        };

        $server->run($app);
    },
    client => sub {

        my $port = shift;

        subtest 'TokyoCabinet' => sub {

            my $webidf = Lingua::JA::WebIDF->new(
                api      => 'Yahoo',
                appid    => 'test',
                driver   => 'TokyoCabinet',
                fetch_df => 1,
                df_file  => $TOKYOCABINET_FILE,
            );

            $Lingua::JA::WebIDF::API::Yahoo::BASE_URL = "http://127.0.0.1:$port/yahoo/";

            $webidf->db_open('write');

            my $df = $webidf->df("テス\tト");
            is($df, $YAHOO_HIT, 'fetch');

            $df = $webidf->df('アア' . "\t" x 10 . 'ア' . "\t");
            is($df, $YAHOO_HIT, 'fetch');

            # fetch from df_file
            {
                local $Lingua::JA::WebIDF::API::Yahoo::BASE_URL = "http://127.0.0.1:$port/404/";
                is($webidf->df('テス ト'),  $df, 'tab was removed');
                is($webidf->df('アア ア '), $df, 'tabs was removed');
            }

            $webidf->db_close;
        };

        subtest 'Storable' => sub {

            my $webidf = Lingua::JA::WebIDF->new(
                api      => 'Yahoo',
                appid    => 'test',
                driver   => 'Storable',
                fetch_df => 1,
                df_file  => $STORABLE_FILE,
            );

            $Lingua::JA::WebIDF::API::Yahoo::BASE_URL = "http://127.0.0.1:$port/yahoo/";

            my $df = $webidf->df("テス\tト");
            is($df, $YAHOO_HIT, 'fetch');

            $df = $webidf->df('アア' . "\t" x 10 . 'ア' . "\t");
            is($df, $YAHOO_HIT, 'fetch');

            # fetch from df_file
            {
                local $Lingua::JA::WebIDF::API::Yahoo::BASE_URL = "http://127.0.0.1:$port/404/";
                is($webidf->df('テス ト'),  $df, 'tab was removed');
                is($webidf->df('アア ア '), $df, 'tabs was removed');
            }
        };
    },
);

done_testing;


sub db_init
{
    Storable::nstore({}, $STORABLE_FILE) or die $!;

    my $hdb = TokyoCabinet::HDB->new;

    $hdb->open($TOKYOCABINET_FILE, $hdb->OWRITER | $hdb->OCREAT)
        or die $hdb->errmsg($hdb->ecode);

    $hdb->close;
}
