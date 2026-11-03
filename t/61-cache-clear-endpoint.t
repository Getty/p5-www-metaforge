#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw( tempdir );
use Digest::MD5 qw( md5_hex );
use Path::Tiny;
use WWW::MetaForge::Cache;

# clear($endpoint) removes the entries of exactly that endpoint (every
# parameter set, current and older file format) and no entry of an endpoint
# whose name merely starts the same way. Entries are files named
# <endpoint>_<md5>.v2.json, older ones <endpoint>_<md5>.json.

sub new_cache { return WWW::MetaForge::Cache->new(cache_dir => tempdir(CLEANUP => 1)) }

# an entry of the older file format, written by hand
sub legacy_file {
  my ($cache, $endpoint, $tag) = @_;
  my $file = path($cache->cache_dir, $endpoint . '_' . md5_hex($tag) . '.json');
  $file->spew_raw('{"timestamp":1,"data":["old"]}');
  return $file;
}

subtest 'clear removes every parameter set of the endpoint' => sub {
  my $cache = new_cache();
  $cache->set('foo', {},          ['a']);
  $cache->set('foo', { page => 2 }, ['b']);
  $cache->set('foo', { q => 'x' }, ['c']);

  $cache->clear('foo');

  is($cache->get('foo', {}),           undef, 'no parameters');
  is($cache->get('foo', { page => 2 }), undef, 'page 2');
  is($cache->get('foo', { q => 'x' }), undef, 'search');
  is(scalar($cache->cache_dir->children), 0, 'no file is left');
};

subtest 'clear leaves an endpoint that only shares the prefix' => sub {
  my $cache = new_cache();
  $cache->set('foo',     {},             ['foo']);
  $cache->set('foo_bar', {},             ['bar']);
  $cache->set('foo_bar', { page => 2 },  ['bar 2']);

  $cache->clear('foo');

  is($cache->get('foo', {}), undef, 'foo is gone');
  is_deeply($cache->get('foo_bar', {}),            ['bar'],   'foo_bar stays');
  is_deeply($cache->get('foo_bar', { page => 2 }), ['bar 2'], 'foo_bar with parameters stays');
  ok($cache->get_entry('foo_bar', {}), 'get_entry still finds it');

  $cache->clear('foo_bar');
  is($cache->get('foo_bar', {}), undef, 'clearing foo_bar removes it');
};

subtest 'the event timer endpoints are told apart' => sub {
  my $cache = new_cache();
  $cache->set('event_timers',        { region => 'europe' }, ['timers']);
  $cache->set('event_timers_hourly', { region => 'europe' }, ['hourly']);

  $cache->clear('event_timers');

  is($cache->get('event_timers', { region => 'europe' }), undef, 'event_timers is gone');
  is_deeply($cache->get('event_timers_hourly', { region => 'europe' }), ['hourly'],
    'event_timers_hourly stays');
};

subtest 'clear removes the older file format of the endpoint as well' => sub {
  my $cache  = new_cache();
  my $old    = legacy_file($cache, 'foo', 'one');
  my $other  = legacy_file($cache, 'foo_bar', 'one');
  $cache->set('foo',     {}, ['new']);
  $cache->set('foo_bar', {}, ['bar']);

  $cache->clear('foo');

  ok(!$old->exists, 'the older entry of foo is gone');
  ok($other->exists, 'the older entry of foo_bar stays');
  is_deeply($cache->get('foo_bar', {}), ['bar'], 'the current entry of foo_bar stays');
  is($cache->get('foo', {}), undef, 'the current entry of foo is gone');
};

subtest 'clear without an argument removes everything of both formats' => sub {
  my $cache = new_cache();
  my @old   = (legacy_file($cache, 'foo', 'one'), legacy_file($cache, 'foo_bar', 'two'));
  $cache->set('foo',     {}, ['a']);
  $cache->set('foo_bar', {}, ['b']);
  $cache->set('items',   { page => 3 }, ['c']);

  $cache->clear;

  is(scalar($cache->cache_dir->children), 0, 'the directory is empty');
  ok(!$_->exists, $_->basename.' is gone') for @old;
  is($cache->get('items', { page => 3 }), undef, 'items is gone');
};

subtest 'clear of an endpoint without entries changes nothing' => sub {
  my $cache = new_cache();
  $cache->set('foo', {}, ['a']);

  $cache->clear('nothing');

  is_deeply($cache->get('foo', {}), ['a'], 'foo stays');
};

done_testing;
