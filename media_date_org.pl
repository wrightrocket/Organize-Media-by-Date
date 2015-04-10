#!/usr/bin/env perl
#
# By Keith Wright
# 2014/11/30
# 2015/02/08
#
# media_date_org.pl
#
# Program organizes files matching regular expressions found in the @regs array
# The default "from directory" is the current working directory
# The default "to directory" is the "gallery" subdirectory
# The program accepts the first argument as the "from directory" <FROM_DIR>
# and the second argument as the "to directory" <TO_DIR>
#
# The program then copies from the "from directory" to the "to directory" by
# Organizing media by year, month and day found and
# Creates a directory for each year found
# Creates a subdirectory for each month found
# Creates a subdirectory for each day found
# Then, copies files to subdirectory by day found
# If the copy is the same size as original, it will be deleted if $REMOVE = 1, or -r is used
#
# The following options modify the default behavior of the program:
#
# Automates confirmation if $CONFIRM = 1, or -a option used
# Debugging information printed if $DEBUG = 1, or -d option used
# Overwrites "to file" with "from file" if $OVERWRITE = 1, or -o option used
# Progress codes are printed if $PROGRESS = 1, or -p option used
# Removes "from file" if copied file is same size as "to file" if $REMOVE = 1, or -r option used
# Verbose output will be printed if $VERBOSE = 1, or -v option used
# If -f <FROM_DIR> is used, then the <FROM_DIR> will be used as the $source_dir
# If -t <TO_DIR> is used, then <TO_DIR> will be used as the $dest_dir

# use standard pragmas
use warnings;
use strict;

# allow use of the given statement
use feature "switch";

# This program will not run with the standard perl distribution
# Modules must be installed in order to run this program

# To install modules use the cpan command
# or the package manager for your distribution
# or the package manager for your operating system
 
# In ActiveState Perl use the "ppm" command
#
# To learn more about these  modules search at: 
# http://search.cpan.org/

# The following modules were not installed
# by default and had to be installed as
# a prerequisite to compile the other modules.

# They are not always part of a distribution.
# Install these before the other modules.

use Module::Build;
use DateTime::Locale;
use DateTime::TimeZone;
use Params::Validate;
use Test::Fatal;
use Test::Warnings;
use Try::Tiny;

# These modules may also need to be installed
# They are the ones that are really used
# Install these after installing the above modules

use DateTime;
use File::Find qw(find);
use Image::EXIF::DateTime::Parser;
use Image::ExifTool qw(ImageInfo);
use Getopt::Easy;

# These modules should be part of a standard distribution
# They probably will not need to be installed 

use Cwd;
# use DB;
use Data::Dumper;
use File::Copy;

# print the log of the arrays and the final report on a termination signal
# or a stack trace if there is an error signal
use sigtrap qw(handler term_handler normal-signals
    stack-trace error-signals);

# These variables can be set true or false (1 or 0)
# They should be used with care, they all default to 0
my $DEBUG = 0; # 1 to print debug output, 0 to not
# Normally, either $VERBOSE = 1 or $PROGRESS = 1 but not both
my $VERBOSE = 0; # 1 to print output, 0 to run silently except errors
my $PROGRESS = 0; # 1 to show progress, 0 to run silently except errors
my $CONFIRM = 0; # 1 to automatically confirm, 0 to confirm before running
my $OVERWRITE = 0; # 1 to overwrite destination files, 0 to skip
my $REMOVE = 0; # 1 to delete original files, 0 to retain them
my $LOG = 0; # 1 to log activity to $source_dir/media_date_org-<DATE_TIME>.log, 0 to not 

# These variables set the default values if not passed as arguments
# for the directories to copy from and to ($source_dir and $dest_dir)
my $curdir = &getcwd; # get the current working directory "."
my $source_dir = $curdir; # use the current directory to process by default
# $dest_dir is where the files will be copied and this directory will be excluded
# my $dest_dir = $curdir/gallery"; # use ./gallery for subdirectories to create
my $dest_dir = "/nas/photos/gallery/"; # hard-coded example

# Get the options from the command line and override the defaults
my $options = "a-automate d-debug h-help l-log o-overwrite p-progress r-remove v-verbose f-from= t-to=";
get_options($options);
# Using get_options from the Getopts::Easy module populates %O from the command line
# Set the variables according to the options passed on the command line:

if ($O{help}) {
    &help;
}
if ($O{automate}) {
    $CONFIRM = 1;
}
if ($O{debug}) {
    $DEBUG = 1;
    $VERBOSE = 1;
} 
if ($O{log}) {
    $LOG = 1;
}
if ($O{overwrite}) {
    $OVERWRITE = 1;
}
if ($O{progress}) {
    $PROGRESS = 1;
}
if ($O{remove}) {
    $REMOVE = 1;
}
if ($O{verbose}) {
    $VERBOSE = 1;
}
if ($O{from}) {
    $source_dir = $O{from};
}
if ($O{to}) {
    $dest_dir = $O{to};
}

# These are the regular expressions that are currently available
# This list is expanding over time
my $avireg = qr/(\.avi$)/i; # regular expression to match avi files
my $bmpreg = qr/(\.bmp$)/i; # regular expression to match bmp files
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
my $ppmreg = qr/(\.ppm$)/i; # regular expression to match ppm files
my $threegpreg = qr/(\.3gp$)/i; # regular expression to match 3gp files
my $tifreg = qr/(\.tif?f$)/i; # regular expression to match tif/tiff files
my $vobreg = qr/(\.vob$)/i; # regular expression to match vob files
my $wmvreg = qr/(\.wmv$)/i; # regular expression to match wmv files
# Add your own regular expression above and then add it to the array below
my @regs = ($jpgreg, $nefreg, $pngreg, $gifreg, $threegpreg, $bmpreg,
    $avireg, $ppmreg, $wmvreg, $mpgreg, $m2vreg, $m4vreg, $mp4reg, 
    $tifreg, $movreg, $modreg, $flvreg, $dvreg, $vobreg);

# These are the variables used for statistics in the "final_report" 
my $files_processed = 0; # track total number of files
my $files_copied = 0; # track the number of files copied
my $files_errors = 0; # track the number of files copied with errors
my $files_skipped = 0; # track the number of files skipped
my $files_deleted = 0; # track the number of files skipped
my $size_copied = 0; # total size copied
my $size_deleted = 0; # total size of files skipped
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
my $exiftool = new Image::ExifTool; # create an instance of the exiftool


&main(@ARGV); # Start the program by executing the main function

sub help {
    print "\nUsage media_date_org.pl [-adhloprvft] [from_directory] [to_directory]\n";
    print "\nAvailable options\n";
    my @words = split / /, $options;
    for my $word (@words) {
        my @line = split /-/, $word;
        print "-$line[0] for $line[1]\n";
    }
    print "\n";
    exit
}

sub main {
    $File::Find::dont_use_nlink=1; # always stat directories, so it works on all filesystems
    &check_argv; # if $CONFIRM is not equal to one then arguments or assumptions will be confirmed
    # the $source_dir and $dest_dir can be passed as arguments on the command line 
    if ($PROGRESS) { # to view progress only set $VERBOSE = 0 and $PROGRESS = 1
        print "\$PROGRESS is true, so the following will be output for each file:\n";
        print "\td=directory, c=copied, s=skipped, r=removed, e=error, 0=zero sized file\n\n";
    }
    find(\&process_file, $source_dir); # find every file in the $source_dir and execute process_file 
    ($VERBOSE || $PROGRESS) && &final_report; # print a summary report if $VERBOSE or $PROGRESS
    $LOG && &print_log; # log file activity 
}

sub check_argv {
    $VERBOSE && print "Usage photo_date_org.pl [-adloprv] [-f 'from_dir'] [-t 'to_dir']  <FROM_DIR> <TO_DIR>\n";
    $VERBOSE && print "The following options can be used:\n";
    $VERBOSE && print "a-automate d-debug l-log o-overwrite p-progress r-remove v-verbose f-from <FROM_DIR> t-to <TO_DIR>\n\n";
    $VERBOSE && print "The following defaults will be used:\n\n";
    if (@ARGV) {
        if ($ARGV[0] && $ARGV[1]) {
            $source_dir = $ARGV[0] if (-d $ARGV[0]);        
            $dest_dir = $ARGV[1] if (-d $ARGV[1]);      
        } else {
            $source_dir = $ARGV[0] if (-d $ARGV[0]);        
        }
    }
    ($VERBOSE || $PROGRESS) && print "SOURCE_DIR: $source_dir\n";
    ($VERBOSE || $PROGRESS) && print "DESTINATION_DIR: $dest_dir\n"; 
       
    if (! &confirm) {
        print "Goodbye!\n";
        exit;
    }
}

sub confirm {
    if (!$CONFIRM || $VERBOSE) {
        print "Do you want to continue? (y/n) ";
        my $answer = <STDIN>;
        my @letters = split ('', $answer);
        $answer = lc $letters[0];
        $DEBUG && print "\$answer = $answer\n";
        if ($answer eq 'y') {
            return 1;
        } else {
            return 0;
        }
    } else {
        return 1;
    }
} 

sub process_file {
    my $file = qq($File::Find::name);  # store the full path for later
    $DEBUG && print"Original file name: $_\n"; # $_ set by File::Find::name
    $_ = qq($_); # add double quotes for handling odd file names
    my $filepath = "$curdir/$file";
    $DEBUG && print"Filepath: $filepath\n";
    if (index($filepath, $dest_dir) > 0) {
        print "NOT PROCESSING $dest_dir: It is the <TO_DIR>";
        $PROGRESS && (!$VERBOSE) && print "d";
        return 0; # skip the destination directory
    }
    my $size = (stat("$_"))[7] || 0;
    $DEBUG && print"Filesize: $size\n";
    if (-d "$_") {
        $VERBOSE && print "ENTERING directory: $file\n\n";
        $PROGRESS && (!$VERBOSE) && print "d";
        return 0; # Don't process directory files or count them as skipped
    } elsif (! $size) {
        $VERBOSE && print "SKIPPING empty file: $file\n\n"; # if the file has a size of zero
        $PROGRESS && (!$VERBOSE) && print "0";
        $files_skipped++;
        return 0; # Don't process empty files
    } 
    $DEBUG && $PROGRESS && (!$VERBOSE) && print ".";
    $files_processed++; # track total number of files
    $VERBOSE && print "PROCESSING file #$files_processed: $filepath\n";
    $filepath = qq("$filepath"); # add double quotes for handling odd file names
    my $nomatch = 1; # Set this true here, and false if it doesn't match below
    for my $reg (@regs) { # use regular expressions in @regs to match file
        if ($_ =~ $reg) {
            $nomatch = 0;
            $DEBUG && print "Matching RE: $reg\n";
            &get_date_and_copy($filepath, $size);
            last;
        }
    }
    if ($nomatch) { # Bypass all files that don't match the regular expressions
        $size_skipped += $size;
        $files_skipped++;
        push @skips, $filepath;
        /.*\.(\w+)$/ ; # match the file name extension group
        $VERBOSE && $1 && print "BYPASSING unknown extension: $1\n\n";
        if ($1 && defined $extensions{$1}) { # increment the number found 
            $extensions{$1} = ++$extensions{$1};
        } elsif ($1) { # define the key and set the value to one for the first found
            $extensions{$1} = 1;
        } else {
            $DEBUG && print "UNEXPECTED: This is unexpected for $_\n\n";
        }
    }
}

sub get_date_and_copy {
    my $file = shift;
    my $size = shift;
    $DEBUG && print "\$file variable: $file\n";
    # my $date = `exiftool -CreateDate "$file"`; 
    # avoiding the system command and using a module is much faster
    $exiftool->ExtractInfo($_);
    my $date = $exiftool->GetValue('CreateDate') || "";
    $date = &fix_date($date);
    $DEBUG && print "FOUND CreateDate: $date\n";
    
    if (! $date) {
        # my $date = `exiftool -DateTimeOriginal "$file"`;
        $date = $exiftool->GetValue('DateTimeOriginal');
        $date = &fix_date($date);
        $DEBUG || $VERBOSE && $date && print "FOUND DateTimeOriginal: $date\n";
    } else {
        $DEBUG || $VERBOSE && $date && print "FOUND CreateDate: $date\n";
    }

    if (!$date) { # if the CreateDate or DateTimeOriginal is not available
        # try the ImageGenerated tag
        $date = $exiftool->GetValue('ImageGenerated');
        $date = &fix_date($date);
                $DEBUG && $date && print "FOUND: ImageGenerated of $date\n";
        if (!$date) { # if the CreateDate or DateTimeOriginal or ImageGenerated is not available
            # use the date from the folder org yyyy-m?m-d?d
            if ("$file" =~ /(\d{4})\/(\d{1,2})\/(\d{1,2})\//) {
                my $month = sprintf("%02d", $2);
                my $day = sprintf("%02d", $3);
                $date = "$1-$month-$day 00:00:00";
                $DEBUG || $VERBOSE && $date && print "FOUND Folder date: $date\n";
            } else { # Use FileModificationDate as final fallback way to determine date
                $date = $exiftool->GetValue('FileModifyDate');
                $DEBUG || $VERBOSE && $date && print "FOUND File modification date: $date\n";
            }
        }
    }

    my $parser = Image::EXIF::DateTime::Parser->new;
    my $time_shot = $parser->parse($date);
    my $dest = &make_dirs($time_shot);
    &copy_delete_file($file, $dest, $size);
}

sub fix_date {
    my $date = shift;
    $DEBUG && $date && print "\$date: $date\n";
    if ($date) {
        # Fix problem with date unknown
        if ($date =~ /unknown/) {
             $date = "2000/01/01 00:00:00";
                }

        # Fix problem with     :   :       :   : 
        if ($date =~ /\s+:\s+:\s+:\s+:/ ) {
            $date = "2000/01/01 00:00:00";
        }

        # Fix problem with dates separated by colons
        $date =~ s/(\d{4}):(\d{1,2}):(\d{1,2}) (\d{2}:\d{2}:\d{2})/$1-$2-$3 $4/;

        # if non-standard format of 07/29/2011 17:56:37
        # change from mm/dd/yyyy HH:MM:SS to yyyy-mm-dd HH:MM:SS
        if ($date =~/^(\d{2})\/(\d{2})\/(\d{4}) (.*)$/) {
            $date = "$3-$2-$1 $4";
        }
        
        # Fix problem with trailing newline
        chomp $date;
    
        # Fix problem with all zeros date 0000-00-00 00:00:00
        if ($date =~ /(0{4})-(0{2})-(0{2})/) {
            $date = "";
        }
        # Fix problem with 2011:06:26 19:02-07:00
        $date =~ s/([0123456789:]+) ([0123456789:]{5})-([0123456789:]+)/$1 $2:00-$3/; 
        
        # Fix problem with Sat Apr 18 14:32:56 2009
        if ($date =~ /\w+ (\w+) (\d+) ([0123456789:])+ (\d{4})/) {
            my $month = $1;
            my $mon = "01";
            given ($month) {
                $mon = "01" if /jan/i;
                $mon = "02" if /feb/i;
                $mon = "03" if /mar/i;
                $mon = "04" if /apr/i;
                $mon = "05" if /may/i;
                $mon = "06" if /jun/i;
                $mon = "07" if /jul/i;
                $mon = "08" if /aug/i;
                $mon = "09" if /sep/i;
                $mon = "10" if /oct/i;
                $mon = "11" if /nov/i;
                $mon = "12" if /dec/i;
            }           
            my $day = sprintf("%02d", $2);
            $date = "$4-$mon-$day $3";
            $DEBUG && print "Date problem Sat Apr 18 14:32:56 2009\n"; 
        }
        # Fix problem with incomplete time
        # 2009-04-18 6
        if ($date =~ /(\d+)-(\d+)-(\d+) ?([0123456789:]{0,2})/) {
            $date = "$1-$2-$3 00:00:00";
        }

    }
    $DEBUG && $date && print "Date Info in \$date: $date\n";
    return $date;
}

sub make_dirs {
    my $time_shot = shift;
    my $datetime = DateTime->from_epoch(epoch => $time_shot);
    my $month = sprintf("%02d", $datetime -> month); # pad month number with a zero for a two digit month
    my $year = sprintf("%04d", $datetime -> year); # use a four digit year
    my $day = sprintf("%02d", $datetime -> day); # pad day number with a zero for a two digit day
    # The following lines will attempt to create the directory for the day the file was created, if the directory does not exist
    # If the "to directory" -t path or $dest_dir/$year/$month/$day does not exist, 
    # attempt to create it, but exit if it fails with die
    # TIP: Make sure that the $dest_dir directory has read, write and execute permission for the user
    if (! -d "$dest_dir") {
        mkdir "$dest_dir" || die "Unable to create $dest_dir";
    }
    if (! -d "$dest_dir/$year") {
        mkdir "$dest_dir/$year" || die "Unable to create $dest_dir/$year";
    }
    if (! -d "$dest_dir/$year/$month") {
        mkdir "$dest_dir/$year/$month" || die "Unable to create $dest_dir/$year/$month";
    }
    if (! -d "$dest_dir/$year/$month/$day") {
         mkdir "$dest_dir/$year/$month/$day" || die "Unable to create $dest_dir/$year/$month/$day";
    }
    return "$dest_dir/$year/$month/$day"; 
}

sub copy_delete_file {
    my $source = shift;
    my $dest = shift;
    $dest =~ s|/$||; # remove any trailing slash
    my $s_size = shift;
    my $path = "$dest/$_";
    my $filepath = $source;
    
    if (-r "$path") {
        $DEBUG && print"Path: $path\n";
        $DEBUG && print"Source Size: $s_size\n";
        my $d_size = ((stat($path))[7] || 0);
        $VERBOSE && print "COMPARING: Size of source $s_size and destination $d_size\n";
        if ($s_size == $d_size) {
                if ($OVERWRITE) {
                    $VERBOSE && print "FILES ARE IDENTICAL: Copying as \$OVERWRITE is true\n";
                    &do_copy_delete_file($source, $dest, $s_size);
                } else {
                    $VERBOSE && print "FILES ARE IDENTICAL: Skipping as \$OVERWRITE is false\n";
                    $PROGRESS && (!$VERBOSE) && print "s";
                    $files_skipped++;
                    $size_skipped += $s_size;
                    push @skips, $filepath;
                }   
        } elsif ($s_size && !$d_size) {
                $VERBOSE && print "COPYING FILE: Destination $path is size 0, overwriting empty file\n";
                &do_copy_delete_file($source, $dest, $s_size);
        } else {
             
            if ($OVERWRITE) {
                    $VERBOSE && print "FILES ARE DIFFERENT SIZE: Copying as \$OVERWRITE is true\n";
                    &do_copy_delete_file($source, $dest, $s_size);
            } else {
                    $VERBOSE && print "FILES ARE DIFFERENT SIZE: Skipping as \$OVERWRITE is false\n";
                $PROGRESS && (!$VERBOSE) && print "s";
                $files_skipped++;
                $size_skipped += $s_size;
                push @skips, $filepath;
            }   
        }
        if ($REMOVE) {
            if ($s_size = $d_size) {
                $VERBOSE && print "DELETING: Deleting file as \$REMOVE is true, or -r option used\n";
                if (unlink "$_") {
                    $VERBOSE && print "DELETED source file: copy is same size as original\n\n";
                    $files_deleted++;
                    $size_deleted += $s_size;
                    push @deleted, "$source";
                } else {
                    warn "\nDELETE FAILED: Could not unlink $source: $!";
                }
            } else {
                $VERBOSE && print "RETAINING FILE: copy differs in size from original\n";
            }
        } else {
                $VERBOSE && print "RETAINING FILE: Retaining file as \$REMOVE is false\n\n";
            
        }
    } else {
        $VERBOSE && print "COPYING FILE: Destination $path does not exist\n";
        &do_copy_delete_file($filepath, $dest, $s_size)
    }
}

sub do_copy_delete_file {
    my $source = shift;
    my $dest = shift;
    my $s_size = shift;
    $source =~ s/\/$//g;
    if (copy($_, $dest)) {
        $VERBOSE && print "COPIED $_ to: $dest\n";
        $size_copied += $s_size;
        $files_copied++;
        $PROGRESS && (!$VERBOSE) && print "c";
        push @copies, ($source, "$dest");
        if ($REMOVE) {
            my $size = (stat("$dest/$_"))[7] || 0;
            if ($s_size = $size) {
                $VERBOSE && print "DELETING: Deleting file as \$REMOVE is true, or -r option used\n";
                if (unlink $_) {
                    $VERBOSE && print "DELETED source file: copy is same size as original\n\n";
                    $files_deleted++;
                    $size_deleted += $size;
                    push @deleted, "$source";
                    $PROGRESS && (!$VERBOSE) && print "r";
                }
                else { 
                    warn "DELETE FAILED: Could not unlink $source: $!";
                    push @errors, "$source";
                    $PROGRESS && (!$VERBOSE) && print "e";
                }
            }  else {
                $VERBOSE && print "RETAINING FILE: copy differs in size from original\n\n";
            }
        } else {
                $VERBOSE && print "RETAINING FILE: Retaining file as \$REMOVE is false\n\n";
        }
    } else {
        warn "\n$/$_ $!\n"; 
        $files_errors++;
        $PROGRESS && (!$VERBOSE) && print "e";
        push @errors, "$source";
    }
}

sub time_total {
    $end_time = time();
    return $end_time - $^T;
}

sub print_extensions {
    print "\n\nThe following file extensions were not processed:\n";
    print "File Extension\t\tFiles Found\n\n";
    my $times = 1;
    for my $ext (keys %extensions) {
        $times = $extensions{$ext};
        print "\t$ext\t\t$times\t\n";
    }
    print "\n\n";
}

sub print_arrays {
    # first argument is the message
    my $message = shift; 
    my $copy_flag = 0;
    if ($message =~ /copied/) {
        $copy_flag = 1;
    }
    if (scalar @_) {
        my $count = 0;
        for (@_) {
            # print copies differently
            if ($copy_flag) {
                if (++$count % 2) {
                    $message .= "From:\t$_\n";
                } else {
                    $message .= "To:\t$_\n";
                }
            } else { 
            # print other arrays the same
                 $message .= "$_\n";
            }
        }
    } else {
        $message = "\tNone\n";
    }
    $message .= "\n";
    return $message;
}

sub term_handler {
    # This is called automatically on termination signals by using sigtrap
    &final_report;
    &print_log;
    print "\n\nExiting\n";
    exit;
}

sub print_log {
    # This should be the last function to use, as it will exit the program
    my  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    $mon = sprintf("%02d", $mon);
    $mday = sprintf("%02d", $mday);
    $hour = sprintf("%02d", $hour);
    $min = sprintf("%02d", $min);
    $sec = sprintf("%02d", $sec);
    
    my $logfile = "$source_dir/media_date_org-$year-$mon-$mday-$hour-$min-$sec.log";
    print "\n\nWriting log file $logfile\n";
    open LOGFILE, ">$logfile" or die;
    print LOGFILE $copies if $copies;
    print LOGFILE $errors if $errors;
    print LOGFILE $deleted if $deleted;
    print LOGFILE $skips if $skips;
    close LOGFILE;
}

sub final_report {
    if ($DEBUG) {
        print "\nDumping \@copies\n" && print Dumper(@copies);
        print "\nDumping \@deleted\n" && print Dumper(@deleted);
        print "\nDumping \@errors\n" && print Dumper(@errors);
        print "\nDumping \@skips\n" && print Dumper(@skips);
    }
    $total_time = &time_total;
    $report_title = "Report for organizing: " . $source_dir;
    $size_copied = $size_copied / 1048576 if $size_copied;
    $size_deleted = $size_deleted / 1048576 if $size_deleted;
    $size_skipped = $size_skipped / 1048576 if $size_skipped;
    $copies = &print_arrays("\nThe following files were copied\n\n", @copies);
    $errors = &print_arrays("\nThe following files had copy errors\n\n", @errors);
    $deleted = &print_arrays("\nThe following files were deleted\n\n", @deleted);
    $skips = &print_arrays("\nThe following files were skipped\n\n", @skips);
    write STDOUT; # write directly to a format, although STDOUT is implied
    $- = 0; # Start a new page
    $^ = "SUMMARY_TOP"; # select new formats without having to open a file handle
    $~ = "SUMMARY";
    write;
    &print_extensions;
}

format STDOUT_TOP =
# centered
@||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
                                $report_title

PAGE
@####
$%

.
# End of STDOUT_TOP format 

format STDOUT =


@||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
                $report_title

@||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
"Details about processing:"

Files skipped: 

   @*
   $skips

Files copied:           

   @*
   $copies

Files deleted:          

   @*
   $deleted

Files with errors on copy:  
                
   @*
   $errors 
.
# End of STDOUT format

format SUMMARY_TOP =
# centered
@||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
                                $report_title
@||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
                                  "Summary" 

PAGE
@####
$%
.
# End of SUMMARY_TOP format

format SUMMARY =

Time in seconds processing:     @>>>>>>>>>>
                $total_time

Files processed:                @>>>>>>>>>>
                $files_processed

Files skipped:                  @>>>>>>>>>>
                $files_skipped

Size of files skipped:          @#######.## MiB
                $size_skipped

Files copied:                   @>>>>>>>>>>
                $files_copied

Size of files copied:           @#######.## MiB
                $size_copied
       
Files with errors on copy:      @>>>>>>>>>>
                $files_errors

Files deleted as identical:     @>>>>>>>>>>
                $files_deleted

Size of files deleted:          @#######.## MiB
                $size_deleted
       

End of processing summary

.
# End of SUMMARY format
