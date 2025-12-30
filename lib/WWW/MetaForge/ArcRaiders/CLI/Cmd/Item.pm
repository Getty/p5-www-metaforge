package WWW::MetaForge::ArcRaiders::CLI::Cmd::Item;
# ABSTRACT: Show details for a single item

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

  # Find exact match by slug or id first
  my ($item) = grep {
    ($_->slug && lc($_->slug) eq lc($slug)) ||
    ($_->id && lc($_->id) eq lc($slug))
  } @$items;

  unless ($item) {
    if (@$items == 1) {
      $item = $items->[0];
    } elsif (@$items > 1) {
      print "Multiple items match '$slug':\n";
      for my $m (@$items) {
        printf "  %s [%s]\n", $m->name // 'Unknown', $m->slug // $m->id // '-';
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

  _print_field("ID",          $item->slug // $item->id);
  _print_field("Category",    $item->category);
  _print_field("Rarity",      $item->rarity);
  _print_field("Weight",      $item->weight);
  _print_field("Stack Size",  $item->stack_size);
  _print_field("Base Value",  $item->base_value);

  if ($item->description) {
    print "\nDescription:\n";
    print "  ", $item->description, "\n";
  }

  if ($item->stats && %{$item->stats}) {
    print "\nStats:\n";
    for my $key (sort keys %{$item->stats}) {
      printf "  %-30s %s\n", $key, $item->stats->{$key} // '-';
    }
  }

  if ($item->crafting_requirements && @{$item->crafting_requirements}) {
    print "\nCrafting Requirements:\n";
    for my $req (@{$item->crafting_requirements}) {
      my $name = $req->{item} // $req->{name} // 'Unknown';
      my $qty  = $req->{quantity} // $req->{amount} // 1;
      printf "  %dx %s\n", $qty, $name;
    }
  }

  if ($item->sold_by && @{$item->sold_by}) {
    print "\nSold By:\n";
    for my $seller (@{$item->sold_by}) {
      if (ref $seller eq 'HASH') {
        printf "  %s\n", $seller->{name} // $seller->{trader} // 'Unknown';
      } else {
        printf "  %s\n", $seller;
      }
    }
  }

  if ($item->recycle_yield && %{$item->recycle_yield}) {
    print "\nRecycle Yield:\n";
    for my $mat (sort keys %{$item->recycle_yield}) {
      printf "  %dx %s\n", $item->recycle_yield->{$mat}, $mat;
    }
  }

  if ($item->last_updated) {
    print "\nLast Updated: ", $item->last_updated, "\n";
  }
}

sub _print_field {
  my ($label, $value) = @_;
  return unless defined $value;
  printf "%-15s %s\n", "$label:", $value;
}

1;
