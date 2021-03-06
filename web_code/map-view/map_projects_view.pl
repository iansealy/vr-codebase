#!/usr/local/bin/perl -T

BEGIN {
    $ENV{VRTRACK_HOST} = 'mcs4a';
    $ENV{VRTRACK_PORT} = 3306;
    $ENV{VRTRACK_RO_USER} = 'vreseq_ro';
    $ENV{VRTRACK_RW_USER} = 'vreseq_rw';
    $ENV{VRTRACK_PASSWORD} = 't3aml3ss';
};

use strict;
use warnings;
use URI;

use SangerPaths qw(core team145);
use SangerWeb;
use VRTrack::VRTrack;
use VRTrack::Project;
use VertRes::Utils::VRTrackFactory;
use VertRes::QCGrind::ViewUtil;

my $utl = VertRes::QCGrind::ViewUtil->new();

my $title = 'Map View';

my $sw  = SangerWeb->new({
    'title'   => $title,
    'banner'  => q(),
    'inifile' => SangerWeb->document_root() . q(/Info/header.ini),
});

my $cgi = $sw->cgi();

my $db = $cgi->param('db');
unless ($db) {
    print $sw->header();
	$utl->displayError( "No database ID",$sw );
}
my $vrtrack = $utl->connectToDatabase($db);
unless ( defined $vrtrack ) {
	print $sw->header();
	$utl->displayError( "No database connection to $db",$sw );
}

my $init_script = $utl->{SCRIPTS}{MAP_VIEW};
my $lanes_script = $utl->{SCRIPTS}{MAP_LANES_VIEW};

print $sw->header();
$utl->displayDatabasePage($title,$cgi,$vrtrack,$db,$init_script,$lanes_script);
print $sw->footer();
exit;
