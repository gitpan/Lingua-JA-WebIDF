use strict;
use warnings;
use Lingua::JA::WebIDF;
use Test::More;
use Test::Warn;
use Test::Fatal;


my $IS_TOKYOCABINET_INSTALLED = eval "use TokyoCabinet; 1";
my @DF_FILE_LIST = qw|./df/utf8.st ./df/utf8.tch|;

can_ok('Lingua::JA::WebIDF', qw/new idf df db_open db_close purge/);

subtest 'new method' => sub {

    for my $df_file (@DF_FILE_LIST)
    {
        subtest $df_file => sub {

            plan skip_all => "TokyoCabinet is not installed."
                if (!$IS_TOKYOCABINET_INSTALLED && $df_file =~ /\.tch$/);

            my $driver = ($df_file =~ /\.tch$/) ? 'TokyoCabinet' : 'Storable';

            my $exception = exception { Lingua::JA::WebIDF->new(driver => $driver, appid => 'test'); };
            like($exception, qr/df_file is not found/, 'not set df_file');

            my $webidf;
            $exception = exception { $webidf = Lingua::JA::WebIDF->new(driver => $driver, df_file => $df_file); };
            is($exception, undef, 'set df_file');
            isa_ok($webidf, 'Lingua::JA::WebIDF');

            $exception = exception { $webidf = Lingua::JA::WebIDF->new({driver => $driver, df_file => $df_file }); };
            is($exception, undef, 'set a hash');
            isa_ok($webidf, 'Lingua::JA::WebIDF');

            $exception = exception { Lingua::JA::WebIDF->new(driver => $driver, df_file => $df_file, document => 250_0000_0000); };
            like($exception, qr/Unknown option: document/, 'set an unknown option');

            $exception = exception { Lingua::JA::WebIDF->new(driver => $driver, df_file => $df_file, appid => 'test', fetch_df => 0); };
            is($exception, undef, "appid => 'test', fetch_df => 0");

            $exception = exception { Lingua::JA::WebIDF->new(driver => $driver, df_file => $df_file, appid => 'test', fetch_df => 1); };
            is($exception, undef, "appid => 'test', fetch_df => 1");

            $exception = exception { Lingua::JA::WebIDF->new(driver => $driver, df_file => $df_file, appid => undef, fetch_df => 0); };
            is($exception, undef, "appid => undef, fetch_df => 0");

            $exception = exception { Lingua::JA::WebIDF->new(driver => $driver, df_file => $df_file, appid => undef, fetch_df => 1); };
            like($exception, qr/appid is required/, "appid => undef, fetch_df => 1");

            $exception = exception { Lingua::JA::WebIDF->new(driver => $driver, df_file => $df_file, appid => 'test', fetch_df => 1, api => 'Wahoo'); };
            unlike($exception, qr/^$/, "appid => test, fetch_df => 1, api => 'Wahoo'");

            for my $idf_type (0 .. 4)
            {
                $exception = exception { Lingua::JA::WebIDF->new(driver => $driver, df_file => $df_file, idf_type => $idf_type); };

                if ($idf_type == 0 || $idf_type == 4)
                {
                    like($exception, qr/Unknown idf type/, 'set a unknow idf_type');
                }
                else
                {
                    is($exception, undef, 'set a correct idf_type');
                }
            }
        };
    }
};

subtest 'df method' => sub {

    for my $df_file (@DF_FILE_LIST)
    {
        subtest $df_file => sub {

            plan skip_all => "TokyoCabinet is not installed."
                if (!$IS_TOKYOCABINET_INSTALLED && $df_file =~ /\.tch$/);

            my $driver = ($df_file =~ /\.tch$/) ? 'TokyoCabinet' : 'Storable';

            my $webidf = Lingua::JA::WebIDF->new(
                driver   => $driver,
                df_file  => $df_file,
                fetch_df => 0,
                verbose  => 0,
            );

            my $exception = exception { $webidf->df('ほげ'); };
            like($exception, qr/not opened/, 'fetch df without opening df_file') if $driver eq 'TokyoCabinet';
            is($exception,   undef,          'fetch df without opening df_file') if $driver eq 'Storable';

            $webidf = Lingua::JA::WebIDF->new(
                driver   => $driver,
                df_file  => $df_file,
                fetch_df => 0,
                verbose  => 1,
            );

            $webidf->db_open;

            my $weight;

            warning_like { $weight = $webidf->df; }
            qr/Undefined or empty word/, 'set an undefined word';
            is($weight, undef);

            warning_like { $weight = $webidf->df(''); }
            qr/Undefined or empty word/, 'set an empty word';
            is($weight, undef);

            isnt($webidf->df('川'), undef, "fetch df of '川' from df file");

            warning_like { $weight = $webidf->idf('川' x 100); }
            qr/use fetch_df/, "calculate idf of '川' x 100 via df file";
            is($weight, undef, "calculate idf of '川' x 100 via df file");

            $webidf->db_close;
        };
    }
};

subtest 'idf method' => sub {

    for my $df_file (@DF_FILE_LIST)
    {
        subtest $df_file => sub {

            plan skip_all => "TokyoCabinet is not installed."
                if (!$IS_TOKYOCABINET_INSTALLED && $df_file =~ /\.tch$/);


            my $driver = ($df_file =~ /\.tch$/) ? 'TokyoCabinet' : 'Storable';
            my $num_of_documents = 250_0000_0000;

            my $webidf = Lingua::JA::WebIDF->new(
                driver    => $driver,
                df_file   => $df_file,
                fetch_df  => 0,
                documents => $num_of_documents,
                verbose   => 0,
            );

            my $exception = exception { $webidf->idf('ほげ'); };
            like($exception, qr/not opened/, 'fetch df without opening df_file') if $driver eq 'TokyoCabinet';
            is($exception,   undef,          'fetch df without opening df_file') if $driver eq 'Storable';

            $webidf = Lingua::JA::WebIDF->new(
                driver    => $driver,
                df_file   => $df_file,
                fetch_df  => 0,
                documents => $num_of_documents,
                verbose   => 1,
            );

            $webidf->db_open;

            my $weight;

            warning_like { $weight = $webidf->idf; }
            qr/Undefined or empty word/, 'set an undefined word';
            is($weight, undef);

            warning_like { $weight = $webidf->idf(''); }
            qr/Undefined or empty word/, 'set an empty word';
            is($weight, undef);

            warning_like { $weight = $webidf->idf(undef, 'df'); }
            qr/Undefined or empty df/, 'set an undefined df';
            is($weight, undef);

            warning_like { $weight = $webidf->idf('', 'df'); }
            qr/Undefined or empty df/, 'set an empty df';
            is($weight, undef);

            isnt($webidf->idf('川'), undef, "calculate idf of '川' via df file");

            warning_like { $weight = $webidf->idf('川' x 100); }
            qr/use fetch_df/, "calculate idf of '川' x 100 via df file";
            is($weight, undef, "calculate idf of '川' x 100 via df file");

            my $df = 100;
            is($webidf->idf($df, 'df'), log($num_of_documents / $df), 'calculate idf with the given df');

            $webidf->db_close;
        };
    }
};

done_testing;
