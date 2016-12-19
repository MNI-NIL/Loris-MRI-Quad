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

my $debug       = 0; 
my $profile = undef;
my $verbose    = 0;
my $file;
my $filename;
my $file_extension;
my $type;
my $sth;
my $InsertedByUserID = undef;
my $sessionID = undef;
my $patient_name = undef;
my $SessionID = undef;
my $TarchiveSource = undef;
my $script;
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
$file = $ARGV[0];
$patient_name = $ARGV[1];


# We get the filename, basename, and extension of the iamge file
my ($basename, $parentdir, $extension) = fileparse($file, qr/\.[^.]*$/);
$filename = $basename . $extension;
$type = substr $extension, 1; # Remove the dot from the extension

# We get the user that is performing the upload
$InsertedByUserID = `whoami`;

################################################################
############### Establish database connection ##################
################################################################
print "\n Connecting to database \n" if $verbose;

my $dbh = &NeuroDB::DBI::connect_to_db(@Settings::db);

################################################################
############## We find the SessionID ###########################
################################################################
print "\n Getting the SessionID \n" if $verbose;

$sth = $dbh->prepare("SELECT SessionID FROM tarchive WHERE PatientName=?");
my @params = ($patient_name);
$sth->execute(@params); 
$SessionID = $sth->fetchrow_array();

################################################################
############### Insert into files table ########################
################################################################
print "\n Inserting into Files table\n" if $verbose;

# We build the insert query
my $query = $dbh->prepare("INSERT INTO files (File, SessionID, FileType, InsertedByUserID, InsertTime, SourceFileID,TarchiveSource) VALUES (?,?,?,?,?,?,?)"); 

# Query parameters     
my @results = ($filename,$SessionID,$type,$InsertedByUserID,time,undef);

# Run query
#$query->execute(@results);

################################################################
############# Get FileID  ######################################
################################################################
print "\n Getting FileID \n" if $verbose;

$sth = $dbh->prepare("SELECT FileID from files where File=?");
@params = ($filename);
$sth->execute(@params);
$FileID = $sth->fetchrow_array();

#print "FileID is " . $FileID . "\n"; 

###############################################################
############# Get CandID ######################################
###############################################################
print "\n Getting CandID \n" if $verbose;
 
$sth = $dbh->prepare("SELECT CandID from session where ID=?");
@params = ($SessionID);
$sth->execute(@params);
$CandID = $sth->fetchrow_array();

#print "CandID is " . "$CandID" . "\n";

###############################################################
############# Get CheckPicID reference ########################
###############################################################
print "\n Getting the CheckPicID reference number \n" if $verbose;

$sth = $dbh->prepare("SELECT \@checkPicID:=ParameterTypeID FROM parameter_type WHERE Name='check_pic_filename'");
$sth->execute();
$checkPicID = $sth->fetchrow_array();

#print "CheckPicID is " . "$checkPicID" . "\n";

###############################################################
############# Insert into parameter_file table ################
###############################################################
print "\n Inserting into parameter_file table \n" if $verbose;

$sth = $dbh->prepare("INSERT INTO parameter_file (FileID, ParameterTypeID, Value, InsertTime) VALUES (?,?,?,?)");
my $value = "$CandID" . "/" . uc("$basename") . uc("_$type") . "_$FileID" . "_check.jpg"; 
@params =  ($FileID,$checkPicID,$value,time); 
#$sth->execute(@params);

# print "Value is " . "$value" . "\n";

###############################################################
############# Calling Mass_Pic ################################
###############################################################
print "\n Calling mass_pic \n" if $verbose;

$script = "./mass_pic.pl -minFileID $FileID -maxFileID $FileID -profile $profile";

if ($verbose) {		
   $script .= " -verbose";		
}

system($script);


exit;
