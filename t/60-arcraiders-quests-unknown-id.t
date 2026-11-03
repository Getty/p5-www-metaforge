#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use HTTP::Response;
use JSON::MaybeXS qw( decode_json );
use Path::Tiny;
use lib "$FindBin::Bin/lib";
use MockUA;
use RecordingUA;
use WWW::MetaForge::ArcRaiders;

# The live API answers quests?id=<unknown> with 404 {"error":"Quest not found"},
# while items?id and arcs?id answer 200 with empty data. For a lookup by id,
# "no such quest" is an empty answer, not a failure; every other error stays
# an error.

my $dir      = "$FindBin::Bin/fixtures";
my $fixture  = decode_json(path("$dir/quests.json")->slurp_raw);
my $known_id = $fixture->{data}[0]{id};

# A UA that answers with a fixed status for the requests its rule matches
# (a regex on the request URI) and with the MockUA answer for all others.
package Stub::UA {
  sub new {
    my ($class, %args) = @_;
    return bless { %args, inner => MockUA->new(fixtures_dir => $dir) }, $class;
  }
  sub request {
    my ($self, $http_request) = @_;
    return $self->{inner}->request($http_request) unless $http_request->uri =~ $self->{match};
    my $response = HTTP::Response->new($self->{status}, $self->{message});
    $response->content($self->{body});
    $response->header('Content-Type' => 'application/json');
    return $response;
  }
}

sub api_with {
  my ($ua) = @_;
  return WWW::MetaForge::ArcRaiders->new(ua => $ua, use_cache => 0);
}

sub error_of {
  my ($code) = @_;
  local $@;
  eval { $code->(); 1 } and return;
  return $@;
}

my $mock_ua = sub { MockUA->new(fixtures_dir => $dir) };

subtest 'quests with an unknown id is an empty list' => sub {
  my $ua  = $mock_ua->();
  my $api = api_with($ua);

  my $quests;
  is(error_of(sub { $quests = $api->quests(id => 'no-such-quest') }), undef, 'does not die');
  is(ref $quests, 'ARRAY', 'an ArrayRef');
  is_deeply($quests, [], 'empty');
  like(($ua->requests)[-1], qr{/api/arc-raiders/quests\?.*\bid=no-such-quest\b}, 'the request carried the id');
};

subtest 'quests_paginated with an unknown id has empty data' => sub {
  my $api = api_with($mock_ua->());

  my $result;
  is(error_of(sub { $result = $api->quests_paginated(id => 'no-such-quest') }), undef, 'does not die');
  is(ref $result, 'HASH', 'a HashRef');
  is(ref $result->{data}, 'ARRAY', 'data is an ArrayRef');
  is_deeply($result->{data}, [], 'data is empty');
};

subtest 'quests with a known id is exactly that quest' => sub {
  my $ua  = RecordingUA->new(fixtures_dir => $dir, filter_by_id => 1);
  my $api = api_with($ua);

  my $quests = $api->quests(id => $known_id);
  is(scalar @$quests, 1, 'one quest');
  isa_ok($quests->[0], 'WWW::MetaForge::ArcRaiders::Result::Quest');
  is($quests->[0]->id, $known_id, 'the quest with that id');
  is($quests->[0]->_raw->{id}, $fixture->{data}[0]{id}, 'built from the fixture record');
};

subtest 'a 500 on a quest lookup by id still dies' => sub {
  my $ua  = Stub::UA->new(match => qr{/quests\?.*\bid=x\b}, status => 500,
    message => 'Internal Server Error', body => '{"error":"boom"}');
  my $api = api_with($ua);

  like(error_of(sub { $api->quests(id => 'x') }), qr{API request failed: 500},
    'quests(id) dies with the status');
  like(error_of(sub { $api->quests_paginated(id => 'x') }), qr{API request failed: 500},
    'quests_paginated(id) dies with the status');
};

subtest 'a 404 on quests without an id still dies' => sub {
  my $ua  = Stub::UA->new(match => qr{/quests}, status => 404,
    message => 'Not Found', body => '{"error":"Quest not found"}');
  my $api = api_with($ua);

  like(error_of(sub { $api->quests(page => 1) }), qr{API request failed: 404},
    'quests(page) dies');
  like(error_of(sub { $api->quests }), qr{API request failed: 404},
    'quests without parameters dies');
  like(error_of(sub { $api->quests_paginated(page => 1) }), qr{API request failed: 404},
    'quests_paginated(page) dies');
};

subtest 'a 404 on another endpoint with an id still dies' => sub {
  my $ua  = Stub::UA->new(match => qr{/arcs}, status => 404,
    message => 'Not Found', body => '{"error":"Arc not found"}');
  my $api = api_with($ua);

  like(error_of(sub { $api->arcs(id => 'no-such-arc') }), qr{API request failed: 404},
    'arcs(id) dies');
};

done_testing;
