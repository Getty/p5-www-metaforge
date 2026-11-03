package WWW::MetaForge::ArcRaiders::CLI::Cmd::Event;
# ABSTRACT: Show details for a single event timer
our $VERSION = '0.003';
use Moo;
use MooX::Cmd;
use MooX::Options;
use DateTime;
use JSON::MaybeXS;

option map => (
  is     => 'ro',
  format => 's',
  short  => 'm',
  doc    => 'Filter by map ID or name (e.g., dam, stella-montis, "Stella Montis")',
);

option region => (
  is     => 'ro',
  format => 's',
  short  => 'r',
  doc    => 'Server region (e.g., north-america, all); without it the API default, europe',
);

sub execute {
  my ($self, $args, $chain) = @_;
  my $app = $chain->[0];
  $app->prepare_output;

  my $event_name = $args->[0];
  unless ($event_name) {
    print "Usage: metaforge-arcraiders event <name> [--map <map>] [--region <region>]\n";
    print "Example: metaforge-arcraiders event \"Night Raid\" --map stella-montis\n";
    return;
  }

  # Events don't have IDs, so search by name (and optionally map)
  my $events = $app->api->event_timers(
    defined $self->region ? ( region => $self->region ) : (),
  );

  # Filter by name first
  my @matches = grep {
    $_->name && lc($_->name) eq lc($event_name)
  } @$events;

  # Try partial match if exact fails
  if (!@matches) {
    @matches = grep {
      $_->name && $_->name =~ /\Q$event_name\E/i
    } @$events;
  }

  # Filter by map if specified, as map ID (stella-montis) or display name
  # (Stella Montis); the API sends the display name
  if ($self->map && @matches) {
    my $map_name = lc $app->api->map_display_name($self->map);
    my @on_map = grep { lc($_->map) eq $map_name } @matches;
    unless (@on_map) {
      print "Event '$event_name' found, but not on map '" . $self->map . "':\n";
      printf "  %s (%s)\n", $_->name, join(', ', grep { defined } $_->map, $_->region) for @matches;
      return;
    }
    @matches = @on_map;
  }

  my $event;
  if (@matches == 1) {
    $event = $matches[0];
  } elsif (@matches > 1) {
    print "Multiple events match '$event_name':\n";
    for my $m (@matches) {
      printf "  %s (%s)\n", $m->name // 'Unknown', join(', ', grep { defined } $m->map // 'all', $m->region);
    }
    # with --region all the matches can differ by region only: point to the
    # option that tells them apart, keep a --map the user gave
    my %maps      = map { $_->map => 1 } @matches;
    my %regions   = map { $_->region => 1 } grep { defined $_->region } @matches;
    my $by_map    = keys %maps > 1 || keys %regions < 2;
    my $by_region = keys %regions > 1;
    my $example   = 'metaforge-arcraiders event "'.$event_name.'"'
      .( $by_map ? ' --map <map>' : defined $self->map ? ' --map "'.$self->map.'"' : '' )
      .( $by_region ? ' --region <region>' : '' );
    print "\nUse ".join(' and ', $by_map ? '--map' : (), $by_region ? '--region' : ())
      ." to specify: $example\n";
    return;
  }

  unless ($event) {
    print "Event '$event_name' not found.\n";
    return;
  }

  if ($app->json) {
    print JSON::MaybeXS->new(pretty => 1, canonical => 1)->encode($event->_raw);
    return;
  }

  _print_event_details($event);
}

sub _print_event_details {
  my ($event) = @_;

  print "=" x 60, "\n";
  printf "%s\n", $event->name // 'Unknown';
  print "=" x 60, "\n";

  _print_field("Map",    $event->map // 'All Maps');
  _print_field("Region", $event->region);
  _print_field("Icon",   $event->icon);

  # Current status
  my $status = $event->is_active_now ? "ACTIVE" : "Inactive";
  _print_field("Status", $status);

  if ($event->is_active_now) {
    my $ends_in = $event->time_until_end;
    _print_field("Ends in", $ends_in) if $ends_in;
  } else {
    my $starts_in = $event->time_until_start;
    _print_field("Starts in", $starts_in) if $starts_in;
  }

  if ($event->times && @{$event->times}) {
    print "\nSchedule (UTC):\n";
    # running and upcoming runs only; the API window starts hours in the past
    my $now    = DateTime->now(time_zone => 'UTC');
    my @sorted = sort { $a->start <=> $b->start } grep { $_->end > $now } @{$event->times};
    print "  No current or upcoming runs in the schedule window.\n" unless @sorted;
    for my $slot (@sorted) {
      printf "  %s - %s\n", $slot->start->strftime('%a %d %b %H:%M'), $slot->end->strftime('%H:%M');
    }
  }
}

sub _print_field {
  my ($label, $value) = @_;
  return unless defined $value;
  printf "%-15s %s\n", "$label:", $value;
}

1;

=head1 SYNOPSIS

  # Show details for an event by name
  metaforge-arcraiders event "Close Scrutiny"

  # Filter by specific map
  metaforge-arcraiders event "Night Raid" --map stella-montis

  # Partial name matching
  metaforge-arcraiders event "Scrutiny"

  # Schedule of another server region
  metaforge-arcraiders event "Night Raid" --map dam --region north-america

  # JSON output
  metaforge-arcraiders --json event "Close Scrutiny"

=head1 DESCRIPTION

Display detailed information about a single event timer. Searches for events by
name using exact match first, falling back to partial/case-insensitive match if
no exact match is found.

The detail view shows:

=over 4

=item * Event name and map, and the server region with C<--region all>

=item * Current status (active/inactive)

=item * Time until start or end

=item * The running and upcoming runs of the API's schedule window (about 42
hours, starting some hours in the past), one line per run with date and time
in UTC. Runs that have ended are left out; when no run is left, the schedule
says so.

=back

If multiple events match the search criteria, displays a list of matches and
suggests using C<--map> to narrow results, or C<--region> when the matches
differ only by region (C<--region all>). If the name matches but none of the
matches runs on the given map, lists the maps the matches run on.

With C<--json> the command prints the event's records as the API sent them,
every run of the window included.

=head1 OPTIONS

=head2 --map, -m

Filter results by map, as map ID (C<dam>, C<stella-montis>, see
C<metaforge-arcraiders map>) or display name (C<"Stella Montis">),
case-insensitive. Useful when the same event appears on multiple maps.

  metaforge-arcraiders event "Night Raid" --map stella-montis
  metaforge-arcraiders event "Night Raid" -m "Stella Montis"

=head2 --region, -r

Server region of the schedule, passed to the API unchanged. Each region has
its own schedule. Without C<--region> no region is sent and the API default
applies, C<europe>. Values seen from the live API: C<europe>,
C<north-america>, C<oceania>, C<east-asia>, C<brazil> and C<all>. The API
answers an unknown region with the C<europe> schedule, without an error.

With C<all> an event has one schedule per region and map; the detail view
shows the region, and the list of matches names it.

  metaforge-arcraiders event "Night Raid" --map dam --region north-america
  metaforge-arcraiders event "Night Raid" -m dam -r all

=cut
