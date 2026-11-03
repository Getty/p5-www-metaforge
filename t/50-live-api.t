#!/usr/bin/env perl
# Opt-in live check of every covered endpoint. Offline suite: skipped.
#
#   WWW_METAFORGE_USE_LIVE_API=1 timeout 240 perl -Ilib -It/lib t/50-live-api.t
#
# What it catches: API drift. The Result classes are strictly typed and die
# when the API sends a field differently (the facade call fails, the
# endpoint's subtest goes red). New fields are caught by comparing the key
# paths of the live records with the byte-faithful fixtures in t/fixtures/:
# a live key the fixtures do not know is a failure (model it or skip it on
# purpose, then update the fixture); a fixture key missing live is a diag
# only, optional fields vary from page to page.
# Nothing here asserts volatile values (counts, names, window times).
use strict;
use warnings;
use Test::More;
use File::Temp qw( tempdir );
use FindBin;
use JSON::MaybeXS;
use Path::Tiny;
use List::Util qw( min );

BEGIN {
  plan skip_all => 'live API test, set WWW_METAFORGE_USE_LIVE_API=1 to run it'
    unless $ENV{WWW_METAFORGE_USE_LIVE_API};
}

use WWW::MetaForge::ArcRaiders;

my $FIXTURES     = path($FindBin::Bin)->child('fixtures');
my $MAX_REQUESTS = 20;
my $GUARD_SECS   = 45;    # hard limit per endpoint
my $BUDGET_SECS  = 170;   # whole run stays under 3 minutes
my $started      = time;

#### Counting, throttling user agent

{
  package Live::CountingUA;
  use parent -norequire, 'LWP::UserAgent';
  our $COUNT = 0;
  our @URLS;
  sub request {
    my ( $self, $req, @rest ) = @_;
    sleep 1 if $COUNT;    # one second between requests
    $COUNT++;
    push @URLS, $req->uri->as_string;
    return $self->SUPER::request( $req, @rest );
  }
}
require LWP::UserAgent;

# One fresh cache dir per run: the first call of every endpoint is live, the
# *_raw call with the same parameters afterwards is answered from it. That
# keeps traders + ermal at one request, and gives each facade call its raw
# response (for the key check) without a second request.
my $api = WWW::MetaForge::ArcRaiders->new(
  ua        => Live::CountingUA->new(
    agent   => 'WWW-MetaForge-live-test',
    timeout => 20,
  ),
  cache_dir => tempdir( CLEANUP => 1 ),
  use_cache => 1,
);

#### Helpers

# Run one endpoint check with a hard alarm; a hang ends as a named failure.
sub guarded {
  my ( $name, $code ) = @_;
  subtest $name => sub {
    my $left = $started + $BUDGET_SECS - time;
    return fail("$name: time budget of ${BUDGET_SECS}s used up") if $left <= 0;
    my $ok = eval {
      local $SIG{ALRM} = sub { die "hard limit hit, endpoint hangs\n" };
      alarm min( $GUARD_SECS, $left );
      $code->();
      alarm 0;
      1;
    };
    my $err = $@;
    alarm 0;
    fail("$name: $err") unless $ok;
  };
}

sub fixture { return decode_json( $FIXTURES->child( $_[0] )->slurp_raw ) }

sub short {
  my ($v) = @_;
  return 'undef' unless defined $v;
  my $s = ref $v ? ( ref $v eq 'HASH' ? '{...}' : ref $v eq 'ARRAY' ? '[...]' : ref $v ) : $v;
  $s = substr( $s, 0, 57 ) . '...' if length $s > 60;
  return $s;
}

# Key paths of one hashref: its keys, and one level deeper the keys of hash
# values and of hashes in array values ("stat_block.damage", "loot[].name").
# Hashes keyed by numbers (hideout levels) are one path, "levels.#".
# Returns { path => example value }.
sub key_paths {
  my ( $rec, $prefix, $depth, $out ) = @_;
  $prefix //= '';
  $depth  //= 1;
  $out    //= {};
  return $out unless ref $rec eq 'HASH';
  for my $key ( keys %$rec ) {
    my $path = length $prefix ? $prefix . '.' . $key : $key;
    my $val  = $rec->{$key};
    $out->{$path} //= short($val);
    next if $depth >= 2;
    if ( ref $val eq 'HASH' ) {
      if ( %$val && !grep { !/\A\d+\z/ } keys %$val ) {
        $out->{ $path . '.#' } //= '(numbered levels)';
      }
      else {
        key_paths( $val, $path, $depth + 1, $out );
      }
    }
    elsif ( ref $val eq 'ARRAY' ) {
      key_paths( $_, $path . '[]', $depth + 1, $out ) for grep { ref $_ eq 'HASH' } @$val;
    }
  }
  return $out;
}

sub union_paths {
  my ($records) = @_;
  my %all;
  for my $rec (@$records) {
    my $paths = key_paths($rec);
    $all{$_} //= $paths->{$_} for keys %$paths;
  }
  return \%all;
}

# Live keys the fixtures do not know fail; fixture keys missing live are a diag.
sub check_drift {
  my ( $label, $live, $fixture ) = @_;
  my $l = union_paths($live);
  my $f = union_paths($fixture);
  my @new     = sort grep { !exists $f->{$_} } keys %$l;
  my @missing = sort grep { !exists $l->{$_} } keys %$f;
  diag( $label . ': key in fixture, not seen live (optional?): ' . $_ ) for @missing;
  diag( $label . ': NEW live key not in fixture: ' . $_ . ' (example: ' . $l->{$_} . ')' ) for @new;
  ok( !@new, $label . ': every live key is known to the fixture' )
    or diag( $label . ': unknown keys, update Result class and fixture: ' . join( ', ', @new ) );
  return;
}

# Response split into (records, envelope): the envelope is everything but
# the record list, with the list itself dropped.
sub records_of {
  my ( $resp, $list_key ) = @_;
  return ( $resp, {} ) if ref $resp eq 'ARRAY';
  my %env = %$resp;
  my $rec = delete $env{$list_key};
  return ( $rec, \%env );
}

sub drift_response {
  my ( $label, $live_resp, $fixture_resps, $list_key ) = @_;
  my ( @live, @fix, @live_env, @fix_env );
  my ( $r, $e ) = records_of( $live_resp, $list_key );
  ok( ref $r eq 'ARRAY' && @$r, $label . ': record list is not empty' ) or return;
  @live     = @$r;
  @live_env = ($e) if %$e;
  for my $resp (@$fixture_resps) {
    my ( $fr, $fe ) = records_of( $resp, $list_key );
    push @fix,     @$fr;
    push @fix_env, $fe if %$fe;
  }
  check_drift( $label . ' records', \@live, \@fix );
  check_drift( $label . ' envelope', \@live_env, \@fix_env ) if @live_env || @fix_env;
  return;
}

sub all_isa {
  my ( $objs, $class, $label ) = @_;
  ok( ref $objs eq 'ARRAY' && @$objs, $label . ': result is not empty' ) or return;
  my @bad = grep { !( ref $_ && $_->isa($class) ) } @$objs;
  ok( !@bad, $label . ': all ' . scalar(@$objs) . ' records built as ' . $class );
  return;
}

#### Endpoints

guarded 'items (page 1, default limit)' => sub {
  my $items = $api->items;
  all_isa( $items, 'WWW::MetaForge::ArcRaiders::Result::Item', 'items' );
  my $raw = $api->items_raw;
  is( scalar @$items, scalar @{ $raw->{data} }, 'items: one object per live record' );
  drift_response( 'items', $raw, [ map { fixture( $_->basename ) } sort $FIXTURES->children(qr/\Aitems.*\.json\z/) ], 'data' );
};

for my $loot ( 0, 1 ) {
  guarded 'arcs (' . ( $loot ? 'includeLoot=true' : 'default' ) . ')' => sub {
    my %p = $loot ? ( includeLoot => 'true' ) : ();
    my $arcs = $api->arcs(%p);
    all_isa( $arcs, 'WWW::MetaForge::ArcRaiders::Result::Arc', 'arcs' );
    my $raw = $api->arcs_raw(%p);
    is( scalar @$arcs, scalar @{ $raw->{data} }, 'arcs: one object per live record' );
    drift_response( 'arcs' . ( $loot ? ' +loot' : '' ), $raw, [ fixture('arcs.json') ], 'data' );
  };
}

guarded 'quests (page 1)' => sub {
  my $quests = $api->quests;
  all_isa( $quests, 'WWW::MetaForge::ArcRaiders::Result::Quest', 'quests' );
  my $raw = $api->quests_raw;
  is( scalar @$quests, scalar @{ $raw->{data} }, 'quests: one object per live record' );
  drift_response( 'quests', $raw, [ fixture('quests.json') ], 'data' );
};

# traders and ermal are one response; with the run's cache it is one request
guarded 'traders and ermal (one response)' => sub {
  my $traders = $api->traders;
  all_isa( $traders, 'WWW::MetaForge::ArcRaiders::Result::Trader', 'traders' );
  my $ermal = $api->ermal;
  isa_ok( $ermal, 'WWW::MetaForge::ArcRaiders::Result::Ermal', 'ermal' )
    or return;
  my $raw = $api->traders_raw;
  is( scalar @$traders, scalar keys %{ $raw->{data} }, 'traders: one object per trader in the response' );
  my $fix = fixture('traders.json');
  my $inv = sub { [ map { @$_ } grep { ref $_ eq 'ARRAY' } values %{ $_[0]{data} } ] };
  check_drift( 'traders inventory', $inv->($raw), $inv->($fix) );
  check_drift( 'ermal', [ $raw->{ermal} ], [ $fix->{ermal} ] );
  my %env = %$raw;
  delete @env{qw( data ermal )};
  my %fenv = %$fix;
  delete @fenv{qw( data ermal )};
  check_drift( 'traders envelope', [ \%env ], [ \%fenv ] );
};

guarded 'event_timers (/events-schedule)' => sub {
  my $timers = $api->event_timers;
  all_isa( $timers, 'WWW::MetaForge::ArcRaiders::Result::EventTimer', 'event_timers' );
  my @slots = map { @{ $_->times } } @$timers;
  ok( scalar @slots, 'event_timers: there are time slots' );
  my @bad = grep { !( $_->start < $_->end ) } @slots;
  ok( !@bad, 'event_timers: every slot starts before it ends' );
  my $now = time;
  ok( scalar( grep { $_->start->epoch > $now } @slots ), 'event_timers: at least one slot lies in the future (window is current)' );
  drift_response( 'event_timers', $api->event_timers_raw, [ fixture('events-schedule.json') ], 'data' );
};

guarded 'event_timers region=all (/events-schedule?region=all)' => sub {
  my $timers = $api->event_timers( region => 'all' );
  all_isa( $timers, 'WWW::MetaForge::ArcRaiders::Result::EventTimer', 'event_timers region=all' );
  my $raw = $api->event_timers_raw( region => 'all' );
  my @slots = map { @{ $_->times } } @$timers;
  is( scalar @slots, scalar @{ $raw->{data} }, 'event_timers region=all: one slot per live record' );
  my @bad = grep { !( $_->start < $_->end ) } @slots;
  ok( !@bad, 'event_timers region=all: every slot starts before it ends' );
  my $now = time;
  ok( scalar( grep { $_->start->epoch > $now } @slots ), 'event_timers region=all: at least one slot lies in the future (window is current)' );
  my @no_region = grep { !length( $_->region // '' ) } @$timers;
  ok( !@no_region, 'event_timers region=all: every group carries its region' );
  drift_response( 'event_timers region=all', $raw, [ fixture('events-schedule-region-all.json') ], 'data' );
};

guarded 'hideout' => sub {
  my $stations = $api->hideout;
  all_isa( $stations, 'WWW::MetaForge::ArcRaiders::Result::HideoutStation', 'hideout' );
  drift_response( 'hideout', $api->hideout_raw, [ fixture('hideout.json') ], undef );
};

guarded 'weekly_trials and window (one response)' => sub {
  my $trials = $api->weekly_trials;
  all_isa( $trials, 'WWW::MetaForge::ArcRaiders::Result::WeeklyTrial', 'weekly_trials' );
  my $window = $api->weekly_trials_window;
  isa_ok( $window, 'WWW::MetaForge::ArcRaiders::Result::WeeklyTrialWindow', 'window' );
  like( $window->active_window_end,  qr/\A\d+\z/, 'window: active_window_end is an epoch number' );
  like( $window->next_window_start, qr/\A\d+\z/, 'window: next_window_start is an epoch number' );
  drift_response( 'weekly_trials', $api->weekly_trials_raw, [ fixture('weekly-trials.json') ], 'data' );
};

for my $map ( $api->maps ) {
  guarded 'map_data ' . $map => sub {
    my $markers = $api->map_data( map => $map );
    all_isa( $markers, 'WWW::MetaForge::ArcRaiders::Result::MapMarker', 'map ' . $map );
    drift_response(
      'map ' . $map,
      $api->map_data_raw( map => $map ),
      [ fixture('map-data-dam.json'), fixture('map-data-pendola-pass.json') ],
      'allData',
    );
  };
}

#### Load and time

subtest 'run stays within limits' => sub {
  diag( 'requests: ' . $Live::CountingUA::COUNT . ' in ' . ( time - $started ) . 's' );
  diag( '  ' . $_ ) for @Live::CountingUA::URLS;
  cmp_ok( $Live::CountingUA::COUNT, '<=', $MAX_REQUESTS, 'at most ' . $MAX_REQUESTS . ' requests' );
  cmp_ok( time - $started, '<', 180, 'under 3 minutes' );
};

done_testing;
