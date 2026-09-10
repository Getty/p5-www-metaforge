package WWW::MetaForge::ArcRaiders::CLI::Cmd::Map;
# ABSTRACT: Show map markers for a single ARC Raiders map
our $VERSION = '0.003';
use Moo;
use MooX::Cmd;
use MooX::Options;
use JSON::MaybeXS;

option type => (
  is     => 'ro',
  format => 's',
  short  => 't',
  doc    => 'Filter markers by category or category/subcategory (substring match)',
);

sub execute {
  my ($self, $args, $chain) = @_;
  my $app = $chain->[0];

  my $map_id = $args->[0];
  unless (defined $map_id && length $map_id) {
    print "Usage: arcraiders map <map-id>\n";
    print "Example: arcraiders map dam\n";
    print "\nAvailable maps:\n";
    for my $m ($app->api->maps) {
      printf "  %-15s %s\n", $m, $app->api->map_display_name($m);
    }
    return;
  }

  my $markers = $app->api->map_data(map => $map_id);

  # Local filter on the marker type ("category" or "category/subcategory")
  if ($self->type) {
    my $needle = lc($self->type);
    $markers = [ grep { defined $_->type && lc($_->type) =~ /\Q$needle\E/ } @$markers ];
  }

  if ($app->json) {
    print JSON::MaybeXS->new(utf8 => 1, pretty => 1)->encode(
      [ map { $_->_raw } @$markers ]
    );
    return;
  }

  if (!@$markers) {
    print "No markers found for map '$map_id'.\n";
    return;
  }

  printf "Markers for %s:\n\n", $app->api->map_display_name($map_id);
  for my $marker (@$markers) {
    my $type = $marker->type // '-';
    my $name = $marker->name;
    printf "  %-35s (%s, %s)%s\n",
      $type,
      defined $marker->x ? $marker->x : '?',
      defined $marker->y ? $marker->y : '?',
      (defined $name && length $name) ? "  $name" : '';
  }

  printf "\n%d marker(s) found.\n", scalar(@$markers);
}

1;

=head1 SYNOPSIS

  # List all markers for a map
  arcraiders map dam

  # Filter markers by type
  arcraiders map dam --type containers

  # Output as JSON
  arcraiders --json map dam

=head1 DESCRIPTION

Shows the map markers (points of interest, loot containers, ARC spawns, quest
locations, etc.) for a single ARC Raiders map, via the Game Map Data API.

The map is given as a positional argument using the API map id (e.g. C<dam>,
C<spaceport>). Running the command without an argument prints the list of
available maps.

Each marker line shows its type (C<category> or C<category/subcategory>), its
map coordinates and, where present, its instance name. Use C<--type> to filter
the markers by a category or subcategory substring.

When the C<--json> flag (inherited from the parent command) is set, the raw
marker data is printed as JSON instead of the formatted display.

=method execute

  $cmd->execute($args, $chain);

Executes the map command. Takes the map id as its single argument and prints
the markers for that map.

=cut
