package WWW::MetaForge::ArcRaiders::CLI::Cmd::Trader;
# ABSTRACT: Show details for a single trader
our $VERSION = '0.003';
use Moo;
use MooX::Cmd;
use MooX::Options;
use JSON::MaybeXS;

sub execute {
  my ($self, $args, $chain) = @_;
  my $app = $chain->[0];

  my $name = $args->[0];
  unless (defined $name && length $name) {
    print "Usage: arcraiders trader <name>\n";
    print "Example: arcraiders trader Apollo\n";
    return;
  }

  # The API has no single-trader endpoint; fetch the trader list (keyed by
  # name) and match by name, case-insensitively.
  my $traders = $app->api->traders;
  my ($trader) = grep { lc($_->name) eq lc($name) } @$traders;

  unless ($trader) {
    print "Trader '$name' not found.\n";
    if (@$traders) {
      print "\nAvailable traders:\n";
      printf "  %s\n", $_->name for @$traders;
    }
    return;
  }

  if ($app->json) {
    print JSON::MaybeXS->new(utf8 => 1, pretty => 1)->encode($trader->_raw);
    return;
  }

  _print_trader_details($trader);
}

sub _print_trader_details {
  my ($trader) = @_;

  print "=" x 60, "\n";
  printf "%s\n", $trader->name // 'Unknown';
  print "=" x 60, "\n";

  my $inventory = $trader->inventory;
  printf "Inventory: %d item(s)\n", scalar @$inventory;

  if (@$inventory) {
    print "\n";
    for my $item (@$inventory) {
      my $iname  = $item->{name} // 'Unknown';
      my $rarity = $item->{rarity} // '-';
      my $price  = $item->{trader_price} // '-';
      printf "  %-40s  %-10s  %s\n", $iname, $rarity, $price;
    }
  }
}

1;

=head1 SYNOPSIS

  # Show a single trader and its inventory
  arcraiders trader Apollo

  # Output as JSON
  arcraiders --json trader Apollo

=head1 DESCRIPTION

Shows details for a single trader: the trader name and its inventory (item
name, rarity and trader price).

The ARC Raiders API has no single-trader endpoint, so the command fetches the
full trader list and matches the given name case-insensitively. When the name
does not match, the available trader names are listed.

When the C<--json> flag (inherited from the parent command) is set, the raw
trader data is printed as JSON instead of the formatted display.

=method execute

  $cmd->execute($args, $chain);

Executes the trader command. Takes the trader name as its single argument.

=cut
