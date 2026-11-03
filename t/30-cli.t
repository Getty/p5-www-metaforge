#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/lib";
use Capture::Tiny qw(capture_stdout);
use URI;
use FrozenClock;

# Skip if Capture::Tiny not available
BEGIN {
  eval { require Capture::Tiny };
  if ($@) {
    plan skip_all => 'Capture::Tiny required for CLI tests';
  }
}

use_ok('WWW::MetaForge::ArcRaiders::CLI');

my $cache_dir = tempdir(CLEANUP => 1);

# Helper to create CLI with MockUA
sub mock_cli {
  require MockUA;
  my $cli = WWW::MetaForge::ArcRaiders::CLI->new();
  # Inject mock API; the UA stays reachable to see which queries arrived
  $cli->{mock_ua} = MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures");
  $cli->{api} = WWW::MetaForge::ArcRaiders->new(
    ua        => $cli->{mock_ua},
    cache_dir => $cache_dir,
    use_cache => 0,
  );
  return $cli;
}

subtest 'CLI help' => sub {
  my $cli = mock_cli();
  my $output = capture_stdout {
    $cli->execute([], [$cli]);
  };

  like($output, qr/metaforge-arcraiders/, 'shows app name');
  like($output, qr/items/, 'mentions items command');
  like($output, qr/quests/, 'mentions quests command');
  like($output, qr/--debug/, 'mentions debug option');
  like($output, qr/--json/, 'mentions json option');
  like($output, qr/hideout/, 'mentions hideout command');
  like($output, qr/trials/, 'mentions trials command');
};

subtest 'Items command' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Items;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Items->new();

  my $output = capture_stdout {
    local @ARGV = ();
    $cmd->execute([], [$cli]);
  };

  like($output, qr/Adrenaline Shot/, 'shows item names');
  like($output, qr/Weapon|Material/, 'shows categories');
  like($output, qr/item\(s\)/, 'shows item count');
};

subtest 'Items command with search' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Items;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Items->new(search => 'Adrenaline');

  my $output = capture_stdout {
    $cmd->execute([], [$cli]);
  };

  # MockUA doesn't actually filter, but command should run
  like($output, qr/Adrenaline/, 'shows results');
};

# --category and --rarity go to the API as item_type and rarity (exact,
# case-sensitive, AND). MockUA evaluates them like the live API, so a CLI
# that filters locally, or sends another parameter name, shows items from the
# unfiltered page 1 and fails here.
sub item_queries {
  my ($cli) = @_;
  return map { { URI->new($_)->query_form } } $cli->{mock_ua}->requests;
}

subtest 'Items command with category filter' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Items;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Items->new(category => 'Quick Use');

  my $output = capture_stdout {
    $cmd->execute([], [$cli]);
  };

  my ($query) = item_queries($cli);
  is($query->{item_type}, 'Quick Use', 'the category went to the API as item_type');
  ok(!exists $query->{category}, 'no category parameter was sent');

  like($output, qr/\[adrenaline-shot\]/, 'shows a Quick Use item of page 1');
  like($output, qr/\[acoustic-guitar\]/, 'shows another Quick Use item of page 1');
  unlike($output, qr/\[abyss-outfit\]/, 'does not show an outfit');
  unlike($output, qr/\[advanced-electrical-components\]/, 'does not show a refined material');
  unlike($output, qr/\[amplified-anvil\]/, 'does not show a weapon');
};

subtest 'Items command with category filter is case-sensitive' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Items;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Items->new(category => 'quick use');

  my $output = capture_stdout {
    $cmd->execute([], [$cli]);
  };

  my ($query) = item_queries($cli);
  is($query->{item_type}, 'quick use', 'the value went to the API unchanged');
  like($output, qr/No items found/, 'the exact match finds nothing for another casing');
};

subtest 'Items command with rarity filter' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Items;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Items->new(rarity => 'Legendary');

  my $output = capture_stdout {
    $cmd->execute([], [$cli]);
  };

  my ($query) = item_queries($cli);
  is($query->{rarity}, 'Legendary', 'the rarity went to the API as rarity');

  like($output, qr/\[acoustic-guitar\]/, 'shows a Legendary item');
  like($output, qr/\[advanced-camera-blueprint\]/, 'shows another Legendary item');
  unlike($output, qr/\[adrenaline-shot\]/, 'does not show a Common item');
  unlike($output, qr/\[advanced-camera\]/, 'does not show a Rare item');
};

subtest 'Items command with category and rarity filter (AND)' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Items;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Items->new(category => 'Quick Use', rarity => 'Legendary');

  my $output = capture_stdout {
    $cmd->execute([], [$cli]);
  };

  my ($query) = item_queries($cli);
  is($query->{item_type}, 'Quick Use', 'item_type sent');
  is($query->{rarity}, 'Legendary', 'rarity sent');
  like($output, qr/\[acoustic-guitar\]/, 'shows the Legendary Quick Use item');
  unlike($output, qr/\[advanced-camera-blueprint\]/, 'does not show a Legendary Blueprint');
  unlike($output, qr/\[adrenaline-shot\]/, 'does not show a Common Quick Use item');
  like($output, qr/^1 item\(s\) shown/m, 'exactly one item') or diag($output);
};

subtest 'Items command JSON output' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Items;

  my $cli = mock_cli();
  $cli->{json} = 1;  # Enable JSON mode
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Items->new();

  my $output = capture_stdout {
    $cmd->execute([], [$cli]);
  };

  like($output, qr/^\[/, 'starts with [');
  like($output, qr/"name"/, 'has name field');
  like($output, qr/"id"/, 'has id field');

  # Should be valid JSON
  require JSON::MaybeXS;
  my $data = eval { JSON::MaybeXS::decode_json($output) };
  ok(!$@, 'valid JSON') or diag("JSON error: $@");
  ok(ref $data eq 'ARRAY', 'is array');
};

subtest 'Arcs command' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Arcs;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Arcs->new();

  my $output = capture_stdout {
    $cmd->execute([], [$cli]);
  };

  like($output, qr/Salvage|arc/i, 'shows arc data');
};

subtest 'Quests command' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Quests;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Quests->new();

  my $output = capture_stdout {
    $cmd->execute([], [$cli]);
  };

  like($output, qr/quest|Quest/i, 'shows quest data');
};

subtest 'Events command' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Events;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Events->new();

  my $output = capture_stdout {
    $cmd->execute([], [$cli]);
  };

  # May show events or "no events" message
  ok(length($output) > 0, 'produces output');
};

subtest 'Traders command' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Traders;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Traders->new();

  my $output = capture_stdout {
    $cmd->execute([], [$cli]);
  };

  ok(length($output) > 0, 'produces output');
};

# Single item/quest/arc/event commands
subtest 'Item command - single item lookup' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Item;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Item->new();

  # adrenaline-shot is a real fixture item with populated components,
  # sold_by and recycle_components, so this exercises the CLI's
  # Crafting Requirements / Sold By / Recycle Yield rendering against the
  # live-API shape (Result::Item->components/sold_by/recycle_components).
  my $output = capture_stdout {
    $cmd->execute(['adrenaline-shot'], [$cli]);
  };

  like($output, qr/Adrenaline Shot/i, 'shows item name');
  like($output, qr/ID:\s+adrenaline-shot/i, 'shows ID field (from id, not slug)');
  like($output, qr/Category:\s+Quick Use/i, 'shows category from item_type');
  like($output, qr/Base Value:\s+300/, 'shows base value from value');

  like($output, qr/Crafting Requirements:/, 'shows crafting requirements section');
  like($output, qr/3x Plastic Parts/, 'lists Plastic Parts component with quantity');
  like($output, qr/3x Chemicals/, 'lists Chemicals component with quantity');

  like($output, qr/Sold By:/, 'shows sold by section');
  like($output, qr/Lance \(900\)/, 'shows trader_name and price from new sold_by shape');

  like($output, qr/Recycle Yield:/, 'shows recycle yield section');
  like($output, qr/1x Chemicals/, 'lists recycled Chemicals');
  like($output, qr/1x Plastic Parts/, 'lists recycled Plastic Parts');

  like($output, qr/Last Updated:/, 'shows updated_at timestamp');
};

subtest 'Item command - Recycled From and Dropped By' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Item;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Item->new();

  # advanced-arc-powercell (page 1 of the live fixture): recycle_from holds
  # 2x frigate-inductor and 4x assessor-matrix, dropped_by eleven ARCs.
  my $output = capture_stdout {
    $cmd->execute(['advanced-arc-powercell'], [$cli]);
  };

  like($output, qr/Advanced ARC Powercell/, 'shows item name');
  like($output, qr/Recycled From:/, 'shows the Recycled From section');
  like($output, qr/Frigate Inductor/, 'lists the first recycle source');
  like($output, qr/Assessor Matrix/, 'lists the second recycle source');
  like($output, qr/Dropped By:/, 'shows the Dropped By section');
  like($output, qr/Leaper/, 'lists the name of the first dropping ARC');
  like($output, qr/Vaporizer|Bombardier/, 'lists later dropping ARCs');
  like($output, qr/Used In:/, 'shows the Used In section');
  like($output, qr/Surge Shield Recharger/, 'lists the fourth used_in entry');

  my ($query) = map { { URI->new($_)->query_form } } $cli->{mock_ua}->requests;
  is($query->{includeComponents}, 'true', 'the item command asks for includeComponents=true');
};

subtest 'Item command - no argument shows usage' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Item;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Item->new();

  my $output = capture_stdout {
    $cmd->execute([], [$cli]);
  };

  like($output, qr/Usage:/i, 'shows usage message');
};

subtest 'Quest command - single quest lookup' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Quest;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Quest->new();

  my $output = capture_stdout {
    $cmd->execute(['a-bad-feeling'], [$cli]);
  };

  like($output, qr/A Bad Feeling/i, 'shows quest name');
  like($output, qr/ID:/i, 'shows ID field');
};

subtest 'Quest command - no argument shows usage' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Quest;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Quest->new();

  my $output = capture_stdout {
    $cmd->execute([], [$cli]);
  };

  like($output, qr/Usage:/i, 'shows usage message');
};

subtest 'Arc command - single arc lookup' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Arc;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Arc->new();

  # Arcs are ARC enemy types in the live API (e.g. "ARC Assessor", "Bastion"),
  # not named missions - arc-assessor is the first entry in t/fixtures/arcs.json.
  my $output = capture_stdout {
    $cmd->execute(['arc-assessor'], [$cli]);
  };

  like($output, qr/ARC Assessor/i, 'shows arc name');
  like($output, qr/ID:/i, 'shows ID field');
  like($output, qr/ARC Powercell/i, 'shows loot drop');
};

subtest 'Arc command - no argument shows usage' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Arc;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Arc->new();

  my $output = capture_stdout {
    $cmd->execute([], [$cli]);
  };

  like($output, qr/Usage:/i, 'shows usage message');
};

# The events-schedule fixture covers Mon 2 Nov 21:00 - Wed 4 Nov 15:00 UTC;
# the clock is frozen inside it, so the status lines do not depend on the day
sub event_output {
  my ($when, $args, %opt) = @_;
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Event;
  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Event->new(%opt);
  my $output = '';
  FrozenClock::at($when, sub {
    $output = capture_stdout { $cmd->execute($args, [$cli]) };
  });
  return $output;
}

subtest 'Event command - single event lookup' => sub {
  my $output = event_output('2026-11-03T05:30:00', ['Close Scrutiny']);

  like($output, qr/^Close Scrutiny$/m, 'shows the event name');
  like($output, qr/Map:\s+Dam/, 'shows the map');
  like($output, qr/Status:\s+Inactive/, 'inactive, its run is on Wednesday');
  like($output, qr/Starts in:\s+31h 30m/, 'starts in 31h 30m (Wed 13:00 minus Tue 05:30)');
  like($output, qr/^Schedule \(UTC\):\n  Wed 04 Nov 13:00 - 14:00\n/m, 'schedule line with date');
  unlike($output, qr/Multiple events|not found/, 'no list, no not-found');
};

subtest 'Event command - active event' => sub {
  my $output = event_output('2026-11-03T05:30:00', ['Night Raid'], map => 'stella-montis');

  like($output, qr/Status:\s+ACTIVE/, 'Night Raid | Stella Montis is active');
  like($output, qr/Ends in:\s+30m/, 'ends in 30m');
  like($output, qr/^  Tue 03 Nov 05:00 - 06:00$/m, 'the running slot with date');
  is(scalar(() = $output =~ /^  \w{3} \d\d \w{3} \d\d:\d\d - \d\d:\d\d$/mg), 21, 'all 21 runs of the window are listed');
};

subtest 'Event command - ambiguous name' => sub {
  my $output = event_output('2026-11-03T05:30:00', ['Night Raid']);

  like($output, qr/^Multiple events match 'Night Raid':$/m, 'reports multiple matches');
  for my $map ('Buried City', 'Blue Gate', 'Dam', 'Pendola Pass', 'Riven Tides', 'Spaceport', 'Stella Montis') {
    like($output, qr/^  Night Raid \(\Q$map\E\)$/m, "lists Night Raid on $map");
  }
  like($output, qr/Use --map to specify/, 'points to --map');
  unlike($output, qr/Schedule \(UTC\)/, 'no detail view');
};

subtest 'Event command - --map as map ID and as display name' => sub {
  my $by_id   = event_output('2026-11-03T05:30:00', ['Night Raid'], map => 'stella-montis');
  my $by_name = event_output('2026-11-03T05:30:00', ['Night Raid'], map => 'Stella Montis');

  like($by_id, qr/^Night Raid$/m, 'by ID: detail view of Night Raid');
  like($by_id, qr/Map:\s+Stella Montis/, 'by ID: on Stella Montis');
  unlike($by_id, qr/Multiple events/, 'by ID: no list');
  is($by_name, $by_id, 'display name gives the same output as the ID');
};

subtest 'Event command - name found, but not on the map' => sub {
  my $output = event_output('2026-11-03T05:30:00', ['Close Scrutiny'], map => 'spaceport');

  like($output, qr/^Event 'Close Scrutiny' found, but not on map 'spaceport':$/m, 'says found, but not on map');
  like($output, qr/^  Close Scrutiny \(Dam\)$/m, 'lists the map of the event');
  unlike($output, qr/Schedule \(UTC\)|not found\./, 'no detail view, no not-found');
};

subtest 'Event command - unknown event' => sub {
  my $output = event_output('2026-11-03T05:30:00', ['Cold Snap']);
  is($output, "Event 'Cold Snap' not found.\n", 'Cold Snap does not exist in the live schedule');
};

subtest 'Event command - no argument shows usage' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Event;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Event->new();

  my $output = capture_stdout {
    $cmd->execute([], [$cli]);
  };

  like($output, qr/Usage:/i, 'shows usage message');
};

subtest 'Item command - JSON output' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Item;

  my $cli = mock_cli();
  $cli->{json} = 1;
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Item->new();

  my $output = capture_stdout {
    $cmd->execute(['adrenaline-shot'], [$cli]);
  };

  like($output, qr/^\{/, 'starts with {');
  like($output, qr/"name"/, 'has name field');

  require JSON::MaybeXS;
  my $data = eval { JSON::MaybeXS::decode_json($output) };
  ok(!$@, 'valid JSON') or diag("JSON error: $@");
};

subtest 'Quest command - JSON output' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Quest;

  my $cli = mock_cli();
  $cli->{json} = 1;
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Quest->new();

  my $output = capture_stdout {
    $cmd->execute(['a-bad-feeling'], [$cli]);
  };

  like($output, qr/^\{/, 'starts with {');
  like($output, qr/"name"/, 'has name field');

  require JSON::MaybeXS;
  my $data = eval { JSON::MaybeXS::decode_json($output) };
  ok(!$@, 'valid JSON') or diag("JSON error: $@");
};

done_testing;
