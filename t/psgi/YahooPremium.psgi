use utf8;
use Encode qw/decode_utf8/;

open(my $fh, '<','./t/ans/YahooPremium.xml') or die $!;
my $ans = do { local $/; <$fh> };
close($fh);

my $app = sub {

    my $env = shift;
    my $req = Plack::Request->new($env);

    my $query = decode_utf8( $req->param('query') );
    $query =~ s/"//g;

    if ($query eq 'NOHIT')
    {
        return [
            200,
            [ 'Content-Type' => 'application/xml' ],
            [
                <<"XML"
<ResultSet firstResultPosition="1" totalResultsAvailable="0" totalResultsReturned="0" xsi:schemaLocation="urn:yahoo:jp:srch http://search.yahooapis.jp/PremiumWebSearchService/V1/WebSearchResponse.xsd"/>
XML
            ],
        ];
    }
    elsif ($query eq 'YahooのAPIでunavailableを引き起こす単語')
    {
        return [
            200,
            [ 'Content-Type' => 'application/xml' ],
            [
                <<"XML"
<?xml version='1.0' encoding='utf-8'?>
<Error>
    <Message>Service unavailable.Too many users</Message>
</Error>
XML
            ],
        ];
    }
    else
    {
        return [
            200,
            [ 'Content-Type' => 'application/xml' ],
            [ $ans ],
        ];
    }
};
