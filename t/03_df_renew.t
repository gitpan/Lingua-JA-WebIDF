use strict;
use warnings;
use utf8;
use Lingua::JA::WebIDF;
use Test::More;
use Test::Warn;
use Test::TCP;
use JSON;
use Storable;
use Encode qw/decode_utf8/;
use Test::Requires qw/Plack::Builder Plack::Request Plack::Handler::Standalone TokyoCabinet/;

unlink 'df.st';
unlink 'df.tch';

my $df = {
    'オコジョ' => "10000\t0",
    'ちょろり' => 1000 . "\t" . time,
    'タッチン' => "100\t1",
    '500'      => "10\t0",
};

Storable::nstore($df, 'df.st');

my $hdb = TokyoCabinet::HDB->new;

$hdb->open('df.tch', $hdb->OWRITER | $hdb->OCREAT)
    or die( $hdb->errmsg($hdb->ecode) );

$hdb->put('オコジョ', "10000\t0")         or warn( $hdb->errmsg($hdb->ecode) );
$hdb->put('ちょろり', 1000 . "\t" . time) or warn( $hdb->errmsg($hdb->ecode) );

my $time = time - (60 * 60 * 24 * 30);
$hdb->put( 'タッチン', "100\t$time") or warn( $hdb->errmsg($hdb->ecode) );

$hdb->close or die( $hdb->errmsg($hdb->ecode) );

my @patterns = (
    {
        api      => 'Bing',
        driver   => 'Storable',
        df_file  => 'df.st',
        fetch_df => 1,
        query    => 'ちょろり',
        hit      => 1000,
    },
    {
        api      => 'Yahoo',
        driver   => 'Storable',
        df_file  => 'df.st',
        fetch_df => 0,
        hit      => 10000,
    },
    {
        api      => 'YahooPremium',
        driver   => 'Storable',
        df_file  => 'df.st',
        fetch_df => 1,
        hit      => 2270000,
    },
    {
        api      => 'Bing',
        driver   => 'TokyoCabinet',
        df_file  => 'df.tch',
        fetch_df => 0,
        query    => 'ちょろり',
        hit      => 1000,
    },
    {
        api      => 'Yahoo',
        driver   => 'TokyoCabinet',
        df_file  => 'df.tch',
        fetch_df => 1,
        hit      => 2230000,
    },
    {
        api      => 'YahooPremium',
        driver   => 'TokyoCabinet',
        df_file  => 'df.tch',
        fetch_df => 1,
        hit      => 2230000,
    },
    {
        api      => 'Bing',
        driver   => 'Storable',
        df_file  => 'df.st',
        fetch_df => 0,
        query    => 'タッチン',
        hit      => 100,
    },
    {
        api      => 'Bing',
        driver   => 'Storable',
        df_file  => 'df.st',
        fetch_df => 1,
        query    => 'タッチン',
        hit      => 0,
    },
    {
        api      => 'Bing',
        driver   => 'TokyoCabinet',
        df_file  => 'df.tch',
        fetch_df => 1,
        query    => 'タッチン',
        hit      => 100,
    },
    {
        api        => 'Bing',
        driver     => 'TokyoCabinet',
        df_file    => 'df.tch',
        fetch_df   => 1,
        expires_in => 31,
        query      => 'タッチン',
        hit        => 100,
    },
    {
        api        => 'Bing',
        driver     => 'TokyoCabinet',
        df_file    => 'df.tch',
        fetch_df   => 1,
        expires_in => 29,
        query      => 'タッチン',
        hit        => 0,
    },
    {
        api        => 'Bing',
        driver     => 'TokyoCabinet',
        df_file    => 'df.tch',
        fetch_df   => 0,
        query      => 'タッチン',
        hit        => 0,
    },
    {
        api      => 'Bing',
        driver   => 'Storable',
        df_file  => 'df.st',
        fetch_df => 1,
        query    => '500',
        hit      => 10,
        warning  => 'Bing: 500 Internal Server Error',
    },
);

test_tcp(
    client => sub {

        my $port = shift;

        for my $pattern (@patterns)
        {
            my %config = (
                api        => $pattern->{api},
                appid      => 'test',
                fetch_df   => $pattern->{fetch_df},
            );

            $config{driver}     = $pattern->{driver}     if exists $pattern->{driver};
            $config{df_file}    = $pattern->{df_file}    if exists $pattern->{df_file};
            $config{expires_in} = $pattern->{expires_in} if exists $pattern->{expires_in};

            my $webidf = Lingua::JA::WebIDF->new(%config);

            {
                no warnings 'once';
                $Lingua::JA::WebIDF::API::Bing::BASE_URL         = "http://127.0.0.1:$port/bing/";
                $Lingua::JA::WebIDF::API::Yahoo::BASE_URL        = "http://127.0.0.1:$port/yahoo/";
                $Lingua::JA::WebIDF::API::YahooPremium::BASE_URL = "http://127.0.0.1:$port/yahoo_premium/";
            }

            my $query = exists $pattern->{query} ? $pattern->{query} : 'オコジョ';

            my $df;

            if (exists $pattern->{warning})
            {
                warning_is { $df = $webidf->df($query) } $pattern->{warning}, 'df warning';
            }
            else { $df = $webidf->df($query); }

            is($df, $pattern->{hit}, 'df');
        }

        unlink 'df.st';
        unlink 'df.tch';
    },
    server => sub {
        my $port = shift;

        my $app = builder {
            mount '/bing/'          => \&bing;
            mount '/yahoo/'         => \&yahoo;
            mount '/yahoo_premium/' => \&yahoo_premium;
        };

        my $server = Plack::Handler::Standalone->new(
            host => '127.0.0.1',
            port => $port,
        )->run($app);
    },
);

done_testing;


sub bing
{
    my $env = shift;
    my $req = Plack::Request->new($env);

    my $query = decode_utf8( $req->param('query') );
    $query =~ s/"//g;

    if ($query eq 'オコジョ')
    {
        return [
            200,
            [ 'Content-Type' => 'application/json' ],
            [
                JSON::encode_json({
                    SearchResponse => {
                        Version => qq/\"2.2\"/,
                        Query   => { SearchTerms => qq/\"$query\"/ },
                        Web => {
                            Total   => 283000000,
                            Offset  => 0,
                            Results => {},
                        }
                    }
                })
            ],
        ];
    }
    elsif ($query eq '500')
    {
        return [ 500, [ 'Content-Type' => 'text/plain' ], [ '500 Internal Server Error' ] ];
    }
    else
    {
        return [
            200,
            [ 'Content-Type' => 'application/json' ],
            [
                JSON::encode_json({
                    SearchResponse => {
                        Version => qq/\"2.2\"/,
                        Query   => { SearchTerms => qq/\"$query\"/ },
                        Web => {
                            Total   => 0,
                            Offset  => 0,
                        }
                    }
                })
            ],
        ];
    }
}

sub yahoo
{
    my $env = shift;
    my $req = Plack::Request->new($env);

    my $query = decode_utf8( $req->param('query') );
    $query =~ s/"//g;

    if ($query eq 'オコジョ')
    {
        return [
            200,
            [ 'Content-Type' => 'application/xml' ],
            [
                qq|
                    <?xml version="1.0" encoding="UTF-8"?>
                    <ResultSet firstResultPosition="1" totalResultsAvailable="2230000" totalResultsReturned="1" xmlns="urn:yahoo:jp:srch" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:yahoo:jp:srch http://search.yahooapis.jp/WebSearchService/V2/WebSearchResponse.xsd">
                        <Result>
                            <Title></Title>
                            <Summary></Summary>
                            <Url></Url>
                            <ClickUrl></ClickUrl>
                            <ModificationDate />
                            <Cache></Cache>
                        </Result>
                    </ResultSet>
                |
            ],
        ];
    }
    else
    {
        return [
            200,
            [ 'Content-Type' => 'aaplication/xml' ],
            [
                qq|
                    <?xml version='1.0' encoding='utf-8'?>
                    <ResultSet firstResultPosition="1" totalResultsAvailable="0" totalResultsReturned="0" xsi:schemaLocation="urn:yahoo:jp:srch http://search.yahooapis.jp/PremiumWebSearchService/V1/WebSearchResponse.xsd"/>
                |
            ],
        ];
    }
}

sub yahoo_premium
{
    my $env = shift;
    my $req = Plack::Request->new($env);

    my $query = decode_utf8( $req->param('query') );
    $query =~ s/"//g;

    if ($query eq 'オコジョ')
    {
        return [
            200,
            [ 'Content-Type' => 'application/xml' ],
            [
                qw|
                    <?xml version="1.0" encoding="UTF-8"?>
                    <ResultSet firstResultPosition="1" totalResultsAvailable="2270000" totalResultsReturned="1" xmlns="urn:yahoo:jp:srch" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:yahoo:jp:srch http://search.yahooapis.jp/PremiumWebSearchService/V1/WebSearchResponse.xsd">
                        <Result>
                            <Title></Title>
                            <Summary></Summary>
                            <Url></Url>
                            <ClickUrl></ClickUrl>
                            <ModificationDate />
                            <Cache></Cache>
                        </Result>
                    </ResultSet>
                |
            ],
        ];
    }
    else
    {
        return [
            200,
            [ 'Content-Type' => 'aaplication/xml' ],
            [
                qq|
                    <?xml version='1.0' encoding='utf-8'?>
                    <ResultSet firstResultPosition="1" totalResultsAvailable="0" totalResultsReturned="0" xmlns="urn:yahoo:jp:srch" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:yahoo:jp:srch http://search.yahooapis.jp/PremiumWebSearchService/V1/WebSearchResponse.xsd" />
                |
            ],
        ];
    }
}
