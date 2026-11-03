package WWW::MetaForge::ArcRaiders::CLI::Cmd::Trials;
# ABSTRACT: Show the weekly trials from the ARC Raiders API
our $VERSION = '0.003';
use Moo;
use MooX::Cmd;
use MooX::Options;
use JSON::MaybeXS;
use POSIX qw(strftime);

option catalog => (
  is    => 'ro',
  short => 'c',
  doc   => 'List the catalog of trials that are not scheduled',
);

sub execute {
  my ($self, $args, $chain) = @_;
  my $app = $chain->[0];

  my $trials = $app->api->weekly_trials;
  my $window = $app->api->weekly_trials_window;

  my @active   = grep { $_->is_active } @$trials;
  my @upcoming = grep { $_->upcoming } @$trials;
  my @catalog  = grep { !$_->is_active && !$_->upcoming } @$trials;

  if ($app->json) {
    my @shown = $self->catalog ? @catalog : ( @active, @upcoming );
    print JSON::MaybeXS->new(utf8 => 1, pretty => 1, canonical => 1)->encode(
      { %{ $window->_raw }, data => [ map { $_->_raw } @shown ] }
    );
    return;
  }

  if ($self->catalog) {
    printf "%-55s  [%s]\n", $_->name, $_->trial_id for @catalog;
    printf "\n%d catalog trial(s) found.\n", scalar @catalog;
    return;
  }

  printf "Active, until %s:\n", _when($window->active_window_end);
  _print_trials(\@active);

  printf "\nUpcoming, from %s:\n", _when($window->next_window_start);
  _print_trials(\@upcoming);
}

sub _print_trials {
  my ($trials) = @_;

  unless (@$trials) {
    print "  (none)\n";
    return;
  }

  for my $trial (@$trials) {
    my $line = $trial->name;
    $line = sprintf('%-55s  %s', $line, join(', ', $trial->map_names->@*)) if $trial->map_names->@*;
    print "  $line\n";
  }
}

# "2026-11-03 10:00 UTC (in 5h 1m)"
sub _when {
  my ($epoch) = @_;
  my $when  = strftime('%Y-%m-%d %H:%M UTC', gmtime $epoch);
  my $delta = $epoch - time;
  return $when if $delta <= 0;
  my $minutes = int($delta / 60);
  my ($d, $h, $m) = (int($minutes / 1440), int($minutes % 1440 / 60), $minutes % 60);
  my $in = $d ? "${d}d ${h}h" : $h ? "${h}h ${m}m" : "${m}m";
  return "$when (in $in)";
}

1;

=head1 SYNOPSIS

  # Active and upcoming weekly trials
  arcraiders trials

  # The catalog of trials that are not scheduled
  arcraiders trials --catalog
  arcraiders trials -c

  # Output as JSON
  arcraiders --json trials

=head1 DESCRIPTION

Shows the weekly trials from the ARC Raiders API: the trials of the running
window with the time it ends, and the trials of the next window with the time
it starts. A trial bound to a map shows the map name. Times are UTC.

When the C<--json> flag (inherited from the parent command) is set, the
output keeps the shape of the API response: the window times and a C<data>
list with the raw entries the command would show.

=head1 OPTIONS

=head2 --catalog, -c

List the catalog instead: the trials the API knows but has not scheduled,
with name and trial id.

=method execute

  $cmd->execute($args, $chain);

Executes the trials command. Takes no arguments.

=cut
