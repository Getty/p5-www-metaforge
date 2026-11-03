#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use HTTP::Request;
use JSON::MaybeXS qw(decode_json);
use LWP::UserAgent;
use Path::Tiny;
use URI::Escape ();
use MockUA;

my $base = 'https://metaforge.app/api/arc-raiders/items';
my $ua   = MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures");

sub fetch {
  my ($query) = @_;
  my $response = $ua->request(HTTP::Request->new(GET => $base . $query));
  die 'MockUA answered ' . $response->code unless $response->is_success;
  return decode_json($response->content);
}

subtest 'page 1 with the client parameters is the fixture, byte for byte' => sub {
  my $response = $ua->request(HTTP::Request->new(GET => "$base?page=1&includeComponents=true"));
  my $fixture  = path("$FindBin::Bin/fixtures/items.json")->slurp_raw;
  ok($response->content eq $fixture, 'the served bytes equal t/fixtures/items.json');
};

subtest 'the item_type filter is exact and case-sensitive' => sub {
  my $answer = fetch('?item_type=Quick%20Use&includeComponents=true');
  my @types  = map { $_->{item_type} } @{ $answer->{data} };
  ok(@types > 0, 'finds Quick Use items');
  is(scalar(grep { $_ ne 'Quick Use' } @types), 0, 'only Quick Use items');
  is($answer->{pagination}{total}, scalar @types, 'total counts the matches');
  is($answer->{pagination}{totalPages}, 1, 'one page');
  ok(!$answer->{pagination}{hasNextPage}, 'no next page');

  for my $wrong ('quick use', 'QUICK USE', 'Quick', 'Quick Use ') {
    my $none = fetch('?item_type=' . URI::Escape::uri_escape($wrong));
    is(scalar @{ $none->{data} }, 0, "'$wrong' matches nothing");
    is($none->{pagination}{total}, 0, "'$wrong': total 0");
    is($none->{pagination}{totalPages}, 0, "'$wrong': totalPages 0, like the live API");
  }
};

subtest 'the rarity filter is exact and case-sensitive' => sub {
  my $answer = fetch('?rarity=Legendary');
  is_deeply(
    [ map { $_->{id} } @{ $answer->{data} } ],
    [qw( acoustic-guitar advanced-camera-blueprint )],
    'the Legendary items of page 1',
  );
  is(scalar @{ fetch('?rarity=legendary')->{data} }, 0, 'lower case matches nothing');
};

subtest 'item_type and rarity combine as AND' => sub {
  my $answer = fetch('?item_type=Quick%20Use&rarity=Legendary');
  is_deeply([ map { $_->{id} } @{ $answer->{data} } ], ['acoustic-guitar'], 'only the Legendary Quick Use item');
  is(scalar @{ fetch('?item_type=Blueprint&rarity=Common')->{data} }, 0, 'no match for a pair that does not occur');
};

subtest 'a filter ends after one page' => sub {
  is(scalar @{ fetch('?rarity=Legendary&page=2')->{data} }, 0, 'page 2 of a filter is empty');
  ok(!fetch('?rarity=Legendary&page=2')->{pagination}{hasNextPage}, 'and has no next page');
};

subtest 'page files and empty pages between them' => sub {
  my $page8 = fetch('?page=8&includeComponents=true');
  is($page8->{pagination}{page}, 8, 'page 8 is the live page 8');
  ok((grep { $_->{id} eq 'chemicals' } @{ $page8->{data} }), 'with its live items');
  ok($page8->{pagination}{hasNextPage}, 'a next page follows');

  my $page2 = fetch('?page=2&includeComponents=true');
  is(scalar @{ $page2->{data} }, 0, 'page 2 has no file and is empty');
  is($page2->{pagination}{page}, 2, 'it reports its page number');
  ok($page2->{pagination}{hasNextPage}, 'it still reports a next page, the walk continues');

  my $last = fetch('?page=31&includeComponents=true');
  is(scalar @{ $last->{data} }, 0, 'page 31 has no file and is empty');
  ok(!$last->{pagination}{hasNextPage}, 'page 31 is the last one');
};

subtest 'requests are recorded' => sub {
  my $recorder = MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures");
  $recorder->request(HTTP::Request->new(GET => "$base?rarity=Rare"));
  $recorder->request(HTTP::Request->new(GET => "$base?page=1"));
  is_deeply([ $recorder->requests ], ["$base?rarity=Rare", "$base?page=1"], 'both URIs, in order');
  is($recorder->last_request, "$base?page=1", 'last_request');
};

subtest 'the network lock stops a real LWP::UserAgent' => sub {
  plan skip_all => 'WWW_METAFORGE_USE_LIVE_API is set, the lock is off'
    if $ENV{WWW_METAFORGE_USE_LIVE_API};
  my $url = 'https://metaforge.app/api/arc-raiders/items?page=1';
  my $error = do { local $@; eval { LWP::UserAgent->new->get($url) }; $@ };
  like($error, qr/network access blocked/, 'a real request dies');
  like($error, qr/\Q$url\E/, 'and names the URL');
};

done_testing;
