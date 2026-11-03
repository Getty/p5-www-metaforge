#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use HTTP::Request;
use JSON::MaybeXS qw( decode_json );
use lib "$FindBin::Bin/lib";
use MockUA;
use RecordingUA;

# The mock has to answer like the live API (curl, 2026-11-03): an unknown
# quest id is 404 {"error":"Quest not found"}, a known one is 200. Items and
# arcs answer 200 with empty data for an unknown id.

my $dir = "$FindBin::Bin/fixtures";
sub get { return $_[0]->request(HTTP::Request->new(GET => 'https://metaforge.app/api/arc-raiders/'.$_[1])) }

subtest 'quests with an unknown id: 404 and the live body' => sub {
  my $ua = MockUA->new(fixtures_dir => $dir);
  for my $id ('a-bad-feeling-nope', 'Celeste%E2%80%99s+Journals', 'A+Bad+Feeling') {
    my $res = get($ua, 'quests?id='.$id);
    is($res->code, 404, $id.': 404');
    is($res->content, '{"error":"Quest not found"}', $id.': body');
    like($res->header('Content-Type'), qr{^application/json}, $id.': content type');
  }
};

subtest 'quests with a known id: the fixture' => sub {
  my $ua  = MockUA->new(fixtures_dir => $dir);
  my $res = get($ua, 'quests?id=celestes-journals');
  is($res->code, 200, 'a known quest id answers 200');
  ok(scalar(grep { $_->{id} eq 'celestes-journals' } @{ decode_json($res->content)->{data} }), 'the quest is in the data');

  my $rec = RecordingUA->new(fixtures_dir => $dir, filter_by_id => 1);
  my $data = decode_json(get($rec, 'quests?id=celestes-journals')->content)->{data};
  is_deeply([ map { $_->{id} } @$data ], ['celestes-journals'], 'RecordingUA (OfflineLWP) filters to that quest');
  is(get($rec, 'quests?id=nope')->code, 404, 'and passes the 404 through');
};

subtest 'without id, and other endpoints: unchanged' => sub {
  my $ua = MockUA->new(fixtures_dir => $dir);
  is(get($ua, 'quests')->code, 200, 'quests without id: 200');
  is(get($ua, 'quests?page=2')->code, 200, 'quests page 2: 200');
  is(get($ua, 'items?id=nope-nope')->code, 200, 'items with an unknown id: 200 (live)');
  is(get($ua, 'arcs?id=nope-nope')->code, 200, 'arcs with an unknown id: 200 (live)');
};

done_testing;
