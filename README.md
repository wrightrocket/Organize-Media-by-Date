# Organize-Media-by-Date
Organize your multimedia files by date.  

Creates a date organized structure under a "to directory" 
by year/month/day/file by reading EXIF create date information, 
the image created date, the folder date, or the modification date from the file.

By Keith Wright (keith.wright.rocket@gmail.com)
Started: 2014/11/30
Last Update: 2015/02/07

Below are the pertinent comments from the top of the media_date_org.pl file


media_date_org.pl

Program organizes files matching regular expressions found in the @regs array
The default "from directory" is the current working directory
The default "to directory" is the "gallery" subdirectory
The program accepts the first argument as the "from directory" <FROM_DIR>
and the second argument as the "to directory" <TO_DIR>

The program then copies from the "from directory" to the "to directory" by
Organizing photos by year, month and day
Creates a directory for each year found
Creates a subdirectory for each month found
Creates a subdirectory for each day found
Then, copies files to subdirectory by day found
If the copy is the same size as original, it will be deleted if $REMOVE = 1, or -r is used

The following options modify the default behavior of the program:

Automates confirmation if $CONFIRM = 1, or -a option used
Debugging information printed if $DEBUG = 1, or -d option used
Overwrites "to file" with "from file" if $OVERWRITE = 1, or -o option used
Progress codes are printed if $PROGRESS = 1, or -p option used
Removes "from file" if copied file is same size as "to file" if $REMOVE = 1, or -r option used
Verbose output will be printed if $VERBOSE = 1, or -v option used
If -f <FROM_DIR> is used, then the <FROM_DIR> will be used as the $source_dir
If -t <TO_DIR> is used, then <TO_DIR> will be used as the $dest_dir

This program will not run with the standard perl distribution
Modules must be installed in order to run this program

To install modules use the cpan command
or the package manager for your distribution
or the package manager for your operating system
 
In ActiveState Perl use the "ppm" command

To learn more about these  modules search at: 
http://search.cpan.org/

The following modules were not installed
by default and had to be installed as
a prerequisite to compile the other modules.

They are not always part of a distribution.
Install these before the other modules.

Module::Build;
DateTime::Locale;
DateTime::TimeZone;
Params::Validate;
Test::Fatal;
Test::Warnings;
Try::Tiny;

These modules may also need to be installed
They are the ones that are really used
Install these after installing the above modules

DateTime;
File::Find qw(find);
Image::EXIF::DateTime::Parser;
Image::ExifTool qw(ImageInfo);
Getopt::Easy;

These modules should be part of a standard distribution
They probably will not need to be installed 

use Cwd;
use Data::Dumper;
use File::Copy;

These variables can be set true or false (1 or 0)
They should be used with care, they all default to 0
my $DEBUG = 0; # 1 to print debug output, 0 to not
Normally, either $VERBOSE = 1 or $PROGRESS = 1 but not both
my $VERBOSE = 0; # 1 to print output, 0 to run silently except errors
my $PROGRESS = 0; # 1 to show progress, 0 to run silently except errors
my $CONFIRM = 0; # 1 to automatically confirm, 0 to confirm before running
my $OVERWRITE = 0; # 1 to overwrite destination files, 0 to skip
my $REMOVE = 0; # 1 to delete original files, 0 to retain them

These variables set the default values if not passed as arguments
for the directories to copy from and to ($source_dir and $dest_dir)
my $curdir = &getcwd; # get the current working directory "."
my $source_dir = $curdir; # use the current directory to process by default
$dest_dir is where the files will be copied and this directory will be excluded
my $dest_dir = $curdir/gallery"; # use ./gallery for subdirectories to create
my $dest_dir = "$curdir/gallery/"; # hard-coded example

Using get_options from the command line overrides the defaults

get_options "a-automate d-debug o-overwrite p-progress r-remove v-verbose f-from= t-to=";
Using get_options from the Getopts::Easy module populates %O from the command line
Set the variables according to the options passed on the command line:

if ($O{progress}) {
	$PROGRESS = 1;
}
if ($O{debug}) {
	$DEBUG = 1;
	$VERBOSE = 1;
} 
if ($O{verbose}) {
	$VERBOSE = 1;
}
if ($O{automate}) {
	$CONFIRM = 1;
}
if ($O{overwrite}) {
	$OVERWRITE = 1;
}
if ($O{remove}) {
	$REMOVE = 1;
}
if ($O{from}) {
	$source_dir = $O{from};
}
if ($O{to}) {
	$dest_dir = $O{to};
}

These are the regular expressions that are currently available
This list is expanding over time
my $avireg = qr/(\.avi$)/i; # regular expression to match avi files
my $dvreg = qr/(\.dv$)/i; # regular expression to match dv files
my $flvreg = qr/(\.flv$)/i; # regular expression to match flv files
my $gifreg = qr/(\.gif$)/i; # regular expression to match gif files
my $jpgreg = qr/(\.jpe?g$)/i; # regular expression to match jpeg/jpg files
my $m2vreg = qr/(\.m2v$)/i; # regular expression to match m2v files
my $m4vreg = qr/(\.m4v$)/i; # regular expression to match m4v files
my $modreg = qr/(\.mod$)/i; # regular expression to match mod files
my $movreg = qr/(\.mov$)/i; # regular expression to match quicktime files
my $mp4reg = qr/(\.mp4$)/i; # regular expression to match mp4 files
my $mpgreg = qr/(\.mpe?g$)/i; # regular expression to match mpeg/mpg files
my $nefreg = qr/(\.nef$)/i; # regular expression to match Nikon raw nef files
my $pngreg = qr/(\.png$)/i; # regular expression to match png files
my $threegpreg = qr/(\.3gp$)/i; # regular expression to match 3gp files
my $vobreg = qr/(\.vob$)/i; # regular expression to match 3gp files
Add your own regular expression above and then add it to the array below
my @regs = ($jpgreg, $nefreg, $pngreg, $gifreg, $threegpreg, $avireg, 
	$mpgreg, $m2vreg, $m4vreg, $mp4reg, $movreg, $modreg, $flvreg, $dvreg, $vobreg);

These are the variables used for statistics in the "final_report" 
my $files_processed = 0; # track total number of files
my $files_copied = 0; # track the number of files copied
my $files_errors = 0; # track the number of files copied with errors
my $files_skipped = 0; # track the number of files skipped
my $files_deleted = 0; # track the number of files deleted
my $size_copied = 0; # total size copied
my $size_skipped = 0; # total size of files skipped
my $end_time = 0; # time when script finished 
my $total_time = 0; # total time script ran 
my %extensions = (); # file extensions that do not match @regs
my @copies = (); # the files that are in the copies array 
my $copies = ""; # the files that are in the copies scalar 
my @deleted = (); # the files that are deleted array
my $deleted = ""; # the files that are in the deleted scalar 
my @errors = (); # the files with errors in the errors array
my $errors = ""; # the files with errors in the errors scalar
my @skips = (); # the files that are skipped array
my $skips = ""; # the files that are skipped scalar
my $report_title = ""; # the title used in the final report


&main(@ARGV); # Start the program by executing the main function


see the media_date_org.pl file for the code that executes
