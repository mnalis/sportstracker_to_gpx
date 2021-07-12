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

my $VERSION = '0.5';

my $URL = $ARGV[0];

my $username = '';
my $JSON_URL;
my $fname_GPX;
my %extra;
my $row;
my $key;

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

if (!defined $URL) {
    print "sportstracker_to_gpx.pl v$VERSION\n";
    print "Usage: $0 <https://www.sports-tracker.com/workout/xxxxx/123456789abcdef012345678> [output.gpx]\n\n";
    print "This program creates standard routing .GPX from sport-tracker.com URL\n";
    exit 1;
}

if ($URL =~ m!/([^/q]*?)/([a-z0-9]{24})$!i) {
    $username = $1;
    $key = $2;
    $fname_GPX = $ARGV[1] || "${key}.gpx";
    $JSON_URL = 'https://api.sports-tracker.com/apiserver/v1/workouts/' . $key . '/data?samples=100000';
} else {
    print "URL must be in format 'https://www.sports-tracker.com/workout/xxxxx/123456789abcdef012345678', and not: $URL";
    exit 2;
}

# parse given JSON input file
open my $json_fd, '-|', "curl -sL $JSON_URL";
binmode $json_fd, ':utf8';			# input file is UTF-8 capable (we hope)

undef $/;
my $json_txt = <$json_fd>; 
my $json_href = decode_json $json_txt;

# create empty .gpx
my $gpx = Geo::Gpx->new();
$gpx->link({ href => 'https://github.com/mnalis/sportstracker_to_gpx', text => "Converted by sportstracker_to_gpx.pl v$VERSION" });
$gpx->name($key);

$DEBUG && print "Parsing from $URL to GPX $fname_GPX\n\n";
my $count = 1;


my $payload = $$json_href{'payload'}{'locations'};


# add all waypoints one by one
foreach my $row (@$payload) {
  $count++;

  #use Data::Dumper; print Dumper ($row); die;

  my $lat = $row->{'la'};
  my $lon = $row->{'ln'};
  my $time = int ($row->{'d'} / 1000);
  if (!$lat or !$lon)  {
    $DEBUG && print "skipping missing lat/lon for point $count";
    next;
  };	
  
  print "parsing $lat,$lon\t$count\n" if $DEBUG > 1;
  
  %extra = ();
  #add_if_exists ('description', 'desc', '', '');	# or desc => cmt ?
  
  push @{$gpx->{waypoints}},
  {
    lat => $lat,
    lon => $lon,
    time => $time,
    %extra
  };
}

# write output GPX 1.1 file
$gpx->author({ 
        link => {
          text => "$username $key",
          href => $URL,
        },
        name => $username
      });

$gpx->desc ($key);
my $xml = $gpx->xml( '1.1' );


die "refusing to overwrite $fname_GPX" if -e $fname_GPX;
open my $gpx_fd, "> $fname_GPX";	# need 2-arg open so '-' will work as alias for stdout
print $gpx_fd $xml or die "can't append to $fname_GPX: $!";
close $gpx_fd;
