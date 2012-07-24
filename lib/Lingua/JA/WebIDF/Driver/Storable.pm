package Lingua::JA::WebIDF::Driver::Storable;

use strict;
use warnings;

use Carp ();
use Storable ();


sub fetch_df
{
    my ($self, $word) = @_;

    if (!exists $self->{df} && -s $self->{df_file})
    {
        $self->{df} = Storable::lock_retrieve($self->{df_file});
    }

    return $self->{df}->{$word};
}

sub save_df
{
    my ($self, $word, $df_and_time) = @_;

    $self->{df}->{$word} = $df_and_time;

    Storable::lock_nstore($self->{df}, $self->{df_file})
        or Carp::croak("Storable: can't store df data to $self->{df_file}");
}

sub purge
{
    my ($self, $days) = @_;

    my $df_of = Storable::lock_retrieve($self->{df_file});

    for my $key (keys %{$df_of})
    {
        my ($df, $time) = split(/\t/, $df_of->{$key});

        if (time - $time > 60 * 60 * 24 * $days)
        {
            delete $df_of->{$key};
        }
    }

    Storable::lock_nstore($df_of, $self->{df_file})
        or Carp::croak("Storable: can't store df data to $self->{df_file}");
}

sub db_open  {}
sub db_close {}

1;
