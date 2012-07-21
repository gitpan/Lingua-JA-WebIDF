package Lingua::JA::WebIDF::Driver::TokyoCabinet;

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

    Carp::croak('TokyoCabinet DB file is not opened') unless $self->{db};

    return $self->{db}->get($word); # or Carp::carp( $hdb->errmsg($hdb->ecode) );
}

sub save_df
{
    my ($self, $word, $df_and_time) = @_;

    my $hdb = $self->{db} || Carp::croak('TokyoCabinet DB file is not opened');

    # If a record with the same key exists in the database, it is overwritten.
    $hdb->put($word, $df_and_time) or Carp::carp( 'TokyoCabinet: ' . $hdb->errmsg($hdb->ecode) );
}

sub purge
{
    my ($self, $days) = @_;

    my $hdb = $self->{db} || Carp::croak('TokyoCabinet DB file is not opened');

    $hdb->iterinit;

    while( defined( my $key = $hdb->iternext ) )
    {
        my ($df, $time) = split( /\t/, $hdb->get($key) );

        if (time - $time > 60 * 60 * 24 * $days)
        {
            $hdb->out($key);
        }
    }
}

sub db_open
{
    my ($self, $mode) = @_;

    my $hdb = TokyoCabinet::HDB->new;
    $self->{db} = $hdb;

    if (-e $self->{df_file})
    {
        if ($mode eq 'read')
        {
            $hdb->open($self->{df_file}, $hdb->OREADER)
                or Carp::croak( 'TokyoCabinet' . $hdb->errmsg($hdb->ecode) );
        }
        elsif ($mode eq 'write')
        {
            $hdb->open($self->{df_file}, $hdb->OWRITER)
                or Carp::croak( 'TokyoCabinet: ' . $hdb->errmsg($hdb->ecode) );
        }
        else { Carp::croak('TokyoCabinet: Unknown open mode'); }
    }
    else
    {
        $hdb->tune(50_0000 * 4, undef, undef, undef);

        $hdb->open($self->{df_file}, $hdb->OWRITER | $hdb->OCREAT)
            or Carp::croak( 'TokyoCabinet: ' . $hdb->errmsg($hdb->ecode) );

        $hdb->close or Carp::croak( 'TokyoCabinet: ' . $hdb->errmsg($hdb->ecode) );

        db_open($self, $mode);
    }
}

sub db_close
{
    my $hdb = shift->{db} || Carp::croak('TokyoCabinet DB file is not opened');
    $hdb->close;
}

1;
