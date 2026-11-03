package WWW::MetaForge::ArcRaiders::CLI::Cmd::Hideout;
# ABSTRACT: List hideout stations or show one with its upgrade levels
our $VERSION = '0.003';
use Moo;
use MooX::Cmd;
use MooX::Options;
use JSON::MaybeXS;

sub execute {
  my ($self, $args, $chain) = @_;
  my $app = $chain->[0];
  $app->prepare_output;

  my $stations = $app->api->hideout;
  my $name = $args->[0];

  return _list_stations($app, $stations) unless defined $name && length $name;

  # The API has no single-station endpoint; match id or name, case-insensitively.
  my ($station) = grep { lc($_->id) eq lc($name) || lc($_->name) eq lc($name) } @$stations;

  unless ($station) {
    print "Hideout station '$name' not found.\n";
    if (@$stations) {
      print "\nAvailable stations:\n";
      printf "  %-20s  [%s]\n", $_->name, $_->id for @$stations;
    }
    return;
  }

  if ($app->json) {
    print JSON::MaybeXS->new(pretty => 1, canonical => 1)->encode($station->_raw);
    return;
  }

  _print_station($station);
}

sub _list_stations {
  my ($app, $stations) = @_;

  if ($app->json) {
    print JSON::MaybeXS->new(pretty => 1, canonical => 1)->encode(
      [ map { $_->_raw } @$stations ]
    );
    return;
  }

  if (!@$stations) {
    print "No hideout stations found.\n";
    return;
  }

  for my $station (@$stations) {
    printf "%-25s  %-20s  %d levels\n", $station->name, '[' . $station->id . ']', $station->max_level;
  }

  printf "\n%d station(s) found.\n", scalar @$stations;
}

sub _print_station {
  my ($station) = @_;

  print "=" x 60, "\n";
  printf "%s\n", $station->name;
  print "=" x 60, "\n";

  _print_field("ID", $station->id);
  _print_field("Max Level", $station->max_level);

  for my $level ($station->levels->@*) {
    printf "\nLevel %d\n", $level->number;
    my $unlock   = $level->unlock_requirements;
    my $required = $level->required_items;
    my $crafts   = $level->crafts;
    _print_field("  Unlock", join(', ', map { $_->{quantity} . ' ' . $_->{id} } @$unlock)) if @$unlock;
    _print_field("  Requires", join(', ', map { $_->{quantity} . 'x ' . $_->{id} } @$required)) if @$required;
    _print_field("  Crafts", join(', ', @$crafts)) if @$crafts;
    print "  (nothing required)\n" unless @$unlock || @$required || @$crafts;
  }
}

sub _print_field {
  my ($label, $value) = @_;
  return unless defined $value;
  printf "%-15s %s\n", "$label:", $value;
}

1;

=head1 SYNOPSIS

  # List the hideout stations
  arcraiders hideout

  # Show one station with what each upgrade level takes
  arcraiders hideout gunsmith
  arcraiders hideout weapon-bench

  # Output as JSON
  arcraiders --json hideout
  arcraiders --json hideout scrappy

=head1 DESCRIPTION

Without an argument, lists the stations of the ARC Raiders hideout (crafting
benches, Scrappy and the Outpost) with their id and number of levels.

With a station id or name (matched case-insensitively), shows that station
level by level: what unlocks the level, the items the upgrade takes and the
items the level adds to the crafting list. Items are shown by their item id,
as the API sends them. When the name does not match, the available stations
are listed.

When the C<--json> flag (inherited from the parent command) is set, the raw
API data is printed as JSON instead of the formatted display.

=method execute

  $cmd->execute($args, $chain);

Executes the hideout command. Takes an optional station id or name.

=cut
