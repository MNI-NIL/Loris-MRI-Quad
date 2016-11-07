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
my $verbose = 0;                  # default, overwritten if scripts are run with -verbose

################################################################
#### These settings are in a config file (profile) #############
################################################################
my @opt_table = (
                 ["-verbose", "boolean", 1, \$verbose, "Be verbose."],
                );

################################################################
########### Create the Specific Log File #######################
################################################################
my $data_dir = $Settings::data_dir;
$no_nii      = $Settings::no_nii if defined $Settings::no_nii;
my $jiv_dir  = $data_dir.'/jiv';
my $TmpDir   = tempdir($template, TMPDIR => 1, CLEANUP => 1 );
my @temp     = split(/\//, $TmpDir);
my $templog  = $temp[$#temp];
my $LogDir   = "$data_dir/logs";
my $tarchiveLibraryDir = $Settings::tarchiveLibraryDir;
$tarchiveLibraryDir    =~ s/\/$//g;
if (!-d $LogDir) {
    mkdir($LogDir, 0770);
}
my $logfile  = "$LogDir/$templog.log";
print "\nlog dir is $LogDir and log file is $logfile \n" if $verbose;
open LOG, ">>", $logfile or die "Error Opening $logfile";
LOG->autoflush(1);
&logHeader();

################################################################
############### Establish database connection ##################
################################################################
my $dbh = &NeuroDB::DBI::connect_to_db(@Settings::db);
print LOG "\n==> Successfully connected to database \n" if $verbose;


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

foreach my $key ('File', 'SessionID','EchoTime', 'CoordinateSpace', 'OutputType', 'AcquisitionProtocolID', 'FileType', 'InsertedByUserID', 'Caveat', 'SeriesUID', 'TarchiveSource','SourcePipeline','PipelineDate','SourceFileID', 'ScannerID') {
    # add the key=value pair to the query
    $query .= "$key=".$dbh->quote($${fileData{$key}}).", ";
}

$query .= "InsertTime=UNIX_TIMESTAMP()";

# run the query
$dbh->do($query);
my $fileID = $dbh->{'mysql_insertid'};

exit;
