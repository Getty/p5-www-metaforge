#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/lib";
use Capture::Tiny qw(capture_stdout);
use URI;

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

subtest 'Event command - single event lookup' => sub {
  require WWW::MetaForge::ArcRaiders::CLI::Cmd::Event;

  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Event->new();

  my $output = capture_stdout {
    $cmd->execute(['Cold Snap'], [$cli]);
  };

  # Should find event or show not found
  ok(length($output) > 0, 'produces output');
  like($output, qr/Cold Snap|not found/i, 'shows event or not found');
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
