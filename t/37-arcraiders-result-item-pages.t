#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use JSON::MaybeXS qw(decode_json);

use_ok('WWW::MetaForge::ArcRaiders::Result::Item');

# Attributes the live API fills only on later pages of /items. The page files
# t/fixtures/items-page-N.json are the unchanged live responses of
# ?page=N&includeComponents=true (the same files MockUA serves for page N).
sub page_item {
  my ($page, $id) = @_;
  my $file = "$FindBin::Bin/fixtures/items-page-$page.json";
  open my $fh, '<:raw', $file or die "Cannot open $file: $!";
  my $payload = decode_json(do { local $/; <$fh> });
  close $fh;
  is($payload->{pagination}{page}, $page, "fixture items-page-$page.json is page $page");
  my ($data) = grep { $_->{id} eq $id } @{ $payload->{data} };
  die "item $id is not on page $page" unless $data;
  return WWW::MetaForge::ArcRaiders::Result::Item->from_hashref($data);
}

subtest 'mods (page 8, compensator-i)' => sub {
  my $item = page_item(8, 'compensator-i');
  is(scalar @{ $item->mods }, 20, 'twenty compatible items');
  is_deeply(
    [ map { $_->{mod}{id} } @{ $item->mods }[0 .. 2] ],
    [qw( arpeggio-i arpeggio-ii arpeggio-iii )],
    'mods: each entry wraps the item under the key mod',
  );
};

subtest 'guide_links and guide_url (page 8, cat-bed)' => sub {
  my $item = page_item(8, 'cat-bed');
  is($item->guide_url, '/arc-raiders/how-to-find-cat-beds-in-arc-raiders', 'guide_url');
  is_deeply(
    $item->guide_links,
    [ { label => 'Cat Bed Video', url => 'https://youtu.be/2iWoQJYp2T8' } ],
    'guide_links keeps label and url',
  );
  my $plain = page_item(8, 'compensator-i');
  ok(!defined $plain->guide_url, 'guide_url null -> undef');
  is_deeply($plain->guide_links, [], 'guide_links [] stays empty');
};

subtest 'unlocks_weapon (page 11, equalizer-recipe)' => sub {
  my $recipe = page_item(11, 'equalizer-recipe');
  is($recipe->unlocks_weapon, 1, 'unlocks_weapon true -> 1');
  is($recipe->guide_url, '/arc-raiders/how-to-get-the-equalizer-blueprint-in-arc-raiders', 'guide_url of the recipe');

  my $plain = page_item(11, 'extended-barrel');
  ok(!exists $plain->_raw->{unlocks_weapon}, 'the API leaves the key out for other items');
  is($plain->unlocks_weapon, 0, 'absent unlocks_weapon -> 0');
};

subtest 'locations (page 20, patrol-car-key)' => sub {
  my $item = page_item(20, 'patrol-car-key');
  is_deeply(
    $item->locations,
    [ { id => 'ca792d5687618106082c5a2271b8c042', map => 'dam' } ],
    'locations keeps id and map',
  );
};

subtest 'shield_type (page 15, heavy-shield)' => sub {
  my $item = page_item(15, 'heavy-shield');
  is($item->shield_type, 'heavy', 'shield_type');
  is($item->item_type, 'Shield', 'item_type');
};

done_testing;
