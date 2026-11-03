package WWW::MetaForge::ArcRaiders::CLI::Cmd::Arc;
# ABSTRACT: Show details for a single arc
our $VERSION = '0.003';
use Moo;
use MooX::Cmd;
use MooX::Options;
use JSON::MaybeXS;

sub execute {
  my ($self, $args, $chain) = @_;
  my $app = $chain->[0];
  $app->prepare_output;

  my $arc_id = $args->[0];
  unless ($arc_id) {
    print "Usage: arcraiders arc <id>\n";
    print "Example: arcraiders arc arc-assessor\n";
    return;
  }

  # Try fetching by ID first (API supports id= query param)
  my $result = $app->api->arcs_paginated(id => $arc_id, includeLoot => 'true');
  my $arcs = $result->{data};

  # If not found by ID, search all arcs
  if (!@$arcs) {
    $arcs = $app->api->arcs_all(includeLoot => 'true');
    my ($match) = grep {
      ($_->id && lc($_->id) eq lc($arc_id)) ||
      ($_->name && lc($_->name) eq lc($arc_id))
    } @$arcs;
    $arcs = $match ? [$match] : [];
  }

  unless (@$arcs) {
    print "Arc '$arc_id' not found.\n";
    return;
  }

  my $arc = $arcs->[0];

  if ($app->json) {
    print JSON::MaybeXS->new(pretty => 1)->encode($arc->_raw);
    return;
  }

  _print_arc_details($arc);
}

sub _print_arc_details {
  my ($arc) = @_;

  print "=" x 60, "\n";
  printf "%s\n", $arc->name // 'Unknown';
  print "=" x 60, "\n";

  _print_field("ID", $arc->id);

  my @variants = @{ $arc->data->{variants} // [] };
  _print_field("Flying", (grep { $_->{can_fly} } @variants) ? 'yes' : 'no') if @variants;

  if ($arc->description) {
    print "\nDescription:\n";
    (my $desc = $arc->description) =~ s/\A\s+|\s+\z//g;
    $desc =~ s/\s+/ /g;
    $desc =~ s/(.{1,58})(?:\s|\z)/  $1\n/g;  # Word wrap
    print $desc;
  }

  if ($arc->loot && @{$arc->loot}) {
    print "\nLoot Drops:\n";
    for my $drop (@{$arc->loot}) {
      if (ref $drop eq 'HASH') {
        my $item = $drop->{item};
        my $name = ref $item eq 'HASH' ? $item->{name} : undef;
        next unless defined $name;
        printf "  %-40s  %s\n", $name, $item->{rarity} // '-';
      }
    }
  }

  if ($arc->updated_at) {
    print "\nLast Updated: ", $arc->updated_at, "\n";
  }
}

sub _print_field {
  my ($label, $value) = @_;
  return unless defined $value;
  printf "%-15s %s\n", "$label:", $value;
}

1;

=head1 SYNOPSIS

  # Show arc details by ID
  arcraiders arc arc-assessor

  # Show arc details by name
  arcraiders arc "Bastion"

  # Output as JSON
  arcraiders --json arc arc-assessor

=head1 DESCRIPTION

This command displays detailed information about a single arc, an ARC enemy
type (e.g. "ARC Assessor", "Bastion", "Bombardier") from the Arc Raiders API.
You can search by either the arc's ID or name.

The command first attempts to find the arc by ID. If no match is found, it
searches through all arcs by both ID and name (case-insensitive).

Output includes:

=over 4

=item * Name and ID

=item * Whether the ARC flies, when the API sends its variants

=item * Description text

=item * Loot drop table with the rarity of each drop

=item * Last updated timestamp

=back

If the C<--json> flag is used, outputs the raw API response as JSON instead of
the formatted display.

=cut
