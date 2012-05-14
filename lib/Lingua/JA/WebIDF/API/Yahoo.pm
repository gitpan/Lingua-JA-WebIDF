package Lingua::JA::WebIDF::API::Yahoo;

use 5.008_001;
use strict;
use warnings;

use Carp ();
use URI;

sub fetch_new_df
{
    my ($self, $word, $base_url) = @_;

    my $api  = $self->{api};
    my $furl = $self->{furl_http};

    my $df;

    my $url = URI->new($base_url);

    $url->query_form(
        'appid'    => $self->{appid},
        'query'    => qq|"$word"|,
        'type'     => 'all', # query type
        'results'  => 1,
        'format'   => 'any', # file format
        'adult_ok' => 1,
    );

    my (undef, $code, $msg, undef, $body) = $furl->get($url);

    if ($code == 200)
    {
        my $xml = $furl->get($url);

        if    ($xml =~ /totalResultsAvailable="([0-9]+)"/) { $df = $1; }
        elsif ($xml =~ m|<Message>(.*?)</Message>|)        { Carp::carp("$api: $1"); }
        else                                               { Carp::carp("$api: unknown response"); }
    }
    else { Carp::carp("$api: $code $msg"); }

    return $df;
}

1;
