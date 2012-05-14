use strict;
use warnings;
use utf8;
use Lingua::JA::WebIDF;
use Test::More;
use Test::Warn;
use Test::TCP;
use JSON;
use Test::Requires qw/Plack::Builder Plack::Request Plack::Handler::Standalone/;


unlink 'df.st';
unlink 'df.tch';

my @patterns = (
    {
        api       => 'Bing',
        driver    => 'Storable',
        df_file   => 'df.st',
        fetch_df  => 1,
        Furl_HTTP => { timeout => 2 },
    },
    {
        api       => 'Yahoo',
        driver    => 'Storable',
        df_file   => 'df.st',
        fetch_df  => 1,
        Furl_HTTP => { timeout => 2 },
    },
    {
        api       => 'YahooPremium',
        driver    => 'TokyoCabinet',
        df_file   => 'df.tch',
        fetch_df  => 1,
        Furl_HTTP => { timeout => 2 },
    },
    {
        api        => 'Bing',
        driver     => 'Storable',
        df_file    => 'df.st',
        fetch_df   => 1,
        query      => 'ちょろり',
        Furl_HTTP  => { timeout => 20 },
        no_warning => 1,
    },
);

test_tcp(
    client => sub {
        my $port = shift;

        local %Lingua::JA::WebIDF::API_URL = (
            Bing         => "http://127.0.0.1:$port/bing/",
            Yahoo        => "http://127.0.0.1:$port/yahoo/",
            YahooPremium => "http://127.0.0.1:$port/yahoo_premium/",
        );

        my $default_df = 1_0000;

        for my $pattern (@patterns)
        {
            my %config = (
                api        => $pattern->{api},
                driver     => $pattern->{driver},
                df_file    => $pattern->{df_file},
                appid      => 'test',
                default_df => $default_df,
                fetch_df   => $pattern->{fetch_df},
                Furl_HTTP  => $pattern->{Furl_HTTP},
            );

            subtest 'timeout' => sub {

                if ($pattern->{driver} eq 'TokyoCabinet')
                {
                    eval { require TokyoCabinet; };

                    plan 'skip_all' => 'TokyoCabinet is not installed' if $@;
                }

                my $webidf = Lingua::JA::WebIDF->new(%config);

                my $query = exists $pattern->{query} ? $pattern->{query} : 'オコジョ';

                my $df;

                if (!exists $pattern->{no_warning})
                {
                    warning_like { $df = $webidf->df($query) } qr/timeout/, 'timeout';
                    is($df, $default_df, 'default df');
                }
                else
                {
                    $df = $webidf->df($query);
                    isnt($df, $default_df, 'df');
                }
            };
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

    sleep(5);

    return [
        200,
        [ 'Content-Type' => 'application/json' ],
        [
            JSON::encode_json({
                SearchResponse => {
                    Version => qq/\"2.2\"/,
                    Query   => { SearchTerms => qq/\"オコジョ\"/ },
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

sub yahoo
{
    my $env = shift;
    my $req = Plack::Request->new($env);

    sleep(5);

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

sub yahoo_premium
{
    my $env = shift;
    my $req = Plack::Request->new($env);

    sleep(5);

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
