#!/usr/bin/perl
#
# by Matija Nalis <mnalis-perl@voyager.hr> GPLv3+ started 2021-07-12
# (used original code at https://github.com/mnalis/gpx_to_dotwalker_xml as starting point)
#
# command line version
#
# requires Geo::Gpx perl module ("apt-get install libgeo-gpx-perl libjson-perl" on Jessie or higher)
# and JSON ("apt-get install libjson-perl")
#
# FIXME: make gpx route object instead? but needs rewriting, can't add one by one rtePt as I can wPt with Geo::GPX?

use strict;
use warnings;
use autodie;
#use diagnostics;

#$| = 1;
my $DEBUG = 0;

use JSON;
use Geo::Gpx;
binmode STDOUT, ':utf8';	# our terminal is UTF-8 capable (we hope)

my $VERSION = '0.2';

my $fname_JSON = $ARGV[0];
my $fname_GPX = $ARGV[1];
my %extra;
my $row;

# adds tag to GPX if it exists in source
sub add_if_exists($$$$) 
{
  my ($src, $dst, $prefix, $postfix) = @_;
  my $txt = $row->{$src};
  if (defined $txt) {
    $txt =~ s/\s+$//;	# remove trailing spaces always
    $extra{$dst} .=  "$prefix$txt$postfix";
    print "  adding extra attribute $src/$dst => >$prefix$txt$postfix<\n" if $DEBUG > 2;
  }
}  

if (!defined ($fname_JSON) or !defined($fname_GPX)) {
    print "loadstone_to_gpx.pl v$VERSION\n";
    print "Usage: $0 <loadstone_input.TXT> <output.GPX>\n\n";
    print "input or/and output file can be '-', signifying stdin/stdout\n";
    print "This program creates standard routing .GPX from sport-tracker.com JSON file\n";
    exit 1;
}

# parse given JSON input file
open my $json_fd, "< $fname_JSON";	# need 2-arg open so '-' will work as alias for stdin
binmode $json_fd, ':utf8';		# input file is UTF-8 capable (we hope)

undef $/;
my $json_txt = <$json_fd>; 
my $json_href = decode_json $json_txt;

# create empty .gpx
my $gpx = Geo::Gpx->new();
$gpx->link({ href => 'https://github.com/mnalis/sportstracker_to_gpx', text => "Converted by sportstracker_to_gpx.pl v$VERSION" });
$gpx->name($fname_JSON) if $fname_JSON ne '-';

$DEBUG && print "Parsing from sports-tracker.com $fname_JSON to GPX $fname_GPX\n\n";
my $count = 1;


my $payload=$$json_href{payload};


# add all waypoints one by one
foreach my $row (@$payload) {
  my $name = $$row{name};
  if (!$name) { $name = "Point $count" }
  $count++;

  my $lat=$row->{location}{y};
  my $lon=$row->{location}{x};
  if (!$lat or !$lon)  {
    $DEBUG && print "skipping missing lat/lon for $name";
    next;
  };	
  
  print "parsing $lat,$lon\t$name\n" if $DEBUG > 1;
  
  %extra = ();
  add_if_exists ('description', 'desc', '', '');	# or desc => cmt ?
  add_if_exists ('timestamp', 'time', '', '');
  
  $gpx->add_waypoint ({
    lat => $lat,
    lon => $lon,
    name => $name,
    %extra
  });
}

# write output GPX 1.1 file
my $xml = $gpx->xml( '1.1' );
die "refusing to overwrite $fname_GPX" if -e $fname_GPX;
open my $gpx_fd, "> $fname_GPX";	# need 2-arg open so '-' will work as alias for stdout
print $gpx_fd $xml or die "can't append to $fname_GPX: $!";
close $gpx_fd;
