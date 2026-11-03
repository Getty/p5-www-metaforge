package WWW::MetaForge::ArcRaiders::CLI::Cmd::Ermal;
# ABSTRACT: Show Ermal's offers and permanent services
our $VERSION = '0.003';
use Moo;
use MooX::Cmd;
use MooX::Options;
use JSON::MaybeXS;

sub execute {
  my ($self, $args, $chain) = @_;
  my $app = $chain->[0];

  my $ermal = $app->api->ermal;

  unless ($ermal) {
    print "No Ermal data in the traders response.\n";
    return;
  }

  if ($app->json) {
    print JSON::MaybeXS->new(utf8 => 1, pretty => 1)->encode($ermal->_raw);
    return;
  }

  _print_ermal($ermal);
}

sub _print_ermal {
  my ($ermal) = @_;

  print "=" x 60, "\n";
  print "Ermal\n";
  print "=" x 60, "\n";

  _print_field("Synced", $ermal->synced_at);

  my $offers = $ermal->offers;
  printf "\nOffers (%d):\n", scalar @$offers;
  for my $offer (@$offers) {
    printf "\n  %s\n", $offer->{offer_title};
    my $item = $offer->{item};
    _print_field("    Item", sprintf('%s [%s]', $item->{name}, $item->{item_type})) if $item;
    _print_field("    Cost", $offer->{coin_cost} . ' coins');
    _print_field("    Runs", $offer->{offer_start} . ' - ' . $offer->{offer_end});
    _print_accepted($offer->{accepted_items});
  }

  my $services = $ermal->permanent_services;
  printf "\nPermanent Services (%d):\n", scalar @$services;
  for my $service (@$services) {
    printf "\n  %s\n", $service->{name};
    _print_field("    Cost", $service->{coin_cost} . ' coins');
    _print_accepted($service->{accepted_items});
    if (defined $service->{description} && length $service->{description}) {
      (my $desc = $service->{description}) =~ s/\A\s+|\s+\z//g;
      $desc =~ s/\s+/ /g;
      $desc =~ s/(.{1,54})(?:\s|\z)/    $1\n/g;  # Word wrap
      print $desc;
    }
  }
}

# Offer entries carry an amount; category entries ("Any Firearm") and
# service entries do not.
sub _print_accepted {
  my ($accepted) = @_;
  return unless $accepted && @$accepted;
  my @lines = ('');
  for my $entry (@$accepted) {
    my $name = defined $entry->{amount} ? $entry->{amount} . 'x ' . $entry->{name} : $entry->{name};
    push @lines, '' if length $lines[-1] && length($lines[-1]) + length($name) > 40;
    $lines[-1] .= length $lines[-1] ? ', ' . $name : $name;
  }
  _print_field("    Accepts", shift @lines);
  printf "%-17s %s\n", '', $_ for @lines;
}

sub _print_field {
  my ($label, $value) = @_;
  return unless defined $value;
  printf "%-17s %s\n", "$label:", $value;
}

1;

=head1 SYNOPSIS

  # Show Ermal's offers and permanent services
  arcraiders ermal

  # Output as JSON
  arcraiders --json ermal

=head1 DESCRIPTION

Shows Ermal, whom the ARC Raiders API lists in the C<ermal> section of the
traders response instead of with an item inventory.

For each time-limited offer the command prints its title, the item it hands
out, its cost in coins, when it runs and the items it accepts. For each
permanent service (e.g. "Expedition Vault") it prints the name, the cost, the
accepted items and the description.

When the C<--json> flag (inherited from the parent command) is set, the raw
C<ermal> section is printed as JSON instead of the formatted display.

=method execute

  $cmd->execute($args, $chain);

Executes the ermal command. Takes no arguments.

=cut
