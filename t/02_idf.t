use strict;
use warnings;
use utf8;
use Lingua::JA::WebIDF;
use Test::More;
use Test::Fatal;
use Test::Warn;
use Test::TCP;
use JSON;
use Encode qw/decode_utf8/;
use Test::Requires qw/Plack::Builder Plack::Request Plack::Handler::Standalone/;

binmode Test::More->builder->$_ => ':utf8'
    for qw/output failure_output todo_output/;


unlink 'df.st';
unlink 'df.tch';

my @patterns = (
    {
        api       => 'Bong',
        driver    => 'Storable',
        df_file   => 'df.st',
        fetch_df  => 1,
        exception => 'Unknown api',
    },
    {
        api       => 'Bing',
        driver    => 'Strable',
        df_file   => 'df.st',
        fetch_df  => 0,
        exception => 'Unknown driver',
    },
    {
        api      => 'Bing',
        driver   => 'Storable',
        df_file  => 'df.st',
        fetch_df => 0,
    },
    {
        api      => 'Yahoo',
        driver   => 'Storable',,
        df_file  => 'df.st',
        fetch_df => 0,
    },
    {
        api      => 'YahooPremium',
        driver   => 'Storable',
        df_file  => 'df.st',
        fetch_df => 0,
    },
    {
        api      => 'Bing',
        driver   => 'TokyoCabinet',
        df_file  => 'df.tch',
        fetch_df => 0,
    },
    {
        api      => 'Yahoo',
        driver   => 'TokyoCabinet',
        df_file  => 'df.tch',
        fetch_df => 0,
    },
    {
        api      => 'YahooPremium',
        driver   => 'TokyoCabinet',
        df_file  => 'df.tch',
        fetch_df => 0,
    },
    {
        api      => 'Bing',
        driver   => 'Storable',
        df_file  => 'df.st',
        fetch_df => 1,
    },
    {
        api      => 'Yahoo',
        driver   => 'Storable',
        df_file  => 'df.st',
        fetch_df => 1,
    },
    {
        api      => 'YahooPremium',
        driver   => 'Storable',
        df_file  => 'df.st',
        fetch_df => 1,
    },
    {
        api      => 'Bing',
        driver   => 'TokyoCabinet',
        df_file  => 'df.tch',
        fetch_df => 1,
    },
    {
        api      => 'Yahoo',
        driver   => 'TokyoCabinet',
        df_file  => 'df.tch',
        fetch_df => 1,
    },
    {
        api      => 'YahooPremium',
        driver   => 'TokyoCabinet',
        df_file  => 'df.tch',
        fetch_df => 1,
    },
    {
        api      => 'Bing',
        df_file  => 'df.st',
        fetch_df => 1,
        query    => 'コジョピー', # no hit
    },
    {
        api      => 'Bing',
        df_file  => 'df.st',
        fetch_df => 1,
        query    => '500',
        warning  => 'Bing: 500 Internal Server Error',
    },
    {
        api      => 'Yahoo',
        df_file  => 'df.st',
        fetch_df => 1,
        query    => '500',
        warning  => 'Yahoo: 500 Internal Server Error',
    },
    {
        api      => 'Yahoo',
        df_file  => 'df.st',
        fetch_df => 1,
        query    => 'unavailable',
        warning  => 'Yahoo: Service unavailable.Too many users',
    },
    {
        api      => 'Yahoo',
        df_file  => 'df.st',
        fetch_df => 1,
        query    => 'コジョピー', # no hit
    },
    {
        api      => 'YahooPremium',
        df_file  => 'df.st',
        fetch_df => 1,
        query    => '500',
        warning  => 'YahooPremium: 500 Internal Server Error',
    },
    {
        api      => 'YahooPremium',
        df_file  => 'df.st',
        fetch_df => 1,
        query    => 'unavailable',
        warning  => 'YahooPremium: Service unavailable.Too many users',
    },
    {
        api      => 'YahooPremium',
        df_file  => 'df.st',
        fetch_df => 1,
        query    => 'コジョピー', # no hit
    },
    {
        api       => 'Bing',
        driver    => 'Storable',
        df_file   => 'df.st',
        fetch_df  => 1,
        test_type => 'fetch df by Storable',
    },
    {
        api       => 'Yahoo',
        driver    => 'TokyoCabinet',
        df_file   => 'df.tch',
        fetch_df  => 1,
        test_type => 'fetch df by TokyoCabinet',
    },
    {
        idf_type  => 1,
        api       => 'Yahoo',
        driver    => 'Storable',
        df_file   => 'df.st',
        fetch_df  => 1,
    },
    {
        idf_type  => 2,
        api       => 'Yahoo',
        driver    => 'Storable',
        df_file   => 'df.st',
        fetch_df  => 1,
    },
    {
        idf_type  => 3,
        api       => 'Yahoo',
        driver    => 'Storable',
        df_file   => 'df.st',
        fetch_df  => 1,
    },
);

test_tcp(
    client => sub {

        my $port = shift;

        my $documents  = 300_0000_0000;

        for my $pattern (@patterns)
        {
            my %config = (
                api        => $pattern->{api},
                appid      => 'test',
                fetch_df   => $pattern->{fetch_df},
                documents  => $documents,
            );

            $config{idf_type} = $pattern->{idf_type} if exists $pattern->{idf_type};
            $config{driver}   = $pattern->{driver}   if exists $pattern->{driver};
            $config{df_file}  = $pattern->{df_file}  if exists $pattern->{df_file};

            subtest 'idf' => sub {

                if (exists $pattern->{driver} && $pattern->{driver} eq 'TokyoCabinet')
                {
                    eval { require TokyoCabinet; };

                    plan 'skip_all' => 'TokyoCabinet is not installed' if $@;
                }

                my $webidf;

                if (exists $pattern->{exception})
                {
                    my $exception = exception { $webidf = Lingua::JA::WebIDF->new(%config); };
                    like($exception, qr/$pattern->{exception}/, 'exception');
                }
                else
                {
                    $webidf = Lingua::JA::WebIDF->new(\%config);
                    $webidf->db_open('write') if exists $config{driver} && $config{driver} eq 'TokyoCabinet';

                    local $Lingua::JA::WebIDF::API::Bing::BASE_URL         = "http://127.0.0.1:$port/bing/"          if $pattern->{api} eq 'Bing';
                    local $Lingua::JA::WebIDF::API::Yahoo::BASE_URL        = "http://127.0.0.1:$port/yahoo/"         if $pattern->{api} eq 'Yahoo';
                    local $Lingua::JA::WebIDF::API::YahooPremium::BASE_URL = "http://127.0.0.1:$port/yahoo_premium/" if $pattern->{api} eq 'YahooPremium';

                    my $query  = exists $pattern->{query} ? $pattern->{query} : 'オコジョ';

                    my ($df, $idf);

                    if (exists $pattern->{test_type})
                    {
                        $Lingua::JA::WebIDF::API::Bing::BASE_URL         = "http://127.0.0.1:$port/404/" if $pattern->{api} eq 'Bing';
                        $Lingua::JA::WebIDF::API::Yahoo::BASE_URL        = "http://127.0.0.1:$port/404/" if $pattern->{api} eq 'Yahoo';
                        $Lingua::JA::WebIDF::API::YahooPremium::BASE_URL = "http://127.0.0.1:$port/404/" if $pattern->{api} eq 'YahooPremium';
                    }

                    warning_is { $df  = $webidf->df($query)  } $pattern->{warning}, 'df warning';
                    warning_is { $idf = $webidf->idf($query) } $pattern->{warning}, 'idf warning';

                    if ($pattern->{fetch_df})
                    {
                        if ($pattern->{warning} && !exists $pattern->{test_type})
                        {
                            is($df, undef, 'warning');
                        }
                        else { isnt($df, undef, 'fetch_df'); }
                    }
                    else { is($df, undef, 'dont fetch'); }

                    if (defined $df && defined $idf)
                    {
                        if (!exists $pattern->{idf_type} || $pattern->{idf_type} == 1)
                        {
                            $df = 1 if $df == 0; # To avoid dividing by zero.

                            is( $idf, log($documents / $df), 'idf_type1' );
                        }
                        elsif ($pattern->{idf_type} == 2)
                        {
                            is( $idf, log( ($documents - $df + 0.5) / ($df + 0.5) ), 'idf_type2' );
                        }
                        elsif ($pattern->{idf_type} == 3)
                        {
                            is( $idf, log( ($documents + 0.5) / ($df + 0.5) ), 'idf_type3' );
                        }
                    }
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
            mount '/404/'           => \&not_found;
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
    elsif ($query eq '500')
    {
        return [ 500, [ 'Content-Type' => 'text/plain' ], [ '500 Internal Server Error' ] ];
    }
    elsif ($query eq 'unavailable')
    {
        return [
            200,
            [ 'Content-Type' => 'application/xml' ],
            [
                qq|
                    <?xml version='1.0' encoding='utf-8'?>
                    <Error>
                        <Message>Service unavailable.Too many users</Message>
                    </Error>
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
    elsif ($query eq '500')
    {
        return [ 500, [ 'Content-Type' => 'text/plain' ], [ '500 Internal Server Error' ] ];
    }
    elsif ($query eq 'unavailable')
    {
        return [
            200,
            [ 'Content-Type' => 'application/xml' ],
            [
                qq|
                    <?xml version='1.0' encoding='utf-8'?>
                    <Error>
                        <Message>Service unavailable.Too many users</Message>
                    </Error>
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

sub not_found
{
    my $env = shift;
    my $req = Plack::Request->new($env);

    return [ 404, [ 'Content-Type' => 'text/plain' ], [ '404 Not Found' ] ];
}
