#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use File::Temp qw(tempdir);
use MockUA;
use HTTP::Request;
use JSON::MaybeXS;
use Path::Tiny;
use WWW::MetaForge::ArcRaiders;

# karr k12: MockUA must not serve gated relations when the query param that
# unlocks them is missing, so a forgotten includeComponents/includeLoot
# fails offline.
my @relations = qw(
  components dropped_by mods recycle_components recycle_from
  relationships sold_by used_in
);

# Raw responses, as the API client receives them: without includeComponents
# the live API leaves the 8 relation keys out of every item (absent, not []).
my $ua = MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures");
my $json = JSON::MaybeXS->new;
my $plain = $json->decode($ua->request(HTTP::Request->new(GET => 'https://metaforge.app/api/arc-raiders/items?page=1'))->decoded_content);
my $full  = $json->decode($ua->request(HTTP::Request->new(GET => 'https://metaforge.app/api/arc-raiders/items?page=1&includeComponents=true'))->decoded_content);

is(scalar @{ $plain->{data} }, 50, 'page 1 without the param still has all 50 items');
my @leaked = grep { my $row = $_; grep { exists $row->{$_} } @relations } @{ $plain->{data} };
is(scalar @leaked, 0, 'no item carries any of the 8 relation keys without the param');
my @missing = grep { my $row = $_; grep { !exists $row->{$_} } @relations } @{ $full->{data} };
is(scalar @missing, 0, 'every item carries all 8 relation keys with includeComponents=true');
is_deeply(
  [ sort keys %{ $plain->{data}[0] } ],
  [ sort grep { my $key = $_; !grep { $_ eq $key } @relations } keys %{ $full->{data}[0] } ],
  'the other keys are untouched',
);
isnt($json->encode($full->{data}[0]), $json->encode($plain->{data}[0]), 'the two answers differ');

# Through the client: the relations default when the keys are absent
my $api = WWW::MetaForge::ArcRaiders->new(
  ua        => $ua,
  cache_dir => tempdir(CLEANUP => 1),
  use_cache => 0,
);

my ($with)    = grep { $_->id eq 'advanced-arc-powercell' } @{ $api->items(includeComponents => 'true') };
my ($without) = grep { $_->id eq 'advanced-arc-powercell' } @{ $api->items() };
ok(@{ $with->recycle_components } > 0, 'recycle_components present with includeComponents=true');
ok(@{ $with->used_in } > 0, 'used_in present with includeComponents=true');
ok(@{ $with->recycle_from } > 0, 'recycle_from present with includeComponents=true');
ok(@{ $with->dropped_by } > 0, 'dropped_by present with includeComponents=true');
ok(scalar keys %{ $with->relationships }, 'relationships present with includeComponents=true');
for my $relation (qw( components recycle_components sold_by used_in recycle_from mods dropped_by )) {
  is_deeply($without->$relation, [], $relation . ' is empty without the param');
  ok(!exists $without->_raw->{$relation}, $relation . ' is absent from the raw record without the param');
}
is_deeply($without->relationships, {}, 'relationships is empty without the param');
ok(!exists $without->_raw->{relationships}, 'relationships is absent from the raw record without the param');

my ($shot_with) = grep { $_->id eq 'adrenaline-shot' } @{ $api->items(includeComponents => 'true') };
ok(@{ $shot_with->components } > 0, 'components present with includeComponents=true');

my ($arc_with)    = grep { $_->id eq 'arc-assessor' } @{ $api->arcs(includeLoot => 'true') };
my ($arc_without) = grep { $_->id eq 'arc-assessor' } @{ $api->arcs() };
ok(@{ $arc_with->loot } > 0, 'loot present with includeLoot=true');
is(scalar @{ $arc_without->loot }, 0, 'loot stripped without the param');

# /hideout and /weekly-trials take no parameters: the mock serves the bytes of
# the fixture, whatever the query, and the client sends none
for my $endpoint (qw( hideout weekly-trials )) {
  my $file = path("$FindBin::Bin/fixtures/$endpoint.json")->slurp_raw;
  my $url  = "https://metaforge.app/api/arc-raiders/$endpoint";
  is($ua->request(HTTP::Request->new(GET => $url))->content, $file, "$endpoint: the fixture, byte for byte");
  is($ua->request(HTTP::Request->new(GET => "$url?page=2&includeAll=true"))->content, $file, "$endpoint: a query changes nothing");
}

my $plain_ua  = MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures");
my $plain_api = WWW::MetaForge::ArcRaiders->new(ua => $plain_ua, cache_dir => tempdir(CLEANUP => 1), use_cache => 0);
$plain_api->hideout;
$plain_api->weekly_trials;
is_deeply(
  [ $plain_ua->requests ],
  [ 'https://metaforge.app/api/arc-raiders/hideout', 'https://metaforge.app/api/arc-raiders/weekly-trials' ],
  'the client asks for hideout and weekly-trials without a query',
);

done_testing;
