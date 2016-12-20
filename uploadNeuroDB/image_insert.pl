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

my $debug = 0; 
my $verbose = 0;
my $file;
my $filename;
my $type;
my $sth;
my $script;
my $profile = undef;
my $InsertedByUserID = undef;
my $sessionID = undef;
my $PatientName = undef;
my $SessionID = undef;
my $TarchiveSource = undef;
my $FileID = undef;
my $CandID = undef;
my $checkPicID = undef;

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
################################################################

# We get the name of the file in the path provided
# Get the file we want to insert 
$file = $ARGV[0]; 

# Get the candidate's name we want to insert the image to 
$PatientName = $ARGV[1]; 

# Get the filename, basename, and extension of the image file to insert
my ($basename, $parentdir, $extension) = fileparse($file, qr/\.[^.]*$/);
$filename = $basename . $extension;

# Get the image type, remove the dot from the extension 
$type = substr $extension, 1;

# Get the user that is performing the upload
$InsertedByUserID = `whoami`;

# Declare path for the source directory
my $data_dir = $Settings::data_dir;
my $pic_dir  = $data_dir.'/pic';


################################################################
############### Establish database connection ##################
################################################################
print "\n Connecting to database \n" if $verbose;

# Database connection
my $dbh = &NeuroDB::DBI::connect_to_db(@Settings::db);

################################################################
############## We find the SessionID ###########################
################################################################
print "\n Getting the SessionID \n" if $verbose;

# Prepare query to retrieve the SessionID from the Candidate
$sth = $dbh->prepare("SELECT SessionID FROM tarchive WHERE PatientName=?");
my @params = ($PatientName);
$sth->execute(@params); 
$SessionID = $sth->fetchrow_array();

print "\n SessionID is " . $SessionID . "\n" if $verbose;

################################################################
############### Insert into files table ########################
################################################################
print "\n Inserting into Files table \n" if $verbose;

# Prepare query to insert file into files table 
my $query = $dbh->prepare("INSERT INTO files (File, SessionID, FileType, InsertedByUserID, InsertTime, SourceFileID,TarchiveSource) VALUES (?,?,?,?,?,?,?)"); 

# Query parameters     
my @results = ($filename,$SessionID,$type,$InsertedByUserID,time,undef,undef);

# Run query
$query->execute(@results);

################################################################
###################### Get FileID ##############################
################################################################
print "\n Getting FileID \n" if $verbose;

# Prepare query to retrieve the FileID of the inserted image file
$sth = $dbh->prepare("SELECT FileID from files where File=?");
@params = ($filename);
$sth->execute(@params);
$FileID = $sth->fetchrow_array();

print "\n FileID is " . $FileID . "\n" if $verbose; 

###############################################################
###################### Get CandID #############################
###############################################################
print "\n Getting CandID \n" if $verbose;
 
# Prepare the query to retrieve the CandID information
$sth = $dbh->prepare("SELECT CandID from session where ID=?");
@params = ($SessionID);
$sth->execute(@params);
$CandID = $sth->fetchrow_array();

print "\n CandID is " . "$CandID" . "\n" if $verbose;

###############################################################
############# Get CheckPicID reference ########################
###############################################################
print "\n Getting the CheckPicID reference number \n" if $verbose;

# Prepare query to get the ParameterTypeID of the site study
$sth = $dbh->prepare("SELECT \@checkPicID:=ParameterTypeID FROM parameter_type WHERE Name='check_pic_filename'");
$sth->execute();
$checkPicID = $sth->fetchrow_array();

print "\n CheckPicID is " . "$checkPicID" . "\n" if $verbose;

###############################################################
############# Insert into parameter_file table ################
###############################################################
print "\n Inserting into parameter_file table \n" if $verbose;

# Prepare query to insert image into the parameter_file table
$sth = $dbh->prepare("INSERT INTO parameter_file (FileID, ParameterTypeID, Value, InsertTime) VALUES (?,?,?,?)");

# Create value field (name to be used in the /pic directory)
my $value = "$CandID" . "/" . uc("$basename") . uc("_$type") . "_$FileID" . "_check.jpg"; 

@params =  ($FileID,$checkPicID,$value,time); 
$sth->execute(@params);

print "\n Value is " . "$value" . "\n" if $verbose;

###############################################################
############# Populating Candidate Pic directory ##############
###############################################################
print "\n Saving image in candidate's /pic directory \n" if $verbose;

# We copy the file into the pic directory with the new "value" name
my $newfilename = uc("$basename") . uc("_$type") . "_$FileID" . "_check.jpg";
my $target = $pic_dir . "/" . $CandID . "/"; 
$script = "cp $file $newfilename && mv $newfilename $target";

system($script);

print "\n Finished inserting $filename \n" if $verbose;

# Done.
exit;
