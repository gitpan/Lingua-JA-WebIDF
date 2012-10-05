use strict;
use warnings;
use Lingua::JA::WebIDF;
use Test::More;
use Test::Requires qw/TokyoCabinet/;


binmode Test::More->builder->$_ => ':utf8'
    for qw/output failure_output todo_output/;


my $df_file = './df/utf8.tch';
my $word    = '川';
my $num_of_documents = 250_0000_0000;

my %config = (
    idf_type => 1,
    df_file  => $df_file,
    fetch_df => 0,
);

my $webidf = Lingua::JA::WebIDF->new(%config);
$webidf->db_open;
my $df = $webidf->df($word);
is( $webidf->idf($word), log($num_of_documents / $df) );
$webidf->db_close;

$config{idf_type} = 2;
$webidf = Lingua::JA::WebIDF->new(%config);
$webidf->db_open;
$df = $webidf->df($word);
is( $webidf->idf($word), log( ($num_of_documents - $df + 0.5) / ($df + 0.5) ) );
$webidf->db_close;

$config{idf_type} = 3;
$webidf = Lingua::JA::WebIDF->new(%config);
$webidf->db_open;
$df = $webidf->df($word);
is( $webidf->idf($word), log( ($num_of_documents + 0.5) / ($df + 0.5) ) );
$webidf->db_close;

done_testing;
