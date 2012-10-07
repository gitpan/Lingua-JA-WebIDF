package Lingua::JA::WebIDF;

use 5.008_001;
use strict;
use warnings;

use Carp ();
use Module::Load ();
use Furl::HTTP;

our $VERSION = '0.43';
our @NETWORK_INTERFACE_PLUGIN;


sub _options
{
    return {
        idf_type      => 1,
        documents     => 250_0000_0000,
        df_file       => './df.tch',
        fetch_df      => 0,
        expires_in    => 365, # number of days
        driver        => 'TokyoCabinet',
        api           => 'YahooPremium',
        appid         => undef,
        Furl_HTTP     => undef,
        verbose       => 1,
    };
}

sub new
{
    my $class = shift;
    my %args  = (ref $_[0] eq 'HASH' ? %{$_[0]} : @_);

    my $options = $class->_options;

    for my $key (keys %args)
    {
        if (!exists $options->{$key}) { Carp::croak("Unknown option: $key"); }
        else                          { $options->{$key} = $args{$key};      }
    }

    Module::Load::load(__PACKAGE__ . '::API::'    . $options->{api});
    Module::Load::load(__PACKAGE__ . '::Driver::' . $options->{driver});

    Carp::croak('df_file is not found')                   if (! -e $options->{df_file} && !grep { $options->{driver} eq $_ } @NETWORK_INTERFACE_PLUGIN);
    Carp::croak('appid is required')                      if ($options->{fetch_df} && !defined $options->{appid});
    Carp::croak("Unknown idf type: $options->{idf_type}") unless grep { $options->{idf_type} eq $_ } 1 .. 3;

    if (defined $options->{Furl_HTTP})
    {
        $options->{furl_http} = Furl::HTTP->new($options->{Furl_HTTP});
    }
    else { $options->{furl_http} = Furl::HTTP->new; }

    bless $options, $class;
}

sub idf
{
    my ($self, $word, $is_df) = @_;

    if (!defined $word || !length $word)
    {
        if ($self->{verbose})
        {
            if (!defined $is_df) { Carp::carp("Undefined or empty word has been set"); }
            else                 { Carp::carp("Undefined or empty df has been set");   }
        }

        return;
    }

    my $df;

    # pattern1: idf('hoge')   -> fetch idf of 'hoge'
    # pattern2: idf(86000, 1) -> calc  idf by using 86000
    #
    if (!$is_df) { $df = $self->df($word); }
    else         { $df = $word;            }

    return unless defined $df;

    my $N    = $self->{documents};
    my $type = $self->{idf_type};

    my $idf;

    if ($type == 1)
    {
        $df = 1 if $df == 0; # To avoid dividing by zero
        $idf = log($N / $df);
    }
    elsif ($type == 2) { $idf = log( ($N - $df + 0.5) / ($df + 0.5) ); }
    elsif ($type == 3) { $idf = log( ($N + 0.5) / ($df + 0.5) ); }
    else               { Crap::croak("Unknown idf_type: $type"); }

    return $idf;
}

sub df
{
    my ($self, $word) = @_;

    if (!defined $word || !length $word)
    {
        Carp::carp("Undefined or empty word has been set") if $self->{verbose};
        return;
    }

    $word =~ s/\t+/ /g;

    my $df_and_time = $self->_fetch_df($word);

    my ($df, $time, $elapsed_time);

    if (defined $df_and_time)
    {
        ($df, $time)  = split(/\t/, $df_and_time);
        $elapsed_time = time - $time;
    }

    if ( !defined $df_and_time || $elapsed_time >= (60 * 60 * 24 * $self->{expires_in}) )
    {
        if ($self->{fetch_df})
        {
            my $new_df = $self->_fetch_new_df($word);

            if (defined $new_df)
            {
                $self->_save_df($word, $new_df);
                return $new_df;
            }
        }
    }

    if (!defined $df)
    {
        if ($self->{verbose})
        {
            Carp::carp("DF of '$word' is not found in df file. Please use fetch_df option") unless $self->{fetch_df};
        }

        return;
    }

    return $df;
}

sub db_open
{
    my ($self, $mode) = @_;

    no strict 'refs';
    &{__PACKAGE__ . '::Driver::' . $self->{driver} . '::db_open'}($self, $mode);
}

sub db_close
{
    my $self = shift;

    no strict 'refs';
    &{__PACKAGE__ . '::Driver::' . $self->{driver} . '::db_close'}($self) if exists $self->{db};
}

sub DESTROY
{
    my $self = shift;

    no strict 'refs';
    &{__PACKAGE__ . '::Driver::' . $self->{driver} . '::db_close'}($self) if exists $self->{db};
}

sub purge
{
    my ($self, $days) = @_;

    Carp::croak("purge method was called without arguments") unless defined $days;

    no strict 'refs';
    &{__PACKAGE__ . '::Driver::' . $self->{driver} . '::purge'}($self, $days);
}

sub _fetch_df
{
    my ($self, $word) = @_;

    no strict 'refs';
    &{__PACKAGE__ . '::Driver::' . $self->{driver} . '::fetch_df'}($self, $word);
}

sub _save_df
{
    my ($self, $word, $df) = @_;

    my $df_and_time = $df . "\t" . time;

    no strict 'refs';
    &{__PACKAGE__ . '::Driver::' . $self->{driver} . '::save_df'}($self, $word, $df_and_time);
}

sub _fetch_new_df
{
    my ($self, $word) = @_;

    no strict 'refs';
    &{__PACKAGE__ . '::API::' . $self->{api} . '::fetch_new_df'}($word, $self->{furl_http}, $self->{appid});
}

1;

__END__

=encoding utf8

=head1 NAME

Lingua::JA::WebIDF - WebIDF calculator

=for test_synopsis
my (%config);

=head1 SYNOPSIS

  use Lingua::JA::WebIDF;

  my $webidf = Lingua::JA::WebIDF->new(%config);

  print $webidf->idf("東京"); # low
  print $webidf->idf("スリジャヤワルダナプラコッテ"); # high

=head1 DESCRIPTION

Lingua::JA::WebIDF calculates WebIDF weight.

WebIDF(Inverse Document Frequency) weight represents the rarity of a word on the Web.
The WebIDF weight of a rare word is high.
Conversely, the WebIDF weight of a common word is low.

IDF is based on the intuition that a query term which occurs in
many documents is not a good discriminator and should be given less weight
than one which occurs in few documents.

=head1 METHODS

=head2 new( %config || \%config )

Creates a new Lingua::JA::WebIDF instance.

The following configuration is used if you don't set %config.

  KEY                 DEFAULT VALUE
  -----------         ---------------
  idf_type            1
  api                 'YahooPremium'
  appid               undef
  driver              'TokyoCabinet'
  df_file             './df.tch'
  fetch_df            0
  expires_in          365
  documents           250_0000_0000
  Furl_HTTP           undef
  verbose             1

=over 4

=item idf_type => 1 || 2 || 3

The type1 is the most commonly cited form of IDF.

                   N
  idf(t_i) = log -----  (1)
                  n_i

  N  : the number of documents
  n_i: the number of documents which contain term t_i
  t_i: term


The type2 is a simple version of the RSJ weight.

                   N - n_i + 0.5
  idf(t_i) = log ----------------  (2)
                    n_i + 0.5


The type3 is a modification of (2).

                   N + 0.5
  idf(t_i) = log -----------  (3)
                  n_i + 0.5

=item api => 'Yahoo' || 'YahooPremium'

Uses the specified Web API when fetches WebDF(Document Frequency).

=item driver => 'Storable' || 'TokyoCabinet'

Fetches and saves WebDF with the specified driver.

=item df_file => $path

Saves WebDF to the specified path.

In order to reduce access to Web API,
please download a big df file from L<http://misc.pawafuru.com/webidf/>.

I recommend that you change the file depending on the type of Web API
you specifies because WebDF may be different depending on it.

=item fech_df => 0

Never fetches WebDF from the Web if 0 is specified.

If the WebDF you want to know has already saved, it is used.
If it is not so, returns undef.

=item expires_in => $days

If 365 is specified, WebDF expires in 365 days after fetches it.

=item Furl_HTTP => \%option

Sets the options of L<Furl::HTTP>->new.

If you want to use proxy server, you have to use this option.

=item verbose => 1 || 0

If 1 is specified, shows verbose error messages.

=back

=head2 idf($word)

Calculates the WebIDF weight of $word via df($word) method.

=head2 df($word)

Fetches the WebDF of $word.

If the WebDF of $word has not been saved yet or has expired,
fetches it by using the Web API you specified and saves it.

If the WebDF of $word has expired and fetch_df is 0,
the expired WebDF is used.

=head2 db_open($mode)

Opens the database file which is located in $path.

If you use TokyoCabinet, you have to open the database file
via this method before idf|df|db_close|purge method is called.

$mode is 'read' or 'write'.

=head2 db_close

Closes the database file which is located in $path.

This method is called automatically when the object is destroyed,
so you might not need to use this method explicitly.

=head2 purge($expires_in)

Purges old data in df_file.

If 365 is specified, the data which 365 days elapsed are purged.

=head1 AUTHOR

pawa E<lt>pawapawa@cpan.orgE<gt>

=head1 SEE ALSO

L<Lingua::JA::TFWebIDF>

L<Lingua::JA::WebIDF::Driver::TokyoTyrant>

Yahoo API: L<http://developer.yahoo.co.jp/>

Tokyo Cabinet: L<http://fallabs.com/tokyocabinet/>

S. Robertson, Understanding inverse document frequency:
on theoretical arguments for IDF.
Journal of Documentation 60, 503-520, 2004.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
