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

    my $df = $self->{df};

    return $df->{$word};
}

sub save_df
{
    my ($self, $word, $df_and_time) = @_;

    my $df_ref  = $self->{df};
    my $df_file = $self->{df_file};

    $df_ref->{$word} = $df_and_time;

    Storable::lock_nstore($df_ref, $self->{df_file})
        or Carp::croak("Storable: can't store df data to $df_file");
}

1;
