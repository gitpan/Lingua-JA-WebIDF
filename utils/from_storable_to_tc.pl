#!/usr/bin/env perl

use strict;
use warnings;
use Storable qw/lock_retrieve/;
use TokyoCabinet;

my $hdb = TokyoCabinet::HDB->new;

$hdb->tune(50_0000 * 4, undef, undef, undef);

$hdb->open('yahoo_utf8.tch', $hdb->OWRITER | $hdb->OCREAT)
    or die $hdb->errmsg($hdb->ecode);

my $df = lock_retrieve('yahoo_utf8.st');

for my $key (keys %{$df})
{
    my ($df, $time) = split(/\t/, $df->{$key});

    $hdb->put($key, "$df\t$time");
}

$hdb->close;
