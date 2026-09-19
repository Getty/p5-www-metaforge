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
  my $items = $app->api->items(search => $slug);

  # If no results, try converting slug to search term (ferro-i -> ferro)
  if (!@$items && $slug =~ /-/) {
    my $search_term = $slug;
    $search_term =~ s/-[ivx]+$//i;  # Remove roman numeral suffix
    $search_term =~ s/-/ /g;        # Replace dashes with spaces
    $items = $app->api->items(search => $search_term) if $search_term ne $slug;
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

  _print_item_details($item);
}

sub _print_item_details {
  my ($item) = @_;

  print "=" x 60, "\n";
  printf "%s\n", $item->name // 'Unknown';
  print "=" x 60, "\n";

  _print_field("ID",          $item->id);
  _print_field("Category",    $item->item_type);
  _print_field("Rarity",      $item->rarity);
  _print_field("Weight",      $item->weight);
  _print_field("Stack Size",  $item->stack_size);
  _print_field("Base Value",  $item->value);

  if ($item->description) {
    print "\nDescription:\n";
    print "  ", $item->description, "\n";
  }

  if ($item->stat_block && %{$item->stat_block}) {
    print "\nStats:\n";
    for my $key (sort keys %{$item->stat_block}) {
      printf "  %-30s %s\n", $key, $item->stat_block->{$key} // '-';
    }
  }

  if ($item->components && @{$item->components}) {
    print "\nCrafting Requirements:\n";
    for my $req (@{$item->components}) {
      my $component = $req->{component};
      my $name = ref($component) eq 'HASH' ? $component->{name} : $component;
      my $qty  = $req->{quantity} // 1;
      printf "  %dx %s\n", $qty, $name // 'Unknown';
    }
  }

  if ($item->sold_by && @{$item->sold_by}) {
    print "\nSold By:\n";
    for my $seller (@{$item->sold_by}) {
      printf "  %s (%s)\n", $seller->{trader_name} // 'Unknown', $seller->{price} // '-';
    }
  }

  if ($item->recycle_components && @{$item->recycle_components}) {
    print "\nRecycle Yield:\n";
    for my $req (@{$item->recycle_components}) {
      my $component = $req->{component};
      my $name = ref($component) eq 'HASH' ? $component->{name} : $component;
      my $qty  = $req->{quantity} // 1;
      printf "  %dx %s\n", $qty, $name // 'Unknown';
    }
  }

  if ($item->updated_at) {
    print "\nLast Updated: ", $item->updated_at, "\n";
  }
}

sub _print_field {
  my ($label, $value) = @_;
  return unless defined $value;
  printf "%-15s %s\n", "$label:", $value;
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

=item * Name, category, rarity

=item * Weight, stack size, base value

=item * Description and stats

=item * Crafting requirements

=item * Vendors that sell the item

=item * Recycle yield

=item * Last updated timestamp

=back

=method execute

  $cmd->execute($args, $chain);

Executes the item detail command. Takes a single argument (the item slug or ID)
and displays comprehensive information about the item. If C<--json> flag is set
in the parent application, outputs raw JSON data instead of formatted text.

=cut
