use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use File::Temp qw(tempdir);
use MockUA;
use WWW::MetaForge::ArcRaiders;

# karr k12: MockUA must not serve gated relations when the query param that
# unlocks them is missing, so a forgotten includeComponents/includeLoot
# fails offline.
my $api = WWW::MetaForge::ArcRaiders->new(
  ua        => MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures"),
  cache_dir => tempdir(CLEANUP => 1),
  use_cache => 0,
);

my ($with)    = grep { $_->id eq 'adrenaline-shot' } @{ $api->items(includeComponents => 'true') };
my ($without) = grep { $_->id eq 'adrenaline-shot' } @{ $api->items() };
ok(@{ $with->components } > 0, 'components present with includeComponents=true');
is(scalar @{ $without->components },         0, 'components stripped without the param');
is(scalar @{ $without->recycle_components }, 0, 'recycle_components stripped without the param');
is(scalar @{ $without->sold_by },            0, 'sold_by stripped without the param');

my ($arc_with)    = grep { $_->id eq 'arc-assessor' } @{ $api->arcs(includeLoot => 'true') };
my ($arc_without) = grep { $_->id eq 'arc-assessor' } @{ $api->arcs() };
ok(@{ $arc_with->loot } > 0, 'loot present with includeLoot=true');
is(scalar @{ $arc_without->loot }, 0, 'loot stripped without the param');

done_testing;
