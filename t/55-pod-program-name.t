#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Find ();

# Source scan, offline and without dzil. Runs in the default suite: the dist
# has no xt/ and the scan is cheap and deterministic.

my $root = "$FindBin::Bin/..";
my @files;
File::Find::find({ no_chdir => 1, wanted => sub {
  push @files, $File::Find::name if -f $_ && /\.pm\z/;
} }, "$root/lib");
push @files, grep { -f } glob("$root/bin/*");
@files = sort @files;

sub scan {
  my ($re) = @_;
  my @hits;
  for my $file (@files) {
    open my $fh, '<:encoding(UTF-8)', $file or die "Cannot read $file: $!";
    while (my $line = <$fh>) {
      push @hits, substr($file, length($root) + 1).':'.$.  .': '.$line if $line =~ $re;
    }
  }
  return @hits;
}

ok(scalar(@files) > 10, 'found lib and bin sources to scan');

# karr k32: the program is installed as metaforge-arcraiders.
subtest 'no bare arcraiders program name (k32)' => sub {
  my $re = qr/(?<![-\w:])arcraiders\b/;
  for my $ok ('metaforge-arcraiders', 'mcp-arcraiders', 'arc-raiders', 'WWW::MetaForge::ArcRaiders',
              'WWW_METAFORGE_ARCRAIDERS_X', 'ArcRaiders') {
    unlike($ok, $re, "pattern leaves '$ok' alone");
  }
  like('run arcraiders item', $re, 'pattern catches a bare arcraiders');
  my @hits = scan($re);
  is(scalar(@hits), 0, 'no bare arcraiders in lib/ and bin/') or diag(join '', @hits);
};

# karr k33: Pod::Weaver (@Author::GETTY) generates these; a hand-written one duplicates it.
subtest 'no hand-written Pod::Weaver sections (k33)' => sub {
  my $re = qr/^=head1\s+(?:NAME|VERSION|SUPPORT|CONTRIBUTING|AUTHORS?|COPYRIGHT)\b/;
  like('=head1 SUPPORT', $re, 'pattern catches =head1 SUPPORT');
  unlike('=head1 COMMUNITY', $re, 'pattern leaves =head1 COMMUNITY alone');
  my @hits = scan($re);
  is(scalar(@hits), 0, 'no generated sections written by hand in lib/ and bin/') or diag(join '', @hits);
};

done_testing;
