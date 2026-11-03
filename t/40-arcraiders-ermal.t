#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use JSON::MaybeXS qw( decode_json );
use Path::Tiny;
use lib "$FindBin::Bin/lib";
use RecordingUA;

use_ok('WWW::MetaForge::ArcRaiders');
use_ok('WWW::MetaForge::ArcRaiders::Result::Ermal');

my $fixtures = "$FindBin::Bin/fixtures";

# t/fixtures/traders.json is the unchanged live /traders response; Ermal is
# its top-level `ermal` section, next to `data`.
my $response = decode_json( path("$fixtures/traders.json")->slurp_raw );
my $section  = $response->{ermal};

sub new_api {
  my (%args) = @_;
  my $ua = RecordingUA->new(fixtures_dir => $fixtures, %{ delete $args{ua_args} || {} });
  my $api = WWW::MetaForge::ArcRaiders->new(
    ua        => $ua,
    cache_dir => tempdir(CLEANUP => 1),
    use_cache => 0,
    %args,
  );
  return ($api, $ua);
}

subtest 'from_hashref maps the ermal section' => sub {
  my $ermal = WWW::MetaForge::ArcRaiders::Result::Ermal->from_hashref($section);
  isa_ok($ermal, 'WWW::MetaForge::ArcRaiders::Result::Ermal');

  is($ermal->synced_at, '2026-10-27T12:59:24.839+00:00', 'synced_at');
  is(scalar @{ $ermal->offers }, 10, 'ten offers');
  is(scalar @{ $ermal->permanent_services }, 2, 'two permanent services');
  is_deeply($ermal->offers, $section->{offers}, 'offers is the offers key');
  is_deeply($ermal->permanent_services, $section->{permanent_services}, 'permanent_services is the permanent_services key');
  is_deeply($ermal->_raw, $section, '_raw is the whole ermal section');
};

subtest 'offers' => sub {
  my $ermal  = WWW::MetaForge::ArcRaiders::Result::Ermal->from_hashref($section);
  my @titles = map { $_->{offer_title} } @{ $ermal->offers };
  is_deeply(\@titles, [
    '2.3 Backpack Attachment: Cauldron', 'Anvil II', 'Dam Staff Key Room',
    'Exodus Techincal Handbook', 'Guitar', 'Hullcracker II', 'Occult Backpack',
    'Power Descender', 'Raider Tokens x25', 'Wolfpack',
  ], 'offer titles in API order (typo "Techincal" is the API\'s)');

  my $cauldron = $ermal->offers->[0];
  is($cauldron->{id}, '5a9be174-55a0-4571-a264-1ea0c56f4507', 'id');
  is($cauldron->{coin_cost}, 50000, 'coin_cost');
  is($cauldron->{offer_start}, '2026-10-27T13:00:00+00:00', 'offer_start');
  is($cauldron->{offer_end}, '2026-11-03T13:00:00+00:00', 'offer_end');
  is($cauldron->{item}{name}, 'Cauldron (Backpack Attachment)', 'item name');
  is($cauldron->{item}{item_type}, 'Cosmetic', 'item item_type');
  is($cauldron->{item}{rarity}, undef, 'item rarity is null');
  is(scalar @{ $cauldron->{accepted_items} }, 11, 'eleven accepted items');
  is($cauldron->{accepted_items}[0]{name}, 'Bronze Statuette', 'first accepted item');
  is($cauldron->{accepted_items}[0]{amount}, 1, 'accepted item amount');
  is($cauldron->{accepted_items}[0]{value}, 10000, 'accepted item value');
  is($cauldron->{accepted_items}[5]{id}, 'bully-fragmenter', 'accepted item with null fields');
  is($cauldron->{accepted_items}[5]{icon}, undef, 'icon can be null');
  is($cauldron->{accepted_items}[5]{rarity}, undef, 'rarity can be null');

  my ($tokens) = grep { $_->{offer_title} eq 'Raider Tokens x25' } @{ $ermal->offers };
  ok(exists $tokens->{item}, 'the tokens offer has an item key ...');
  is($tokens->{item}, undef, '... which is null');
};

subtest 'permanent services' => sub {
  my $ermal = WWW::MetaForge::ArcRaiders::Result::Ermal->from_hashref($section);
  is_deeply([ map { $_->{name} } @{ $ermal->permanent_services } ],
    [ 'Expedition Vault', 'Stash Expansion' ], 'service names');

  my $vault = $ermal->permanent_services->[0];
  is($vault->{id}, 'expedition-vault', 'id');
  is($vault->{coin_cost}, 200000, 'coin_cost');
  like($vault->{description}, qr/^Safely stores items between expeditions/, 'description');
  is(scalar @{ $vault->{accepted_items} }, 9, 'nine accepted items');
  is($vault->{accepted_items}[0]{name}, 'Matriarch Reactor', 'first accepted item');
  ok(!exists $vault->{accepted_items}[0]{amount}, 'service entries carry no amount');
};

subtest 'defaults' => sub {
  my $ermal = WWW::MetaForge::ArcRaiders::Result::Ermal->from_hashref({});
  is_deeply($ermal->offers, [], 'offers defaults to []');
  is_deeply($ermal->permanent_services, [], 'permanent_services defaults to []');
  is($ermal->synced_at, undef, 'synced_at is undef');
};

subtest '$api->ermal' => sub {
  my ($api, $ua) = new_api();
  my $ermal = $api->ermal;
  isa_ok($ermal, 'WWW::MetaForge::ArcRaiders::Result::Ermal');
  is($ermal->synced_at, $section->{synced_at}, 'synced_at from the traders response');
  is_deeply($ermal->_raw, $section, '_raw is the response section');
  is(scalar @{ $ermal->offers }, 10, 'offers');
  is(scalar @{ $ermal->permanent_services }, 2, 'permanent_services');
  like(($ua->seen_uris)[0], qr{/api/arc-raiders/traders$}, 'it asked the traders endpoint');
  is(scalar $ua->seen, 1, 'one request');
};

subtest 'traders and ermal cost one request with the cache on' => sub {
  my ($api, $ua) = new_api(use_cache => 1);
  my $traders = $api->traders;
  my $ermal   = $api->ermal;
  is(scalar @$traders, 5, 'traders answered');
  is(scalar @{ $ermal->offers }, 10, 'ermal answered');
  is(scalar $ua->seen, 1, 'traders + ermal: exactly one request');

  my ($api2, $ua2) = new_api(use_cache => 1);
  $api2->ermal;
  $api2->traders;
  $api2->ermal;
  is(scalar $ua2->seen, 1, 'ermal + traders + ermal: exactly one request');
};

subtest 'without an ermal section' => sub {
  my ($api, $ua) = new_api(ua_args => { drop_sections => ['ermal'] });
  is($api->ermal, undef, 'ermal is undef');
  is(scalar @{ $api->traders }, 5, 'traders are unaffected');
  ok(!exists $api->traders_raw->{ermal}, 'the served response really has no ermal key');
};

subtest 'traders() is unchanged by ermal' => sub {
  my ($api) = new_api();
  my $traders = $api->traders;
  is_deeply([ map { $_->name } @$traders ], [qw( Apollo Celeste Lance Shani TianWen )], 'trader names');
  is_deeply($traders->[1]->inventory, $response->{data}{Celeste}, 'Celeste inventory is data.Celeste');
};

done_testing;
