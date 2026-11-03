package WWW::MetaForge::ArcRaiders::CLI::Cmd::Item;
# ABSTRACT: Show details for a single item
our $VERSION = '0.003';
use Moo;
use MooX::Cmd;
use MooX::Options;
use JSON::MaybeXS;

sub execute {
  my ($self, $args, $chain) = @_;
  my $app = $chain->[0];

  my $slug = $args->[0];
  unless ($slug) {
    print "Usage: arcraiders item <slug>\n";
    print "Example: arcraiders item wasp-driver\n";
    return;
  }

  # Search for item - try multiple search strategies
  my $items = $app->api->items(search => $slug, includeComponents => 'true');

  # If no results, try converting slug to search term (ferro-i -> ferro)
  if (!@$items && $slug =~ /-/) {
    my $search_term = $slug;
    $search_term =~ s/-[ivx]+$//i;  # Remove roman numeral suffix
    $search_term =~ s/-/ /g;        # Replace dashes with spaces
    $items = $app->api->items(search => $search_term, includeComponents => 'true') if $search_term ne $slug;
  }

  # Find exact match by id first
  my ($item) = grep {
    ($_->id && lc($_->id) eq lc($slug))
  } @$items;

  unless ($item) {
    if (@$items == 1) {
      $item = $items->[0];
    } elsif (@$items > 1) {
      print "Multiple items match '$slug':\n";
      for my $m (@$items) {
        printf "  %s [%s]\n", $m->name // 'Unknown', $m->id // '-';
      }
      return;
    } else {
      print "Item '$slug' not found.\n";
      return;
    }
  }

  if ($app->json) {
    print JSON::MaybeXS->new(utf8 => 1, pretty => 1)->encode($item->_raw);
    return;
  }

  _print_item_details($item, $app->api);
}

sub _print_item_details {
  my ($item, $api) = @_;

  print "=" x 60, "\n";
  printf "%s\n", $item->name // 'Unknown';
  print "=" x 60, "\n";

  _print_field("ID",          $item->id);
  _print_field("Category",    $item->item_type);
  _print_field("Subcategory", $item->subcategory);
  _print_field("Rarity",      $item->rarity);
  _print_field("Weight",      $item->weight);
  _print_field("Stack Size",  $item->stack_size);
  _print_field("Base Value",  $item->value);
  _print_field("Workbench",   $item->workbench);
  _print_field("Ammo Type",   $item->ammo_type);
  _print_field("Shield Type", $item->shield_type);
  _print_field("Loot Area",   $item->loot_area);
  _print_field("Cosmetic",    $item->cosmetic->{kind});
  _print_field("Slot",        $item->cosmetic->{slot});
  _print_field("Variant Of",  $item->cosmetic->{parentName});
  _print_field("Option",      $item->cosmetic->{optionName});
  _print_field("Guide",       $item->guide_url);

  if ($item->description) {
    print "\nDescription:\n";
    print "  ", $item->description, "\n";
  }

  if ($item->flavor_text) {
    print "\nFlavor Text:\n";
    print "  ", $item->flavor_text, "\n";
  }

  if ($item->stat_block && %{$item->stat_block}) {
    print "\nStats:\n";
    for my $key (sort keys %{$item->stat_block}) {
      printf "  %-30s %s\n", $key, $item->stat_block->{$key} // '-';
    }
  }

  _print_list("Crafting Requirements",
    map { sprintf '%dx %s', $_->{quantity}, $_->{component}{name} } @{$item->components});

  _print_list("Used In",
    map { sprintf '%s (needs %dx)', $_->{item}{name}, $_->{quantity} } @{$item->used_in});

  _print_list("Sold By",
    map { sprintf '%s (%s)', $_->{trader_name}, $_->{price} } @{$item->sold_by});

  _print_list("Recycle Yield",
    map { sprintf '%dx %s', $_->{quantity}, $_->{component}{name} } @{$item->recycle_components});

  _print_list("Recycled From",
    map { sprintf '%s (yields %dx)', $_->{item}{name}, $_->{quantity} } @{$item->recycle_from});

  _print_list("Dropped By",
    map { sprintf '%s [%s]', $_->{arc}{name}, $_->{arc}{id} } @{$item->dropped_by});

  _print_list("Compatible With",
    map { $_->{mod}{name} } @{$item->mods});

  my (@maps, %spots);
  for my $location (@{$item->locations}) {
    push @maps, $location->{map} unless $spots{$location->{map}}++;
  }
  _print_list("Locations",
    map { $api->map_display_name($_) . ($spots{$_} > 1 ? " ($spots{$_} spots)" : '') } @maps);

  my @settings;
  for my $setting (@{$item->cosmetic->{settings} // []}) {
    push @settings, $setting->{name} . ': ' . join(', ', map { $_->{name} } @{$setting->{options}});
  }
  _print_list("Customization", @settings);

  _print_list("Guides",
    map { $_->{label} . ': ' . $_->{url} } @{$item->guide_links});

  if ($item->updated_at) {
    print "\nLast Updated: ", $item->updated_at, "\n";
  }
}

sub _print_field {
  my ($label, $value) = @_;
  return unless defined $value && length $value;
  printf "%-15s %s\n", "$label:", $value;
}

sub _print_list {
  my ($title, @lines) = @_;
  return unless @lines;
  print "\n$title:\n";
  print "  $_\n" for @lines;
}

1;

=head1 SYNOPSIS

  # Show details for an item by slug
  arcraiders item wasp-driver

  # Show details for an item with roman numerals
  arcraiders item ferro-i

  # Output as JSON
  arcraiders --json item wasp-driver

=head1 DESCRIPTION

This CLI command displays detailed information for a single item in Arc Raiders.
The command searches for items by slug or ID, supporting fuzzy matching for items
with roman numeral suffixes (e.g., C<ferro-i> will search for "ferro").

If multiple items match the search term, all matches are listed. If exactly one
item matches, or an exact slug/ID match is found, detailed information is displayed
including:

=over 4

=item * Name, category, subcategory, rarity

=item * Weight, stack size, base value, workbench

=item * Ammo type, shield type, loot area

=item * Cosmetic kind, slot and customization options

=item * Description, flavor text and stats

=item * Crafting requirements and the items it is used in

=item * Vendors that sell the item

=item * Recycle yield and the items that recycle into it

=item * ARCs that drop the item

=item * Compatible mods or weapons

=item * Map locations

=item * Guide links

=item * Last updated timestamp

=back

=method execute

  $cmd->execute($args, $chain);

Executes the item detail command. Takes a single argument (the item slug or ID)
and displays comprehensive information about the item. If C<--json> flag is set
in the parent application, outputs raw JSON data instead of formatted text.

=cut
