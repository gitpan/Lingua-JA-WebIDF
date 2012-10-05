my $app = sub {
    return [ 404, [ 'Content-Type' => 'text/plain' ], [ '404 Not Found' ] ];
};
