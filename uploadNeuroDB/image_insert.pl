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
my $file_name;
my $file_extension;
my $ext;
my $InsertedByUserID = undef;
my $sessionID = undef;

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

if(scalar(@ARGV) != 1) {
    print "\nError: Missing source file\n\n";
    exit 1;
}

# We get the name of the file in the path provided 
$file_name = basename(abs_path($ARGV[0]));

# We get the extension of the file
($file_extension) = $file_name =~ /((\.[^.\s]+)+)$/;
$ext = substr $file_extension, 1;

# We get the user that is performing the upload
$InsertedByUserID = `whoami`;

################################################################
############### Establish database connection ##################
################################################################

my $dbh = &NeuroDB::DBI::connect_to_db(@Settings::db);


################################################################
############## We find the SessionID ###########################
################################################################

# TODO
#my $sth = $${dbhr}->prepare("SELECT CandID, Visit_label FROM session WHERE ID=".$file->getFileDatum('SessionID'));
#   $sth->execute();
#    my $rowhr = $sth->fetchrow_hashref();

################################################################
############### Create Insert Query ############################
################################################################

# TODO
# retrieve the file's data
#my $fileData = $file->getFileData();

# TODO
# make sure this file isn't registered
#if(defined($fileData->{'FileID'}) && $fileData->{'FileID'} > 0) {
#   return 0;
#}

# build the insert query
my $query = $dbh->prepare("INSERT INTO files (File, SessionID, FileType, InsertedByUserID, InsertTime) VALUES (?,?,?,?,?)"); 
     
my @results = ($file_name,"",$ext,$InsertedByUserID,time);

$query->execute(@results);

# for debugging
print "$query\n\n";


exit;
