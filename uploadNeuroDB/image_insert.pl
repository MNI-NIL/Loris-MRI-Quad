#!/usr/bin/perl

# Write/use a script to insert data into the files table
# Script can assume and document that candidate and session already exist
# location: uploadNeuroDB/image_insertion.pl

use strict;
use warnings;
use Carp;
use Getopt::Tabular;
use FileHandle;
use File::Basename;
use File::Temp qw/ tempdir /;
use Data::Dumper;
use FindBin;
use Cwd qw/ abs_path /;

# These are the NeuroDB modules to be used
use lib "$FindBin::Bin";
use NeuroDB::File;
use NeuroDB::MRI;
use NeuroDB::DBI;
use NeuroDB::Notify;
use NeuroDB::MRIProcessingUtility;

my $profile = undef;
my $verbose    = 0;
my $file;
my $file_extension;
my $type;
my $sth;
my $InsertedByUserID = undef;
my $sessionID = undef;
my $patient_name = undef;
my $session_id = undef;

################################################################
#### These settings are in a config file (profile) #############
################################################################
my @opt_table = (
                 ["-verbose", "boolean", 1, \$verbose, "Be verbose."],
                 ["-profile","string",1, \$profile, "Specify the name of the config file which resides in .loris_mri in the current directory."]
                );


GetOptions(\@opt_table, \@ARGV) ||  exit 1;

################################################################
################ checking for profile settings #################
################################################################
if (-f "$ENV{LORIS_CONFIG}/.loris_mri/$profile") {
	{ package Settings; do "$ENV{LORIS_CONFIG}/.loris_mri/$profile" }
}
if ($profile && !@Settings::db) {
    print "\n\tERROR: You don't have a configuration file named '$profile' ".
          "in:  $ENV{LORIS_CONFIG}/.loris_mri/ \n\n";
    exit 33;
}

if (!$profile) {
    print "\n\tERROR: You must specify an existing profile.\n\n";
    exit 33;
}

if(scalar(@ARGV) != 2) {
    print "\nError: Missing source file or Patient Name\n\n";
    exit 1;
}


################################################################
############ Populate main parameters ##########################
###############################################################

# We get the name of the file in the path provided 
$file = basename(abs_path($ARGV[0]));
$patient_name = $ARGV[1];

# TODO: refactor this. 
# We get the extension of the file
($file_extension) = $file =~ /(\.[^.]+)$/;

$type = substr $file_extension, 1;

# We get the user that is performing the upload
$InsertedByUserID = `whoami`;

################################################################
############### Establish database connection ##################
################################################################

my $dbh = &NeuroDB::DBI::connect_to_db(@Settings::db);


################################################################
############## We find the SessionID ###########################
################################################################

$sth = $dbh->prepare("SELECT SessionID FROM tarchive WHERE PatientName=?");
my @params = ($patient_name);
$sth->execute(@params); 
$session_id = $sth->fetchrow_array();

################################################################
############### Create Insert Query ############################
################################################################

# We build the insert query
my $query = $dbh->prepare("INSERT INTO files (File, SessionID, FileType, InsertedByUserID, InsertTime, SourceFileID) VALUES (?,?,?,?,?,?)"); 

# Query parameters     
my @results = ($file,$session_id,$type,$InsertedByUserID,time,undef);

# Run query
$query->execute(@results);

exit;
