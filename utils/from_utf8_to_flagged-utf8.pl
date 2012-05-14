#!/usr/bin/env perl

use strict;
use warnings;
use Storable qw/lock_retrieve lock_nstore/;
use Encode qw/decode_utf8/;

my $df = lock_retrieve('yahoo_utf8.st');

my $new_df = ();

for my $key (keys %{$df})
{
    my ($df, $time) = split(/\t/, $df->{$key});

    $new_df->{ decode_utf8($key) } = "$df\t$time";
}

lock_nstore($new_df, 'yahoo_flagged_utf8.st');
