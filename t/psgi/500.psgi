my $app = sub {
    return [ 500, [ 'Content-Type' => 'text/plain' ], [ '500 Internal Server Error' ] ];
};
