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

################################################################
#### These settings are in a config file (profile) #############
################################################################
my @opt_table = (
                 ["-verbose", "boolean", 1, \$verbose, "Be verbose."],
                );


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
    print $Usage;
    print "\n\tERROR: You must specify an existing profile.\n\n";
    exit 33;
}

################################################################
# Where the pics should go #####################################
################################################################
my $pic_dir = $Settings::data_dir . '/pic';

################################################################
############### Establish database connection ##################
################################################################
my $dbh = &NeuroDB::DBI::connect_to_db(@Settings::db);


################################################################
############### Create Insert Query ############################
################################################################

# retrieve the file's data
my $fileData = $file->getFileData();

# make sure this file isn't registered
if(defined($fileData->{'FileID'}) && $fileData->{'FileID'} > 0) {
   return 0;
}

# build the insert query
my $query = "INSERT INTO files SET ";

foreach my $key ('File', 'FileType', 'InsertedByUserID') {
    # add the key=value pair to the query
    $query .= "$key=".$dbh->quote($${fileData{$key}}).", ";
}

$query .= "InsertTime=UNIX_TIMESTAMP()";

# run the query
$dbh->do($query);

#my $fileID = $dbh->{'mysql_insertid'};
#$file->setFileData('FileID', $fileID);

exit 0;
