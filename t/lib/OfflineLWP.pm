package OfflineLWP;
use strict;
use warnings;
use RecordingUA;
use LWP::UserAgent;

# For tests that run a real script in a subprocess: load it with
# `perl -It/lib -MOfflineLWP script ...`. Every LWP::UserAgent request the
# script makes is answered by RecordingUA (MockUA plus the id filter) from
# the fixtures, so the subprocess never touches the network. Loading MockUA
# also blocks every other way of reaching the network (simple_request).
# The fixtures directory is $ENV{OFFLINE_FIXTURES_DIR}, default t/fixtures.

my $ua = RecordingUA->new(
  fixtures_dir => $ENV{OFFLINE_FIXTURES_DIR} // 't/fixtures',
  filter_by_id => 1,
);

{
  no warnings 'redefine';
  *LWP::UserAgent::request = sub {
    my ($self, $http_request) = @_;
    return $ua->request($http_request);
  };
}

1;
