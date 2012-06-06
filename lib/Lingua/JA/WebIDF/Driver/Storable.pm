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

1;
