package WWW::MetaForge::ArcRaiders::Result::EventTimer;
# ABSTRACT: Event timer/schedule result object
our $VERSION = '0.003';
use Moo;
use Types::Standard qw(Str ArrayRef HashRef Maybe InstanceOf);
use DateTime;
use WWW::MetaForge::ArcRaiders::Result::EventTimer::TimeSlot;
use namespace::clean;

has name => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has map => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has icon => (
  is  => 'ro',
  isa => Maybe[Str],
);

# Only sent per record with region=all
has region => (
  is  => 'ro',
  isa => Maybe[Str],
);

# Schedule times - array of TimeSlot objects
has times => (
  is      => 'ro',
  isa     => ArrayRef[InstanceOf['WWW::MetaForge::ArcRaiders::Result::EventTimer::TimeSlot']],
  default => sub { [] },
);

has _raw => (
  is  => 'ro',
  isa => HashRef,
);

# Build from grouped API data: the events-schedule records that share
# name+map (and region, when the records carry one). The API sends no
# grouped records, so this is the constructor instead of from_hashref.
sub from_grouped {
  my ($class, $name, $map, $events) = @_;

  my @slots = map {
    WWW::MetaForge::ArcRaiders::Result::EventTimer::TimeSlot->from_hashref($_)
  } @$events;

  # Sort slots by start time
  @slots = sort { $a->start <=> $b->start } @slots;

  return $class->new(
    name   => $name,
    map    => $map,
    icon   => $events->[0]{icon},
    region => $events->[0]{region},
    times  => \@slots,
    _raw   => { name => $name, map => $map, events => $events },
  );
}

# Check if event is currently active based on current UTC time
sub is_active_now {
  my ($self) = @_;
  my $now = DateTime->now(time_zone => 'UTC');

  for my $slot ($self->times->@*) {
    return 1 if $slot->contains($now);
  }
  return 0;
}

# Get next scheduled time slot (returns TimeSlot object)
sub next_time {
  my ($self) = @_;
  my $now = DateTime->now(time_zone => 'UTC');

  my @sorted = sort { $a->start <=> $b->start } $self->times->@*;

  # Find next slot that starts after now. The API sends absolute times for
  # a fixed window, so there is no wrap-around to an earlier slot.
  for my $slot (@sorted) {
    return $slot if $slot->start > $now;
  }

  return undef;
}

# Get current active time slot (returns TimeSlot object)
sub current_slot {
  my ($self) = @_;
  my $now = DateTime->now(time_zone => 'UTC');

  for my $slot ($self->times->@*) {
    return $slot if $slot->contains($now);
  }
  return undef;
}

# Format minutes as human-readable duration
sub _format_duration {
  my ($self, $minutes) = @_;
  return undef unless defined $minutes && $minutes >= 0;

  if ($minutes < 60) {
    return "${minutes}m";
  }
  my $hours = int($minutes / 60);
  my $mins = $minutes % 60;
  return $mins > 0 ? "${hours}h ${mins}m" : "${hours}h";
}

# Time until next event start
sub time_until_start {
  my ($self) = @_;
  my $minutes = $self->minutes_until_start;
  return defined $minutes ? $self->_format_duration($minutes) : undef;
}

# Minutes until next event start (for sorting)
sub minutes_until_start {
  my ($self) = @_;
  my $next = $self->next_time or return undef;
  return $next->minutes_until_start;
}

# Time until current active slot ends
sub time_until_end {
  my ($self) = @_;
  my $minutes = $self->minutes_until_end;
  return defined $minutes ? $self->_format_duration($minutes) : undef;
}

# Minutes until current active slot ends (for sorting)
sub minutes_until_end {
  my ($self) = @_;
  my $slot = $self->current_slot or return undef;
  return $slot->minutes_until_end;
}

1;

=head1 SYNOPSIS

  my $events = $api->event_timers;
  for my $event (@$events) {
      say $event->name;
      say "  Active!" if $event->is_active_now;
      if (my $next = $event->next_time) {
          say "  Next: ", $next->start, " - ", $next->end;
      }
  }

=head1 DESCRIPTION

Represents the schedule of one ARC Raiders event on one map. The
C</events-schedule> endpoint sends one record per scheduled run
(C<name>, C<map>, C<icon>, C<startTime>, C<endTime>, times in epoch
milliseconds UTC) for a window of about 42 hours that starts some hours in
the past. L<WWW::MetaForge::ArcRaiders/event_timers> groups the records that
share name and map, and region when the records carry one, into one
EventTimer each; every record becomes one
L<WWW::MetaForge::ArcRaiders::Result::EventTimer::TimeSlot>.

=attr name

Event name.

=attr map

Map where event occurs, as display name (C<Dam>, C<Stella Montis>).

=attr icon

URL to event icon image.

=attr region

Server region of this schedule (C<europe>, C<north-america>, C<oceania>,
C<east-asia>, C<brazil>). Set only when the records carry a C<region> field,
which the API sends only for the request parameter C<region =E<gt> 'all'>;
undef otherwise. The region of a single-region response is in the C<region>
field of the response envelope, see
L<WWW::MetaForge::ArcRaiders/event_timers_raw>.

=attr times

ArrayRef of L<WWW::MetaForge::ArcRaiders::Result::EventTimer::TimeSlot>
objects, sorted by start time. Holds every run in the schedule window,
including runs that have already ended.

=attr _raw

HashRef C<{ name, map, events }>. The API sends no grouped record, so this
hash is built by L</from_grouped>: C<name> and C<map> are those of the
group, C<events> holds the untouched records of the group in API order (with
their C<region> field, when the API sends one).

=method from_grouped

  my $event = WWW::MetaForge::ArcRaiders::Result::EventTimer->from_grouped(
    $name, $map, \@records
  );

Construct from the C</events-schedule> records that share the same name and
map (and region, when the records carry one). This is the constructor for
API data instead of C<from_hashref>, because the API sends no grouped
records. C<icon> and C<region> are read from the first record.

=method is_active_now

  if ($event->is_active_now) { ... }

Returns true if current time is within a scheduled time slot.

=method next_time

  my $slot = $event->next_time;
  say "Starts at ", $slot->start if $slot;

Returns the next TimeSlot that starts after now, or undef when no slot in
the schedule window lies ahead. The API sends absolute times, so there is no
wrap-around to an earlier slot.

=method current_slot

  my $slot = $event->current_slot;
  say "Ends at ", $slot->end if $slot;

Returns currently active TimeSlot object, or undef if not active.

=method time_until_start

  my $duration = $event->time_until_start;
  say "Event starts in $duration" if $duration;

Returns human-readable duration until next event start (e.g., "2h 30m", "45m").
Returns undef if no slot lies ahead (see L</next_time>).

=method minutes_until_start

  my $minutes = $event->minutes_until_start;

Returns numeric minutes until next event start. Useful for sorting events.
Returns undef if no slot lies ahead (see L</next_time>).

=method time_until_end

  my $duration = $event->time_until_end;
  say "Event ends in $duration" if $duration;

Returns human-readable duration until current event ends (e.g., "1h 15m").
Returns undef if event is not currently active.

=method minutes_until_end

  my $minutes = $event->minutes_until_end;

Returns numeric minutes until current active event ends. Useful for sorting.
Returns undef if event is not currently active.

=cut
