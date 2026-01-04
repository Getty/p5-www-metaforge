package WWW::MetaForge::ArcRaiders::Result::EventTimer;
# ABSTRACT: Event timer/schedule result object

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

has game => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has icon => (
  is  => 'ro',
  isa => Maybe[Str],
);

has description => (
  is  => 'ro',
  isa => Maybe[Str],
);

# Schedule times - array of TimeSlot objects
has times => (
  is      => 'ro',
  isa     => ArrayRef[InstanceOf['WWW::MetaForge::ArcRaiders::Result::EventTimer::TimeSlot']],
  default => sub { [] },
);

# Days the event occurs (empty = every day)
has days => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has _raw => (
  is  => 'ro',
  isa => HashRef,
);

sub from_hashref {
  my ($class, $data) = @_;

  my @slots = map {
    WWW::MetaForge::ArcRaiders::Result::EventTimer::TimeSlot->from_hashref($_)
  } @{ $data->{times} // [] };

  return $class->new(
    name        => $data->{name},
    map         => $data->{map},
    game        => $data->{game},
    icon        => $data->{icon},
    description => $data->{description},
    times       => \@slots,
    days        => $data->{days} // [],
    _raw        => $data,
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

  # Find next slot that starts after now
  for my $slot (@sorted) {
    return $slot if $slot->start > $now;
  }

  # Wrap around to first slot tomorrow
  return $sorted[0] if @sorted;
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

Represents an event timer/schedule from the ARC Raiders game.

=attr name

Event name.

=attr map

Map where event occurs (undef if global).

=attr game

Game identifier.

=attr icon

Icon identifier for UI.

=attr description

Event description text.

=attr times

ArrayRef of L<WWW::MetaForge::ArcRaiders::Result::TimeSlot> objects.

=attr days

ArrayRef of days when event occurs. Empty means every day.

=method from_hashref

  my $event = WWW::MetaForge::ArcRaiders::Result::EventTimer->from_hashref(\%data);

Construct from API response.

=method is_active_now

  if ($event->is_active_now) { ... }

Returns true if current time is within a scheduled time slot.

=method next_time

  my $slot = $event->next_time;
  say "Starts at ", $slot->start if $slot;

Returns next upcoming TimeSlot object, or undef if none scheduled.

=method current_slot

  my $slot = $event->current_slot;
  say "Ends at ", $slot->end if $slot;

Returns currently active TimeSlot object, or undef if not active.

=method time_until_start

  my $duration = $event->time_until_start;
  say "Event starts in $duration" if $duration;

Returns human-readable duration until next event start (e.g., "2h 30m", "45m").
Returns undef if no upcoming events.

=method minutes_until_start

  my $minutes = $event->minutes_until_start;

Returns numeric minutes until next event start. Useful for sorting events.
Returns undef if no upcoming events.

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
