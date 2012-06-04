package Lingua::JA::WebIDF::API::Bing;

use strict;
use warnings;

use Carp ();
use URI;
use JSON ();

our $BASE_URL = 'http://api.bing.net/json.aspx';


sub fetch_new_df
{
    my ($word, $furl, $appid) = @_;

    my $df;

    my $url = URI->new($BASE_URL);

    $url->query_form(
        'Appid'     => $appid,
        'query'     => qq|"$word"|,
        'sources'   => 'web',
        'web.count' => 1,
    );

    my (undef, $code, $msg, undef, $body) = $furl->get($url);

    if ($code == 200)
    {
        my $json = JSON::decode_json($body);
        $df = $json->{SearchResponse}{Web}{Total};
    }
    else { Carp::carp("Bing: $code $msg"); }

    return $df;
}

1;
