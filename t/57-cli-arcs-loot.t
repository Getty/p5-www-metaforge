#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use JSON::MaybeXS ();
use Path::Tiny;
use URI;
use lib "$FindBin::Bin/lib";

BEGIN {
  eval { require Capture::Tiny };
  if ($@) {
    plan skip_all => 'Capture::Tiny required for CLI tests';
  }
}
use Capture::Tiny qw(capture_stdout);
use RecordingUA;

use_ok('WWW::MetaForge::ArcRaiders::CLI');
use_ok('WWW::MetaForge::ArcRaiders::CLI::Cmd::Arcs');

# karr k38: "arcs --loot" prints, under every ARC, one indented line per drop
# (item name, rarity), "  (no loot drops)" for an ARC without drops. Without
# --loot the text view is as before. Expected values are read from the
# byte-faithful t/fixtures/arcs.json (26 ARCs, 149 drops, 4 ARCs without).

my $class     = 'WWW::MetaForge::ArcRaiders::CLI::Cmd::Arcs';
my $cache_dir = tempdir(CLEANUP => 1);
my $fixture   = JSON::MaybeXS->new->decode(path("$FindBin::Bin/fixtures/arcs.json")->slurp_utf8);
my @fx_arcs   = @{ $fixture->{data} };

sub mock_cli {
  my $ua  = RecordingUA->new(fixtures_dir => "$FindBin::Bin/fixtures");
  my $cli = WWW::MetaForge::ArcRaiders::CLI->new();
  $cli->{api} = WWW::MetaForge::ArcRaiders->new(
    ua        => $ua,
    cache_dir => $cache_dir,
    use_cache => 0,
  );
  return ($cli, $ua);
}

sub run_arcs {
  my (%args) = @_;
  my ($cli, $ua) = mock_cli();
  $cli->{json} = delete $args{json};
  my $output = capture_stdout { $class->new(%args)->execute([], [$cli]) };
  return ($output, $ua);
}

subtest 'fixture sanity (the numbers below come from it)' => sub {
  is(scalar @fx_arcs, 26, '26 ARCs');
  is(scalar(map { @{ $_->{loot} } } @fx_arcs), 149, '149 drops');
  is(scalar(grep { !@{ $_->{loot} } } @fx_arcs), 4, '4 ARCs without drops');
};

subtest 'arcs --loot - drops under their ARC' => sub {
  my ($output, $ua) = run_arcs( loot => 1 );

  is(query_of(($ua->seen_uris)[0])->{includeLoot}, 'true', 'the request asks for includeLoot=true');
  like($output, qr/^ARC Assessor\s+\[arc-assessor\]\n  ARC Powercell\s+Common\n  ARC Alloy\s+Uncommon\n  ARC Circuitry\s+Rare\n  Assessor Matrix\s+Epic\n/m,
    'ARC Assessor: its four drops in API order, name and rarity');
  like($output, qr/^ARC Frigate\s+\[frigate\]\n  \(no loot drops\)\n/m, 'an ARC without drops says so');
  like($output, qr/^  ARC Powercell {25,}Common$/m, 'name column is 38 wide, two spaces, then the rarity');
};

subtest 'arcs --loot - every ARC, every drop' => sub {
  my ($output) = run_arcs( loot => 1 );

  my @lines = split /\n/, $output;
  my @arc_lines  = grep { /^\S.*\[\S+\]$/ } @lines;
  my @drop_lines = grep { /^  (?!\(no loot drops\))\S/ } @lines;
  my @none_lines = grep { $_ eq '  (no loot drops)' } @lines;

  is(scalar @arc_lines,  26,  '26 ARC lines');
  is(scalar @drop_lines, 149, '149 drop lines');
  is(scalar @none_lines, 4,   '4 "(no loot drops)" lines');
  like($output, qr/^26 ARC\(s\) found\.$/m, 'summary line');

  # rebuild the expected text block by block from the fixture
  my $expected = '';
  for my $arc (@fx_arcs) {
    $expected .= sprintf "%-40s  [%s]\n", $arc->{name}, $arc->{id};
    $expected .= "  (no loot drops)\n" unless @{ $arc->{loot} };
    $expected .= sprintf "  %-38s  %s\n", $_->{item}{name}, $_->{item}{rarity} for @{ $arc->{loot} };
  }
  $expected .= "\n26 ARC(s) found.\n";
  is($output, $expected, 'the whole output equals the layout built from the fixture');
};

subtest 'arcs without --loot - unchanged' => sub {
  my ($output, $ua) = run_arcs();

  unlike(($ua->seen_uris)[0], qr/includeLoot/, 'no includeLoot in the request');
  unlike($output, qr/^  /m, 'no indented line');
  unlike($output, qr/no loot drops/, 'no "(no loot drops)"');
  my @arc_lines = grep { /^\S.*\[\S+\]$/ } split /\n/, $output;
  is(scalar @arc_lines, 26, '26 ARC lines');
  like($output, qr/^26 ARC\(s\) found\.$/m, 'summary line');
  like($output, qr/^ARC Assessor\s+\[arc-assessor\]\nARC Frigate\s+\[frigate\]\n/m,
    'ARC lines follow each other directly');
};

subtest 'arcs --loot --json - unchanged' => sub {
  my ($output) = run_arcs( loot => 1, json => 1 );

  my $data = JSON::MaybeXS->new->decode($output);
  is(scalar @$data, 26, '26 records');
  unlike($output, qr/\(no loot drops\)/, 'no text-view line in JSON');
  is(scalar(map { @{ $_->{loot} } } @$data), 149, 'the raw loot is all there');
};

sub query_of { return { URI->new($_[0])->query_form } }

done_testing;
