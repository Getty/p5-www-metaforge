package WWW::MetaForge::ArcRaiders::CLI::Cmd::Events;
# ABSTRACT: Show event timers from the ARC Raiders API
our $VERSION = '0.003';
use Moo;
use MooX::Cmd;
use MooX::Options;
use JSON::MaybeXS;

option active => (
  is    => 'ro',
  short => 'a',
  doc   => 'Show only currently active events',
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

  my $events = $app->api->event_timers(
    defined $self->region ? ( region => $self->region ) : (),
  );

  if ($self->active) {
    $events = [ grep { $_->is_active_now } @$events ];
  }

  # Sort chronologically: active events first (by time until end), then upcoming (by time until start)
  $events = [
    sort {
      my $a_active = $a->is_active_now;
      my $b_active = $b->is_active_now;

      # Active events come first
      return -1 if $a_active && !$b_active;
      return 1 if !$a_active && $b_active;

      # Both active: sort by time until end
      if ($a_active) {
        return ($a->minutes_until_end // 9999) <=> ($b->minutes_until_end // 9999);
      }

      # Both inactive: sort by time until start
      return ($a->minutes_until_start // 9999) <=> ($b->minutes_until_start // 9999);
    } @$events
  ];

  if ($app->json) {
    print JSON::MaybeXS->new(pretty => 1, canonical => 1)->encode(
      [ map { $_->_raw } @$events ]
    );
    return;
  }

  if (!@$events) {
    print "No events found.\n";
    return;
  }

  for my $event (@$events) {
    my $name   = $event->name // 'Unknown';
    my $map    = $event->map // '';
    my $status = $event->is_active_now ? '[ACTIVE]' : '';
    my $time_info = '';

    if ($event->is_active_now) {
      my $remaining = $event->time_until_end;
      $time_info = "ends in $remaining" if $remaining;
    } else {
      my $until = $event->time_until_start;
      $time_info = "in $until" if $until;
    }

    # only region=all records carry a region
    my $region = defined $event->region ? sprintf('%-13s  ', $event->region) : '';

    printf "%-30s  %-15s  %s%-10s  %s\n", $name, $map, $region, $status, $time_info;
  }

  printf "\n%d event(s) found.\n", scalar(@$events);
}

1;

=head1 SYNOPSIS

  metaforge-arcraiders events
  metaforge-arcraiders events --active
  metaforge-arcraiders events -a

  # Schedule of another server region, or of all regions
  metaforge-arcraiders events --region north-america
  metaforge-arcraiders events -r all

  # JSON output
  metaforge-arcraiders --json events

=head1 DESCRIPTION

This command displays event timers from the ARC Raiders API. Events are shown
in chronological order: currently active events appear first (sorted by time
remaining until end), followed by upcoming events (sorted by time until start).

For each event, the output displays:

=over 4

=item * Event name

=item * Map name (if available)

=item * Server region, with C<--region all> only

=item * Status indicator C<[ACTIVE]> for running events

=item * Time information (either "ends in X" or "in X")

=back

=head1 OPTIONS

=head2 --active, -a

Show only currently active events. This filters out upcoming events that
haven't started yet.

=head2 --region, -r

Server region of the schedule, passed to the API unchanged. Each region has
its own schedule. Without C<--region> no region is sent and the API default
applies, C<europe>.
Values seen from the live API: C<europe>, C<north-america>, C<oceania>,
C<east-asia>, C<brazil> and C<all>. The API answers an unknown region with
the C<europe> schedule, without an error.

C<all> lists every event once per region and map, with the region in its own
column.

  metaforge-arcraiders events --region north-america
  metaforge-arcraiders events -r all

=cut
