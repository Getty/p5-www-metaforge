#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use URI;
use lib "$FindBin::Bin/lib";
use RecordingUA;

use WWW::MetaForge::ArcRaiders;

sub new_api {
  my $ua = RecordingUA->new(fixtures_dir => "$FindBin::Bin/fixtures");
  # No game_map_data is injected: the facade has to hand its ua on.
  my $api = WWW::MetaForge::ArcRaiders->new(
    ua        => $ua,
    cache_dir => tempdir(CLEANUP => 1),
    use_cache => 0,
  );
  return ($api, $ua);
}

subtest 'k29: map_data runs over the injected ua' => sub {
  my ($api, $ua) = new_api();
  $api->map_data(map => 'dam');

  is(scalar $ua->seen, 1, 'the injected ua served exactly one request');
  my ($uri) = $ua->seen_uris;
  my %query = URI->new($uri)->query_form;
  like($uri, qr{^https://metaforge\.app/api/game-map-data\?}, 'it asked the game-map-data endpoint');
  is($query{mapID}, 'dam', 'mapID=dam');
  is($query{tableID}, 'arc_map_data', 'tableID=arc_map_data');

  is($api->game_map_data->ua, $ua, 'the child GameMapData holds the very same ua object');
  is($api->game_map_data->ua, $api->ua, '... which is the facade\'s ua');
};

done_testing;
