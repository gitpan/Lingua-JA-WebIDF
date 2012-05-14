package Lingua::JA::WebIDF::Driver::TokyoCabinet;

use 5.008_001;
use strict;
use warnings;

use Carp ();
use TokyoCabinet;

# TokyoCabinet
#   OWRITER -> exclusive lock
#   OREADER -> shared lock

sub fetch_df
{
    my ($self, $word) = @_;

    my $hdb = TokyoCabinet::HDB->new;

    if (-e $self->{df_file})
    {
        $hdb->open($self->{df_file}, $hdb->OREADER)
            or Carp::croak( 'TokyoCabinet: ' . $hdb->errmsg($hdb->ecode) );
    }
    else
    {
        $hdb->tune(50_0000 * 4, undef, undef, undef);

        $hdb->open($self->{df_file}, $hdb->OWRITER | $hdb->OCREAT)
            or Carp::croak( 'TokyoCabinet: ' . $hdb->errmsg($hdb->ecode) );
    }

    my $df = $hdb->get($word); # or Carp::carp( $hdb->errmsg($hdb->ecode) );

    $hdb->close or Carp::croak( 'TokyoCabinet: ' . $hdb->errmsg($hdb->ecode) );

    return $df;
}

sub save_df
{
    my ($self, $word, $df_and_time) = @_;

    my $hdb = TokyoCabinet::HDB->new;

    $hdb->open($self->{df_file}, $hdb->OWRITER | $hdb->OCREAT)
        or Carp::croak( 'TokyoCabinet: ' . $hdb->errmsg($hdb->ecode) );

    # If a record with the same key exists in the database, it is overwritten.
    $hdb->put($word, $df_and_time) or Carp::carp( 'TokyoCabinet: ' . $hdb->errmsg($hdb->ecode) );

    $hdb->close or Carp::croak( 'TokyoCabinet: ' . $hdb->errmsg($hdb->ecode) );
}

1;
