package WWW::MetaForge::ArcRaiders::Result::EventTimer;
# ABSTRACT: Event timer/schedule result object

use Moo;
use Types::Standard qw(Str Int ArrayRef HashRef Maybe);
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

# Schedule times - array of {start: "HH:MM", end: "HH:MM"}
has times => (
  is      => 'ro',
  isa     => ArrayRef[HashRef],
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

  return $class->new(
    name        => $data->{name},
    map         => $data->{map},
    game        => $data->{game},
    icon        => $data->{icon},
    description => $data->{description},
    times       => $data->{times} // [],
    days        => $data->{days} // [],
    _raw        => $data,
  );
}

# Check if event is currently active based on current time
sub is_active_now {
  my ($self) = @_;
  my ($sec, $min, $hour) = localtime;
  my $now = sprintf("%02d:%02d", $hour, $min);

  for my $slot ($self->times->@*) {
    my $start = $slot->{start} // next;
    my $end = $slot->{end} // next;

    # Handle overnight events (e.g., 23:00 - 00:00)
    if ($end lt $start) {
      return 1 if $now ge $start || $now lt $end;
    } else {
      return 1 if $now ge $start && $now lt $end;
    }
  }
  return 0;
}

# Get next scheduled time slot
sub next_time {
  my ($self) = @_;
  my ($sec, $min, $hour) = localtime;
  my $now = sprintf("%02d:%02d", $hour, $min);

  my @sorted = sort { $a->{start} cmp $b->{start} } $self->times->@*;

  # Find next slot after now
  for my $slot (@sorted) {
    return $slot if ($slot->{start} // '') gt $now;
  }

  # Wrap around to first slot tomorrow
  return $sorted[0] if @sorted;
  return undef;
}

# Get current active time slot
sub _current_slot {
  my ($self) = @_;
  my ($sec, $min, $hour) = localtime;
  my $now = sprintf("%02d:%02d", $hour, $min);

  for my $slot ($self->times->@*) {
    my $start = $slot->{start} // next;
    my $end = $slot->{end} // next;

    if ($end lt $start) {
      return $slot if $now ge $start || $now lt $end;
    } else {
      return $slot if $now ge $start && $now lt $end;
    }
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

# Calculate minutes between two HH:MM times
sub _minutes_between {
  my ($self, $from, $to) = @_;
  my ($from_h, $from_m) = split /:/, $from;
  my ($to_h, $to_m) = split /:/, $to;

  my $from_mins = $from_h * 60 + $from_m;
  my $to_mins = $to_h * 60 + $to_m;

  my $diff = $to_mins - $from_mins;
  $diff += 24 * 60 if $diff < 0;  # wrap around midnight
  return $diff;
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
  my ($sec, $min, $hour) = localtime;
  my $now = sprintf("%02d:%02d", $hour, $min);
  return $self->_minutes_between($now, $next->{start});
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
  my $slot = $self->_current_slot or return undef;
  my ($sec, $min, $hour) = localtime;
  my $now = sprintf("%02d:%02d", $hour, $min);
  return $self->_minutes_between($now, $slot->{end});
}

1;

=head1 SYNOPSIS

  my $events = $api->event_timers;
  for my $event (@$events) {
      say $event->name;
      say "  Active!" if $event->is_active_now;
      if (my $next = $event->next_time) {
          say "  Next: $next->{start} - $next->{end}";
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

ArrayRef of time slots: C<[{ start => "HH:MM", end => "HH:MM" }]>.

=attr days

ArrayRef of days when event occurs. Empty means every day.

=method from_hashref

  my $event = WWW::MetaForge::ArcRaiders::Result::EventTimer->from_hashref(\%data);

Construct from API response.

=method is_active_now

  if ($event->is_active_now) { ... }

Returns true if current time is within a scheduled time slot.
Handles overnight events (e.g., 23:00-01:00).

=method next_time

  my $slot = $event->next_time;
  say "Starts at $slot->{start}" if $slot;

Returns next upcoming time slot as HashRef, or undef if none scheduled.

=cut
