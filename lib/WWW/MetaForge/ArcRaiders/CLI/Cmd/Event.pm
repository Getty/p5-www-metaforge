package WWW::MetaForge::ArcRaiders::CLI::Cmd::Event;
# ABSTRACT: Show details for a single event timer

use Moo;
use JSON::MaybeXS;
use Getopt::Long qw(:config pass_through);
use namespace::clean;
use MooX::Cmd;

sub execute {
  my ($self, $args, $chain) = @_;
  my $app = $chain->[0];

  local @ARGV = @$args;
  my $map_filter;
  GetOptions(
    'map|m=s' => \$map_filter,
  );

  my $event_name = $ARGV[0];
  unless ($event_name) {
    print "Usage: arcraiders event <name> [--map <map>]\n";
    print "Example: arcraiders event \"Cold Snap\" --map dam\n";
    return;
  }

  # Events don't have IDs, so search by name (and optionally map)
  my $events = $app->api->event_timers;

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

  # Filter by map if specified
  if ($map_filter && @matches) {
    @matches = grep {
      $_->map && lc($_->map) eq lc($map_filter)
    } @matches;
  }

  my $event;
  if (@matches == 1) {
    $event = $matches[0];
  } elsif (@matches > 1) {
    print "Multiple events match '$event_name':\n";
    for my $m (@matches) {
      printf "  %s (%s)\n", $m->name // 'Unknown', $m->map // 'all';
    }
    print "\nUse --map to specify: arcraiders event \"$event_name\" --map <map>\n";
    return;
  }

  unless ($event) {
    print "Event '$event_name' not found.\n";
    return;
  }

  if ($app->json) {
    print JSON::MaybeXS->new(utf8 => 1, pretty => 1)->encode($event->_raw);
    return;
  }

  _print_event_details($event);
}

sub _print_event_details {
  my ($event) = @_;

  print "=" x 60, "\n";
  printf "%s\n", $event->name // 'Unknown';
  print "=" x 60, "\n";

  _print_field("Map",  $event->map // 'All Maps');
  _print_field("Game", $event->game);
  _print_field("Icon", $event->icon);

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

  if ($event->description) {
    print "\nDescription:\n";
    my $desc = $event->description;
    $desc =~ s/(.{1,58})\s/$1\n  /g;  # Word wrap
    print "  $desc\n";
  }

  if ($event->times && @{$event->times}) {
    print "\nSchedule:\n";
    my @sorted = sort { $a->{start} cmp $b->{start} } @{$event->times};
    for my $slot (@sorted) {
      my $start = $slot->{start} // '?';
      my $end   = $slot->{end} // '?';
      printf "  %s - %s\n", $start, $end;
    }
  }

  if ($event->days && @{$event->days}) {
    _print_field("Days", join(", ", @{$event->days}));
  } else {
    _print_field("Days", "Every day");
  }
}

sub _print_field {
  my ($label, $value) = @_;
  return unless defined $value;
  printf "%-15s %s\n", "$label:", $value;
}

1;

=head1 SYNOPSIS

  arcraiders event "Cold Snap" --map dam
  arcraiders event harvester -m spaceport

=head1 DESCRIPTION

Shows detailed information for a single event timer from the ARC Raiders database.

Accepts event name (exact or partial match). Use C<--map> to disambiguate
when an event exists on multiple maps.

=head1 OPTIONS

=over 4

=item --map, -m

Filter by map name (e.g., dam, spaceport, buried-city).

=back

=cut
