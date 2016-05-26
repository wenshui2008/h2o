use strict;
use warnings;
use Net::EmptyPort qw(check_port empty_port);
use Test::More;
use t::Util;

plan skip_all => 'curl not found'
    unless prog_exists('curl');
plan skip_all => 'plackup not found'
    unless prog_exists('plackup');
plan skip_all => 'Starlet not found'
    unless system('perl -MStarlet /dev/null > /dev/null 2>&1') == 0;

my $upstream_port = empty_port();

my $guard = spawn_server(
    argv     => [ qw(plackup -s Starlet --keepalive-timeout 100 --access-log /dev/null --listen), $upstream_port, ASSETS_DIR . "/upstream.psgi" ],
    is_ready =>  sub {
        check_port($upstream_port);
    },
);

my $server = spawn_h2o(<< "EOT");
hosts:
  default:
    paths:
      /:
        proxy.reverse.url: http://127.0.0.1.XIP.IO:$upstream_port
EOT

run_with_curl($server, sub {
    my ($proto, $port, $curl) = @_;
    my $resp = `$curl --silent --dump-header /dev/stdout --max-redirs 0 "$proto://127.0.0.1:$port/?resp:status=302&resp:location=http://127.0.0.1.xip.io:$upstream_port/abc"`;
    like $resp, qr{HTTP/[^ ]+ 302\s}m;
    like $resp, qr{^location: ?$proto://127.0.0.1:$port/abc\r$}m;
});

done_testing();
