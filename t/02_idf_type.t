use strict;
use warnings;
use Lingua::JA::WebIDF;
use Test::More;


binmode Test::More->builder->$_ => ':utf8'
    for qw/output failure_output todo_output/;


my $IS_TOKYOCABINET_INSTALLED = eval 'use TokyoCabinet; 1;';
my @df_file_list = qw|./df/utf8.st ./df/utf8.tch|;
my $word = '川';
my $num_of_documents = 250_0000_0000;

for my $df_file (@df_file_list)
{
    subtest $df_file => sub {

        plan skip_all => "TokyoCabinet is not installed."
            if (!$IS_TOKYOCABINET_INSTALLED && $df_file =~ /\.tch$/);

        my $driver = ($df_file =~ /\.tch$/) ? 'TokyoCabinet' : 'Storable';

        my %config = (
            driver   => $driver,
            idf_type => 1,
            df_file  => $df_file,
            fetch_df => 0,
            verbose  => 0,
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
    };
}

done_testing;
