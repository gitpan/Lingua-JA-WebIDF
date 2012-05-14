package Lingua::JA::WebIDF::API::Bing;

use 5.008_001;
use strict;
use warnings;

use Carp ();
use URI;
use JSON ();

sub fetch_new_df
{
    my ($self, $word, $base_url) = @_;

    my $api  = $self->{api};
    my $furl = $self->{furl_http};

    my $df;

    my $url = URI->new($base_url);

    $url->query_form(
        'Appid'     => $self->{appid},
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
    else { Carp::carp("$api: $code $msg"); }

    return $df;
}

1;
