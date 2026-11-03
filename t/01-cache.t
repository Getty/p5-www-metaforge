#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Path::Tiny;
use Digest::MD5 qw(md5_hex);

use_ok('WWW::MetaForge::Cache');

my $temp_dir = tempdir(CLEANUP => 1);

subtest 'constructor with custom cache_dir' => sub {
  my $cache = WWW::MetaForge::Cache->new(
    cache_dir => $temp_dir,
  );

  isa_ok($cache, 'WWW::MetaForge::Cache');
  ok($cache->cache_dir->is_dir, 'cache_dir exists');
};

subtest 'default namespace' => sub {
  my $cache = WWW::MetaForge::Cache->new(cache_dir => $temp_dir);
  is($cache->namespace, 'metaforge', 'default namespace is metaforge');
};

subtest 'cache_dir coercion from string' => sub {
  my $cache = WWW::MetaForge::Cache->new(
    cache_dir => "$temp_dir",  # string, not Path::Tiny
  );

  isa_ok($cache->cache_dir, 'Path::Tiny', 'coerced to Path::Tiny');
};

subtest 'default TTL is empty (never expire)' => sub {
  my $cache = WWW::MetaForge::Cache->new(cache_dir => $temp_dir);

  is_deeply($cache->ttl, {}, 'default TTL is empty hash');
  ok(!defined $cache->ttl->{items}, 'items has no TTL (never expires)');
  ok(!defined $cache->ttl->{event_timers}, 'event_timers has no TTL (never expires)');
};

subtest 'custom TTL' => sub {
  my $cache = WWW::MetaForge::Cache->new(
    cache_dir => $temp_dir,
    ttl       => { items => 60, traders => 120 },
  );

  is($cache->ttl->{items}, 60, 'custom items TTL');
  is($cache->ttl->{traders}, 120, 'custom traders TTL');
};

subtest 'get/set roundtrip' => sub {
  my $cache = WWW::MetaForge::Cache->new(cache_dir => $temp_dir);
  my $data = { foo => 'bar', list => [1, 2, 3] };

  $cache->set('test_endpoint', { param => 'value' }, $data);

  my $retrieved = $cache->get('test_endpoint', { param => 'value' });
  is_deeply($retrieved, $data, 'data roundtrips correctly');
};

subtest 'get returns undef for missing' => sub {
  my $cache = WWW::MetaForge::Cache->new(cache_dir => $temp_dir);

  my $result = $cache->get('nonexistent', {});
  ok(!defined $result, 'missing cache returns undef');
};

subtest 'different params create different cache entries' => sub {
  my $cache = WWW::MetaForge::Cache->new(cache_dir => $temp_dir);

  $cache->set('items', { search => 'Ferro' }, { name => 'Ferro' });
  $cache->set('items', { search => 'Grip' }, { name => 'Grip' });

  my $ferro = $cache->get('items', { search => 'Ferro' });
  my $grip = $cache->get('items', { search => 'Grip' });

  is($ferro->{name}, 'Ferro', 'first entry');
  is($grip->{name}, 'Grip', 'second entry');
};

subtest 'TTL expiration' => sub {
  my $cache = WWW::MetaForge::Cache->new(
    cache_dir => $temp_dir,
    ttl       => { test => 1 },  # 1 second TTL
  );

  $cache->set('test', {}, { data => 'value' });

  my $immediate = $cache->get('test', {});
  is($immediate->{data}, 'value', 'immediate get works');

  sleep 2;  # Wait for expiration

  my $expired = $cache->get('test', {});
  ok(!defined $expired, 'expired cache returns undef');
};

subtest 'no TTL means never expire' => sub {
  my $cache = WWW::MetaForge::Cache->new(
    cache_dir => $temp_dir,
    ttl       => {},  # empty = never expire
  );

  $cache->set('forever', {}, { data => 'permanent' });

  my $immediate = $cache->get('forever', {});
  is($immediate->{data}, 'permanent', 'immediate get works');

  sleep 2;  # Wait... but it should NOT expire

  my $still_valid = $cache->get('forever', {});
  is($still_valid->{data}, 'permanent', 'cache still valid without TTL');
};

subtest 'clear specific endpoint' => sub {
  my $cache = WWW::MetaForge::Cache->new(cache_dir => $temp_dir);

  $cache->set('endpoint_a', {}, { a => 1 });
  $cache->set('endpoint_b', {}, { b => 2 });

  $cache->clear('endpoint_a');

  ok(!defined $cache->get('endpoint_a', {}), 'endpoint_a cleared');
  is($cache->get('endpoint_b', {})->{b}, 2, 'endpoint_b still exists');
};

subtest 'clear_all' => sub {
  my $cache = WWW::MetaForge::Cache->new(cache_dir => $temp_dir);

  $cache->set('ep1', {}, { x => 1 });
  $cache->set('ep2', {}, { y => 2 });

  $cache->clear_all;

  ok(!defined $cache->get('ep1', {}), 'ep1 cleared');
  ok(!defined $cache->get('ep2', {}), 'ep2 cleared');
};

subtest 'cache file contains metadata' => sub {
  my $cache = WWW::MetaForge::Cache->new(cache_dir => $temp_dir);

  $cache->set('meta_test', { key => 'val' }, { result => 'data' });

  # Find the cache file and read it directly
  my @files = path($temp_dir)->children(qr/^meta_test_/);
  ok(@files == 1, 'cache file created');

  my $content = $cache->json->decode($files[0]->slurp_raw);
  ok(exists $content->{timestamp}, 'has timestamp');
  ok(exists $content->{endpoint}, 'has endpoint');
  ok(exists $content->{params}, 'has params');
  ok(exists $content->{data}, 'has data');
  is($content->{endpoint}, 'meta_test', 'endpoint stored');
};

subtest 'non-ASCII value is encoded to UTF-8 exactly once' => sub {
  my $dir   = tempdir(CLEANUP => 1);
  my $cache = WWW::MetaForge::Cache->new(cache_dir => $dir);
  my $value = "Raider\x{2019}s Hatch";

  $cache->set('utf8', {}, { name => $value });

  my @files = path($dir)->children(qr/^utf8_/);
  is(scalar @files, 1, 'one cache file');
  my $bytes = $files[0]->slurp_raw;

  like($bytes, qr/\xE2\x80\x99/, 'right single quote is E2 80 99 on disk');
  unlike($bytes, qr/\xC3\xA2\xC2\x80\xC2\x99/, 'not double-encoded');
  ok(utf8::decode(my $copy = $bytes), 'file bytes decode as UTF-8');
  like($copy, qr/\x{2019}/, 'decoded text holds the character');

  is($cache->get('utf8', {})->{name}, $value, 'get returns the same string');
};

subtest 'file name carries the format version' => sub {
  my $dir   = tempdir(CLEANUP => 1);
  my $cache = WWW::MetaForge::Cache->new(cache_dir => $dir);

  $cache->set('ep', {}, { a => 1 });

  my @names = map { $_->basename } path($dir)->children;
  is(scalar @names, 1, 'one file');
  like($names[0], qr/^ep_[0-9a-f]{32}\.v2\.json$/, 'name is <endpoint>_<md5>.v2.json');
};

subtest 'v1 files are not read, clear removes them' => sub {
  my $dir   = tempdir(CLEANUP => 1);
  my $cache = WWW::MetaForge::Cache->new(cache_dir => $dir);

  my $v1 = path($dir)->child('ep_' . md5_hex($cache->json->encode({})) . '.json');
  my $write_v1 = sub {
    $v1->spew_raw($cache->json->encode({
      timestamp => time, endpoint => 'ep', params => {}, data => { old => 1 },
    }));
  };

  $write_v1->();
  ok($v1->is_file, 'v1 file in place');
  ok(!defined $cache->get('ep', {}), 'get ignores the v1 file');
  ok(!defined $cache->get_entry('ep', {}), 'get_entry ignores the v1 file');

  $cache->clear('ep');
  ok(!$v1->exists, 'clear(endpoint) removes the v1 file');

  $write_v1->();
  $cache->clear;
  ok(!$v1->exists, 'clear() removes the v1 file');
};

subtest 'get_entry returns the stored entry' => sub {
  my $dir   = tempdir(CLEANUP => 1);
  my $cache = WWW::MetaForge::Cache->new(cache_dir => $dir);

  $cache->set('ep', { q => 'x' }, { v => [1, 2] });
  my $before = time;
  my $entry  = $cache->get_entry('ep', { q => 'x' });

  is_deeply([sort keys %$entry], [qw(data endpoint params timestamp)], 'all four keys');
  ok(abs($entry->{timestamp} - $before) <= 2, 'timestamp is about now');
  is($entry->{endpoint}, 'ep', 'endpoint');
  is_deeply($entry->{params}, { q => 'x' }, 'params');
  is_deeply($entry->{data}, { v => [1, 2] }, 'data');

  ok(!defined $cache->get_entry('ep', { q => 'other' }), 'undef for a missing entry');
};

subtest 'get_entry ignores the TTL, get applies it' => sub {
  my $dir   = tempdir(CLEANUP => 1);
  my $cache = WWW::MetaForge::Cache->new(cache_dir => $dir, ttl => { ep => 1 });

  $cache->set('ep', {}, { v => 1 });

  # rewrite the entry as written 10 s ago, past the 1 s TTL
  my ($file) = path($dir)->children(qr/^ep_/);
  my $stored = $cache->json->decode($file->slurp_raw);
  $stored->{timestamp} = time - 10;
  $file->spew_raw($cache->json->encode($stored));

  ok(!defined $cache->get('ep', {}), 'get: expired');
  my $entry = $cache->get_entry('ep', {});
  ok(defined $entry, 'get_entry: still delivered');
  is_deeply($entry->{data}, { v => 1 }, 'with its data');
};

done_testing;
