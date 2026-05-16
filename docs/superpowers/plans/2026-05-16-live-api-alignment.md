# Live API Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update all modules to match current MetaForge Live API. Remove old/deprecated field mappings. Update fixtures to real API responses.

**Architecture:** Align Result classes with live API field names. Drop backwards-compat mappings (`category` → `item_type`, etc.). Keep `from_hashref` for object construction. Update fixtures to real API responses.

**Tech Stack:** Perl, Moo, Test::More, MockUA

---

## File Structure

| File | Action | Purpose |
|------|--------|---------|
| `lib/WWW/MetaForge/ArcRaiders/Result/Item.pm` | MODIFY | Match live API (`item_type`, `icon`, `value`, `loadout_slots`, `workbench`, `stat_block`) |
| `lib/WWW/MetaForge/ArcRaiders/Result/Arc.pm` | MODIFY | Match live API (only `id`, `name`, `description`, `icon`, `image`, `created_at`, `updated_at`) |
| `lib/WWW/MetaForge/ArcRaiders/Result/Quest.pm` | MODIFY | Match live API (`xp`, `granted_items`, `rewards` nested structure, `trader_name`, etc.) |
| `lib/WWW/MetaForge/ArcRaiders/Result/Trader.pm` | MODIFY | Trader item hat `icon`, `trader_price` (kein `price`/`stock`) |
| `lib/WWW/MetaForge/ArcRaiders/Result/EventTimer.pm` | VERIFY | Already OK (uses `from_grouped` for raw array) |
| `lib/WWW/MetaForge/GameMapData/Result/MapMarker.pm` | VERIFY | Already OK |
| `lib/WWW/MetaForge/ArcRaiders.pm` | MODIFY | Update `@MAPS` to include `riven-tides`, `stella-montis` |
| `t/fixtures/items.json` | REPLACE | Real live API items response |
| `t/fixtures/arcs.json` | REPLACE | Real live API arcs response |
| `t/fixtures/quests.json` | REPLACE | Real live API quests response |
| `t/fixtures/traders.json` | REPLACE | Real live API traders response |
| `t/12-arcraiders-result-item.t` | MODIFY | Update to match new Item fields |
| `t/13-arcraiders-result-arc.t` | MODIFY | Update to match new Arc fields |
| `t/14-arcraiders-result-quest.t` | MODIFY | Update to match new Quest fields |
| `t/15-arcraiders-result-trader.t` | MODIFY | Update to match new Trader fields |
| `t/10-arcraiders-api.t` | MODIFY | Verify all endpoints work with live API |
| `t/11-arcraiders-request.t` | VERIFY | Endpoint URLs already correct |

---

## Live API Field Mapping

### Items (`/arc-raiders/items`)
```
Live API fields: id, name, description, item_type, loadout_slots, icon, rarity, value, workbench, stat_block{...}
Module had:      category, components, soldBy, usedIn, compatibleWith (ALL GONE from live API)
```
Stat block fields in live API: range, value, damage, health, radius, shield, weight, agility, arcStun, healing, stamina, stealth, useTime, duration, fireRate, stability, stackSize, damageMult, raiderStun, weightLimit, augmentSlots, healingSlots, magazineSize, reducedNoise, shieldCharge, backpackSlots, quickUseSlots, damagePerSecond, movementPenalty, safePocketSlots, damageMitigation, healingPerSecond, reducedEquipTime, staminaPerSecond, increasedADSSpeed, increasedFireRate, reducedReloadTime, illuminationRadius, increasedEquipTime, ...

### Arcs (`/arc-raiders/arcs`)
```
Live API fields: id, name, description, icon, image, created_at, updated_at
Module had:      type, maps, duration, cooldown, loot, xp_reward, coin_reward (ALL GONE from live API)
```
Live API returns PAGINATED basic info only - no mission/loot data anymore.

### Quests (`/arc-raiders/quests`)
```
Live API fields: id, name, objectives, xp, granted_items, created_at, updated_at, locations,
                 marker_category, image, guide_links, trader_name, sort_order, position,
                 required_items, rewards[{id, item:{id,icon,name,rarity,item_type}, item_id, quantity}]
Module had:      type, description, maps, duration, cooldown, loot, rewards (different structure!)
```
`xp` replaces `xp_reward`. `rewards` is nested `{item:{...}, quantity}` not `{item=>"Name", quantity}`.

### Traders (`/arc-raiders/traders`)
```
Live API item fields: id, icon, name, value, rarity, item_type, description, trader_price
Module had:         price, stock (NOT in live API)
```
Trader wrapper structure unchanged: `{TraderName: [items]}`

### EventTimers (`/arc-raiders/events-schedule`)
```
Live API fields: name, map, icon, startTime, endTime
Module: Already uses from_grouped() correctly
```
Structure unchanged.

### MapData (`/game-map-data`)
```
Live API fields: id, lat, lng, zlayers, mapID, category, subcategory, instanceName,
                 added_by, behindLockedDoor, last_edited_by, updated_at, eventConditionMask, lootAreas
Module: Already correct
```
Structure unchanged.

---

## Maps List Update

Current in ArcRaiders.pm:
```perl
our @MAPS = qw(dam spaceport buried-city blue-gate stella-montis);
```

Live API has: Dam, Spaceport, Buried City, Blue Gate, **Riven Tides**, **Stella Montis**

Update to:
```perl
our @MAPS = qw(dam spaceport buried-city blue-gate riven-tides stella-montis);
```

---

## Task 1: Update Item Result Class

**Files:**
- Modify: `lib/WWW/MetaForge/ArcRaiders/Result/Item.pm`
- Test: `t/12-arcraiders-result-item.t`

- [ ] **Step 1: Write the failing test**

```perl
use WWW::MetaForge::ArcRaiders::Result::Item;
use Test::More;

subtest 'from_hashref matches live API fields' => sub {
  my $live_data = {
    id => "acoustic-guitar",
    name => "Acoustic Guitar",
    description => "A playable acoustic guitar.",
    item_type => "Quick Use",
    loadout_slots => [],
    icon => "https://cdn.metaforge.app/arc-raiders/icons/acoustic-guitar.webp",
    rarity => "Legendary",
    value => 7000,
    workbench => undef,
    stat_block => {
      weight => 1,
      stackSize => 1,
      damage => 0,
    },
  };

  my $item = WWW::MetaForge::ArcRaiders::Result::Item->from_hashref($live_data);

  is($item->id, "acoustic-guitar", 'id ok');
  is($item->name, "Acoustic Guitar", 'name ok');
  is($item->item_type, "Quick Use", 'item_type ok (not category)');
  is($item->icon, "https://cdn.metaforge.app/arc-raiders/icons/acoustic-guitar.webp", 'icon ok');
  is($item->value, 7000, 'value ok (not baseValue)');
  is($item->rarity, "Legendary", 'rarity ok');
  ok($item->loadout_slots && ref $item->loadout_slots eq 'ARRAY', 'loadout_slots ok');
  is($item->workbench, undef, 'workbench ok');
  is($item->weight, 1, 'weight from stat_block ok');
  is($item->stack_size, 1, 'stack_size from stat_block ok');
  is($item->description, "A playable acoustic guitar.", 'description ok');
};

done_testing;
```

- [ ] **Step 2: Run test to verify it fails**

Run: `prove -l t/12-arcraiders-result-item.t`
Expected: FAIL - `item_type` method doesn't exist yet

- [ ] **Step 3: Rewrite Item Result class**

Replace Item.pm with new version matching live API:

```perl
package WWW::MetaForge::ArcRaiders::Result::Item;
# ABSTRACT: Item result object
our $VERSION = '0.003';
use Moo;
use Types::Standard qw(Str Int Num ArrayRef HashRef Maybe);
use namespace::clean;

has id => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has name => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has description => (
  is  => 'ro',
  isa => Maybe[Str],
);

has item_type => (
  is  => 'ro',
  isa => Maybe[Str],
);

has loadout_slots => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has icon => (
  is  => 'ro',
  isa => Maybe[Str],
);

has rarity => (
  is  => 'ro',
  isa => Maybe[Str],
);

has value => (
  is  => 'ro',
  isa => Maybe[Int],
);

has workbench => (
  is  => 'ro',
  isa => Maybe[Str],
);

has stat_block => (
  is  => 'ro',
  isa => Maybe[HashRef],
);

has weight => (
  is  => 'ro',
  isa => Maybe[Num],
);

has stack_size => (
  is  => 'ro',
  isa => Maybe[Int],
);

has _raw => (
  is  => 'ro',
  isa => HashRef,
);

sub from_hashref {
  my ($class, $data) = @_;

  my $stat = $data->{stat_block} // {};

  return $class->new(
    id            => $data->{id},
    name          => $data->{name},
    description   => $data->{description},
    item_type     => $data->{item_type},
    loadout_slots => $data->{loadout_slots} // [],
    icon          => $data->{icon},
    rarity        => $data->{rarity},
    value         => $data->{value},
    workbench     => $data->{workbench},
    stat_block    => $stat,
    weight        => $stat->{weight},
    stack_size    => $stat->{stackSize},
    _raw          => $data,
  );
}

1;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -l t/12-arcraiders-result-item.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/WWW/MetaForge/ArcRaiders/Result/Item.pm t/12-arcraiders-result-item.t
git commit -m "refactor(Item): align with live API - use item_type, value, stat_block"
```

---

## Task 2: Update Arc Result Class

**Files:**
- Modify: `lib/WWW/MetaForge/ArcRaiders/Result/Arc.pm`
- Test: `t/13-arcraiders-result-arc.t`

- [ ] **Step 1: Write the failing test**

```perl
use WWW::MetaForge::ArcRaiders::Result::Arc;
use Test::More;

subtest 'from_hashref matches live API fields' => sub {
  my $live_data = {
    id => "arc-assessor",
    name => "ARC Assessor",
    description => "ARC Assessor placeholder",
    icon => "https://cdn.metaforge.app/arc-raiders/icons/arc-assessor.webp",
    image => "https://cdn.metaforge.app/a...",
    created_at => "2026-03-31T10:13:51.34182+00:00",
    updated_at => "2026-05-05T17:44:29.733028+00:00",
  };

  my $arc = WWW::MetaForge::ArcRaiders::Result::Arc->from_hashref($live_data);

  is($arc->id, "arc-assessor", 'id ok');
  is($arc->name, "ARC Assessor", 'name ok');
  is($arc->description, "ARC Assessor placeholder", 'description ok');
  is($arc->icon, "https://cdn.metaforge.app/arc-raiders/icons/arc-assessor.webp", 'icon ok');
  is($arc->image, "https://cdn.metaforge.app/a...", 'image ok');
  is($arc->created_at, "2026-03-31T10:13:51.34182+00:00", 'created_at ok');
  is($arc->updated_at, "2026-05-05T17:44:29.733028+00:00", 'updated_at ok');
};

done_testing;
```

- [ ] **Step 2: Run test to verify it fails**

Run: `prove -l t/13-arcraiders-result-arc.t`
Expected: FAIL - new fields don't exist

- [ ] **Step 3: Rewrite Arc Result class**

```perl
package WWW::MetaForge::ArcRaiders::Result::Arc;
# ABSTRACT: Arc (mission/event) result object
our $VERSION = '0.003';
use Moo;
use Types::Standard qw(Str Maybe);
use namespace::clean;

has id => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has name => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has description => (
  is  => 'ro',
  isa => Maybe[Str],
);

has icon => (
  is  => 'ro',
  isa => Maybe[Str],
);

has image => (
  is  => 'ro',
  isa => Maybe[Str],
);

has created_at => (
  is  => 'ro',
  isa => Maybe[Str],
);

has updated_at => (
  is  => 'ro',
  isa => Maybe[Str],
);

has _raw => (
  is  => 'ro',
  isa => 'HashRef',
);

sub from_hashref {
  my ($class, $data) = @_;
  return $class->new(
    id          => $data->{id},
    name        => $data->{name},
    description => $data->{description},
    icon        => $data->{icon},
    image       => $data->{image},
    created_at  => $data->{created_at},
    updated_at  => $data->{updated_at},
    _raw        => $data,
  );
}

1;

=head1 SYNOPSIS

  my $arcs = $api->arcs;
  for my $arc (@$arcs) {
      say $arc->name;
  }

=head1 DESCRIPTION

Represents an ARC from the ARC Raiders game. Live API returns only basic
info: id, name, description, icon, image, created_at, updated_at.

=attr id

Arc identifier.

=attr name

Arc name.

=attr description

Arc description text.

=attr icon

URL to arc icon image.

=attr image

URL to arc image.

=attr created_at

ISO timestamp of creation.

=attr updated_at

ISO timestamp of last update.

=cut
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -l t/13-arcraiders-result-arc.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/WWW/MetaForge/ArcRaiders/Result/Arc.pm t/13-arcraiders-result-arc.t
git commit -m "refactor(Arc): align with live API - simplified fields"
```

---

## Task 3: Update Quest Result Class

**Files:**
- Modify: `lib/WWW/MetaForge/ArcRaiders/Result/Quest.pm`
- Test: `t/14-arcraiders-result-quest.t`

- [ ] **Step 1: Write the failing test**

```perl
use WWW::MetaForge::ArcRaiders::Result::Quest;
use Test::More;

subtest 'from_hashref matches live API fields' => sub {
  my $live_data = {
    id => "a-bad-feeling",
    name => "A Bad Feeling",
    objectives => ["Find and search any ARC Probe or ARC Courier"],
    xp => 0,
    granted_items => [],
    created_at => "2025-10-07T14:15:00.671965+00:00",
    updated_at => "2025-10-07T14:15:00.671965+00:00",
    locations => [],
    marker_category => undef,
    image => "https://cdn.metaforge.app/arc-raiders/images/a-bad-feeling.webp",
    guide_links => [{url => "https://metaforge.app/...", label => "Guide"}],
    trader_name => "Celeste",
    sort_order => 0,
    position => {x => 210, y => 800},
    required_items => [],
    rewards => [{
      id => "abc123",
      item => {
        id => "duct-tape-recipe",
        icon => "https://cdn.metaforge.app/...",
        name => "Duct Tape",
        rarity => "Uncommon",
        item_type => "Topside Material",
      },
      item_id => "duct-tape-recipe",
      quantity => "5",
    }],
  };

  my $quest = WWW::MetaForge::ArcRaiders::Result::Quest->from_hashref($live_data);

  is($quest->id, "a-bad-feeling", 'id ok');
  is($quest->name, "A Bad Feeling", 'name ok');
  is_deeply($quest->objectives, ["Find and search any ARC Probe or ARC Courier"], 'objectives ok');
  is($quest->xp, 0, 'xp ok');
  is($quest->trader_name, "Celeste", 'trader_name ok');
  is($quest->image, "https://cdn.metaforge.app/arc-raiders/images/a-bad-feeling.webp", 'image ok');
  ok(ref $quest->rewards eq 'ARRAY', 'rewards is array');
  is($quest->rewards->[0]{item}{name}, "Duct Tape", 'reward item name nested correctly');
  is($quest->rewards->[0]{quantity}, "5", 'reward quantity ok');
};

done_testing;
```

- [ ] **Step 2: Run test to verify it fails**

Run: `prove -l t/14-arcraiders-result-quest.t`
Expected: FAIL - `xp`, `trader_name`, nested `rewards` structure don't exist

- [ ] **Step 3: Rewrite Quest Result class**

```perl
package WWW::MetaForge::ArcRaiders::Result::Quest;
# ABSTRACT: Quest result object
our $VERSION = '0.003';
use Moo;
use Types::Standard qw(Str Int ArrayRef HashRef Maybe);
use namespace::clean;

has id => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has name => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has objectives => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has xp => (
  is  => 'ro',
  isa => Maybe[Int],
);

has granted_items => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has created_at => (
  is  => 'ro',
  isa => Maybe[Str],
);

has updated_at => (
  is  => 'ro',
  isa => Maybe[Str],
);

has locations => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has marker_category => (
  is  => 'ro',
  isa => Maybe[Str],
);

has image => (
  is  => 'ro',
  isa => Maybe[Str],
);

has guide_links => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has trader_name => (
  is  => 'ro',
  isa => Maybe[Str],
);

has sort_order => (
  is  => 'ro',
  isa => Maybe[Int],
);

has position => (
  is  => 'ro',
  isa => Maybe[HashRef],
);

has required_items => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has rewards => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has _raw => (
  is  => 'ro',
  isa => HashRef,
);

sub from_hashref {
  my ($class, $data) = @_;
  return $class->new(
    id              => $data->{id},
    name            => $data->{name},
    objectives      => $data->{objectives} // [],
    xp              => $data->{xp},
    granted_items   => $data->{granted_items} // [],
    created_at      => $data->{created_at},
    updated_at      => $data->{updated_at},
    locations       => $data->{locations} // [],
    marker_category => $data->{marker_category},
    image           => $data->{image},
    guide_links     => $data->{guide_links} // [],
    trader_name     => $data->{trader_name},
    sort_order      => $data->{sort_order},
    position        => $data->{position},
    required_items  => $data->{required_items} // [],
    rewards         => $data->{rewards} // [],
    _raw            => $data,
  );
}

1;

=head1 SYNOPSIS

  my $quests = $api->quests;
  for my $quest (@$quests) {
      say $quest->name;
      say "  Trader: ", $quest->trader_name if $quest->trader_name;
  }

=head1 DESCRIPTION

Represents a quest from the ARC Raiders game.

=attr id

Quest identifier.

=attr name

Quest name.

=attr objectives

ArrayRef of objective strings.

=attr xp

Experience points reward.

=attr granted_items

ArrayRef of items granted on completion.

=attr created_at

ISO timestamp of creation.

=attr updated_at

ISO timestamp of last update.

=attr locations

ArrayRef of location identifiers.

=attr marker_category

Marker category for map display.

=attr image

URL to quest image.

=attr guide_links

ArrayRef of guide links: C<[{url => "...", label => "..."}]>.

=attr trader_name

Name of the trader associated with this quest.

=attr sort_order

Sort order for quest listing.

=attr position

HashRef with C<x> and C<y> coordinates for map positioning.

=attr required_items

ArrayRef of items required to start the quest.

=attr rewards

ArrayRef of reward objects: C<[{id, item => {id, icon, name, rarity, item_type}, item_id, quantity}]>.

=cut
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -l t/14-arcraiders-result-quest.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/WWW/MetaForge/ArcRaiders/Result/Quest.pm t/14-arcraiders-result-quest.t
git commit -m "refactor(Quest): align with live API - nested rewards, trader_name, xp"
```

---

## Task 4: Update Trader Result Class

**Files:**
- Modify: `lib/WWW/MetaForge/ArcRaiders/Result/Trader.pm`
- Test: `t/15-arcraiders-result-trader.t`

- [ ] **Step 1: Write the failing test**

```perl
use WWW::MetaForge::ArcRaiders::Result::Trader;
use Test::More;

subtest 'from_hashref matches live API fields' => sub {
  my $live_data = {
    name => "Apollo",
    inventory => [{
      id => "barricade-kit",
      icon => "https://cdn.metaforge.app/arc-raiders/icons/barricade-kit.webp",
      name => "Barricade Kit",
      value => 640,
      rarity => "Uncommon",
      item_type => "Quick Use",
      description => "A deployable cover.",
      trader_price => 1920,
    }],
  };

  my $trader = WWW::MetaForge::ArcRaiders::Result::Trader->from_hashref($live_data);

  is($trader->name, "Apollo", 'name ok');
  ok(ref $trader->inventory eq 'ARRAY', 'inventory ok');
  is($trader->inventory->[0]{name}, "Barricade Kit", 'item name ok');
  is($trader->inventory->[0]{trader_price}, 1920, 'trader_price ok');
  is($trader->inventory->[0]{icon}, "https://cdn.metaforge.app/arc-raiders/icons/barricade-kit.webp", 'item icon ok');
  is($trader->inventory->[0]{rarity}, "Uncommon", 'item rarity ok');
};

done_testing;
```

- [ ] **Step 2: Run test to verify it fails**

Run: `prove -l t/15-arcraiders-result-trader.t`
Expected: FAIL - `trader_price` field handling differs

- [ ] **Step 3: Update Trader Result class**

```perl
package WWW::MetaForge::ArcRaiders::Result::Trader;
# ABSTRACT: Trader result object
our $VERSION = '0.003';
use Moo;
use Types::Standard qw(Str ArrayRef HashRef Maybe);
use namespace::clean;

has name => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has inventory => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has _raw => (
  is  => 'ro',
  isa => HashRef,
);

sub from_hashref {
  my ($class, $data) = @_;
  return $class->new(
    name      => $data->{name},
    inventory => $data->{inventory} // [],
    _raw      => $data,
  );
}

# Live API items have: id, icon, name, value, rarity, item_type, description, trader_price
sub find_item {
  my ($self, $item_name) = @_;
  for my $item ($self->inventory->@*) {
    return $item if lc($item->{name} // '') eq lc($item_name);
  }
  return undef;
}

sub has_item {
  my ($self, $item_name) = @_;
  return defined $self->find_item($item_name);
}

1;

=head1 SYNOPSIS

  my $traders = $api->traders;
  for my $trader (@$traders) {
      say $trader->name;
      if (my $item = $trader->find_item('Barricade Kit')) {
          say "  Sells ", $item->{name}, " for ", $item->{trader_price};
      }
  }

=head1 DESCRIPTION

Represents a trader NPC from the ARC Raiders game.

=attr name

Trader name (e.g., "Apollo", "TianWen").

=attr inventory

ArrayRef of items for sale. Each item has: id, icon, name, value, rarity,
item_type, description, trader_price.

=method find_item

  my $info = $trader->find_item('Barricade Kit');

Search inventory by name (case-insensitive). Returns inventory entry or undef.

=method has_item

  if ($trader->has_item('Metal Parts')) { ... }

Returns true if trader sells the named item.

=cut
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -l t/15-arcraiders-result-trader.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/WWW/MetaForge/ArcRaiders/Result/Trader.pm t/15-arcraiders-result-trader.t
git commit -m "refactor(Trader): align with live API - trader_price, icon per item"
```

---

## Task 5: Update Maps List in ArcRaiders.pm

**Files:**
- Modify: `lib/WWW/MetaForge/ArcRaiders.pm` (lines ~58-66)

- [ ] **Step 1: Verify current map IDs**

Run: `curl -s "https://metaforge.app/api/arc-raiders/events-schedule?limit=5" | python3 -c "import json,sys; d=json.load(sys.stdin); print(sorted(set(e['map'] for e in d['data'])))"`
Expected: `['Blue Gate', 'Buried City', 'Dam', 'Riven Tides', 'Spaceport', 'Stella Montis']`

- [ ] **Step 2: Update @MAPS and %MAP_DISPLAY_NAMES**

Change:
```perl
our @MAPS = qw(dam spaceport buried-city blue-gate stella-montis);
our %MAP_DISPLAY_NAMES = (
  'dam'           => 'Dam',
  'spaceport'     => 'Spaceport',
  'buried-city'   => 'Buried City',
  'blue-gate'     => 'Blue Gate',
  'stella-montis' => 'Stella Montis',
);
```

To:
```perl
our @MAPS = qw(dam spaceport buried-city blue-gate riven-tides stella-montis);
our %MAP_DISPLAY_NAMES = (
  'dam'           => 'Dam',
  'spaceport'     => 'Spaceport',
  'buried-city'   => 'Buried City',
  'blue-gate'     => 'Blue Gate',
  'riven-tides'   => 'Riven Tides',
  'stella-montis' => 'Stella Montis',
);
```

- [ ] **Step 3: Commit**

```bash
git add lib/WWW/MetaForge/ArcRaiders.pm
git commit -m "fix(maps): add riven-tides and stella-montis maps"
```

---

## Task 6: Replace Fixtures with Live API Responses

**Files:**
- Replace: `t/fixtures/items.json`
- Replace: `t/fixtures/arcs.json`
- Replace: `t/fixtures/quests.json`
- Replace: `t/fixtures/traders.json`

- [ ] **Step 1: Fetch live items fixture**

Run:
```bash
curl -s "https://metaforge.app/api/arc-raiders/items?limit=20" > t/fixtures/items.json
```

Verify: `python3 -c "import json; d=json.load(open('t/fixtures/items.json')); print(d['data'][0].keys())"`
Expected: Shows `item_type`, `stat_block`, `value` keys

- [ ] **Step 2: Fetch live arcs fixture**

Run:
```bash
curl -s "https://metaforge.app/api/arc-raiders/arcs?limit=20" > t/fixtures/arcs.json
```

Verify: `python3 -c "import json; d=json.load(open('t/fixtures/arcs.json')); print(d['data'][0].keys())"`
Expected: Shows `icon`, `image`, `created_at`, `updated_at` keys (no `type`, `maps`, `loot`)

- [ ] **Step 3: Fetch live quests fixture**

Run:
```bash
curl -s "https://metaforge.app/api/arc-raiders/quests?limit=20" > t/fixtures/quests.json
```

Verify: `python3 -c "import json; d=json.load(open('t/fixtures/quests.json')); print(d['data'][0].keys())"`
Expected: Shows `xp`, `trader_name`, `guide_links`, `rewards` structure

- [ ] **Step 4: Fetch live traders fixture**

Run:
```bash
curl -s "https://metaforge.app/api/arc-raiders/traders" > t/fixtures/traders.json
```

Verify: `python3 -c "import json; d=json.load(open('t/fixtures/traders.json')); t=list(d['data'].keys())[0]; print(list(d['data'][t][0].keys()))"`
Expected: Shows `trader_price`, `icon` keys

- [ ] **Step 5: Commit all fixtures**

```bash
git add t/fixtures/items.json t/fixtures/arcs.json t/fixtures/quests.json t/fixtures/traders.json
git commit -m "test fixtures: update to match live API responses"
```

---

## Task 7: Run Full Test Suite

**Files:**
- Run: `prove -l t/`

- [ ] **Step 1: Run all tests**

Run: `prove -l t/ 2>&1`
Expected: ALL PASS

- [ ] **Step 2: Fix any failures**

If tests fail, investigate and fix. Likely issues:
- New fields in fixtures that old test assertions don't expect
- Method name changes (e.g., `category` → `item_type`)

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "test: fix test assertions after live API alignment"
```

---

## Task 8: Update EventTimer TimeSlot (verify from_grouped works with live API)

**Files:**
- Verify: `lib/WWW/MetaForge/ArcRaiders/Result/EventTimer/TimeSlot.pm`
- Verify: `t/16-arcraiders-result-event-timer.t`

- [ ] **Step 1: Check live event-timers response structure**

Run: `curl -s "https://metaforge.app/api/arc-raiders/events-schedule?limit=5" | python3 -m json.tool`
Expected: Array of `{name, map, icon, startTime, endTime}` - matches `from_grouped` expects

- [ ] **Step 2: Run event timer tests**

Run: `prove -l t/16-arcraiders-result-event-timer.t`
Expected: PASS (already correct)

- [ ] **Step 3: Commit (if any changes needed)**

---

## Task 9: Update MapMarker (verify it works with live API)

**Files:**
- Verify: `lib/WWW/MetaForge/GameMapData/Result/MapMarker.pm`
- Verify: `t/22-gamemapdata-map-marker.t`

- [ ] **Step 1: Check current fixture vs live API**

Fixture `map-data-dam.json` has: `id, lat, lng, zlayers, mapID, category, subcategory, instanceName, added_by, behindLockedDoor, last_edited_by, updated_at, eventConditionMask, lootAreas`

Live API returns same structure. No changes needed.

- [ ] **Step 2: Run map marker tests**

Run: `prove -l t/22-gamemapdata-map-marker.t`
Expected: PASS

---

## Verification Checklist

After all tasks complete:

- [ ] `prove -l t/00-load.t` - all modules load
- [ ] `prove -l t/10-arcraiders-api.t` - all endpoints work with fixtures
- [ ] `prove -l t/11-arcraiders-request.t` - request factory correct
- [ ] `prove -l t/12-arcraiders-result-item.t` - Item fields match live API
- [ ] `prove -l t/13-arcraiders-result-arc.t` - Arc fields match live API
- [ ] `prove -l t/14-arcraiders-result-quest.t` - Quest fields match live API
- [ ] `prove -l t/15-arcraiders-result-trader.t` - Trader fields match live API
- [ ] `prove -l t/16-arcraiders-result-event-timer.t` - EventTimer works
- [ ] `prove -l t/17-arcraiders-result-map-marker.t` - MapMarker works
- [ ] `USE_LIVE_API=1 prove -l t/10-arcraiders-api.t` - live API integration test
- [ ] `dzil test` - full distribution test

---

## Execution Options

**Plan complete and saved to `docs/superpowers/plans/2026-05-16-live-api-alignment.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**