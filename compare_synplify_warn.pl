#!/usr/local/bin/perl
use Data::Dumper;
#
#---------------------------------------------
#---------------------------------------------
#--
#-- Author Marlon Roa 
#-- Intent: Run only in Windows
#-- Function: Script compares results from Synplify synthesis with and existing 
#--            dataBase. If the DBase does not exist, this script creates one based on
#--            the current report file (*.srr).
#--
#-- NOTES: 
#-- * After synplify run this script, if no Dbase a new is created and no comparison or report takes place.
#-- * If you want to update DBase, remove current Dbase file and recreate using current file (there is no option to add individual entries)
#-- * Update fpga_name and main_path variables only when adding teh script to a Covaro FPGA flow.
#-- * The directory structure assume is that one used thru teh life of Covaro company up to today, if trying to reuse somwhere else 
#--   you are on your own).
#---------------------------------------------
#---------------------------------------------
#
#
my $fpga_name = "mcc1800_mac_tx"; #mcc1800
my $user      = "uname";
my $blevel    = 1;
#
# DO NOT CHANGE ANYTHING BELOW THIS POINT
#=========================================
#
my $os = $ENV{'OS'};
if ($os =~ /windows/gi)  { $os = "w"}
else   { $os = "u"}
#
my $main_path   = "/projects/asic/user/".$user."/code/ASIC/mcc1800/syn/".$fpga_name; # I: Assuming blevel always in unix.
if ($os eq "w")
  { $main_path   = "C:\\projects\\asic\\user\\".$user."\\code\\ASIC\\".$fpga_name."\\syn\\".$fpga_name."_top";
    if ($blevel == 1)
      { $main_path   = "Z:\\user\\".$user."\\code\\ASIC\\mcc1800\\syn\\".$fpga_name;}
  }
#
my $log_path    = $main_path."/log_files";
if ($os eq "w")
  { $log_path    = $main_path."\\log_files";}
#
my $srr_path    = $main_path."/rev_1";
if ($os eq "w")
  { $srr_path    = $main_path."\\rev_1";}
#
my $srr_suffix = "_top.srr";
if ($blevel == 1)
{ $srr_suffix = ".srr";}
#
my $code_path1 = "c_projects_asic_ws_code_asic_". $fpga_name . "_";
my $code_path2 = $code_path1;
if ($blevel == 1)
{ $code_path1 = "z_ws_code_asic_";
  $code_path2 = "z_user_".$user."_code_asic_";
}
#-------------------------
#
my $hash_path   = $main_path;
#
my $script_name   = "compare_synplify_warnings";
my $log_file      = $script_name . ".log";
#
my $synplify_file = $fpga_name . $srr_suffix;
my $DEF_HASH_FILE = $script_name."_hash.txt";
$RTL_PATH_ARR[0] = $code_path1;
@RTL_PATH_ARR[1,2,3] = qw(common_ ram_rtl_ rtl_);
$RTL_PATH_ARR[4] = $code_path2;
#
#
my (@file_array) = ();
my (%file_hash_warn, %file_hash_error, %file_hash_notes, %file_hash_info) = ();
my (%main_file_hash, %main_saved_hash) = ();
my ($file_ix, $saved_ix, $found_match) = 0;
my ($debug, $saved_hash_exist, $old_entries) = 0;
#
# Debug:
# 0 = None
# 1 = Loading of log_file and hash_file
# 2 = Print main_*_hash
# 3 = Debug print for comparisons.
$debug = 0;
#
# ====================================
# Open log file
# ====================================
#
if (!-e "$log_path")
{ die "Dir $log_path does not exists\n";}
#
if ($os eq "w")
  { open(log_file, ">$log_path\\$log_file") || die "*ERROR: Could not create $log_file. Quitting.\n";}
else
  { open(log_file, ">$log_path/$log_file") || die "*ERROR: Could not create $log_path/$log_file. Quitting.\n";}
#
# ====================================
# Read DataBase Hash
# ====================================
#
$saved_hash_exist = 0;
if ($os eq "w")
  { if (-e "$hash_path\\$DEF_HASH_FILE")
      { $saved_hash_exist = 1;}
  }
else
  { if (-e "$hash_path/$DEF_HASH_FILE")
      { $saved_hash_exist = 1;}
  }
#
if ($saved_hash_exist == 1)
{ &sub_load_saved_hash;}
#
printf log_file "DBG: saved_hash_exist : $saved_hash_exist\n" if ($debug == 1);
#
# ====================================
# Parse log file
# ====================================
#
if (-e "$srr_path")
  { if ($os eq "w")
      { open(list_handle, "$srr_path\\$synplify_file") || die "--ERROR : Could not open $synplify_file file.\n";}
    else
      { open(list_handle, "$srr_path/$synplify_file") || die "--ERROR : Could not open $synplify_file file.\n";}
    @file_array = <list_handle>;
    close(list_handle);
  }
else 
  { printf log_file "--ERROR : File $synplify_file does not exist.\n";
    die "--ERROR : File $synplify_file does not exist.\n";}
#
foreach my $line (@file_array)
  { chomp($line);
    $line =~ s/\:\"(\w{1})\:/:$1/gi;
    $line =~ s/\"//g;
    #print log_file ("DBG_0: $line\n");
    $line =~ s/\|/:/g;
    #print log_file ("DBG_1: $line\n");
    $line =~ s/\\/_/g;
    # Change message [] delimeters to <> to improve matching
    $line =~ s/\[/</g;
    $line =~ s/\]/>/g;
    $line =~ s/<(\d+):(\d+)>/<$1_$2>/g;
    #
    # Ex: @N: CG364 :"C:\Program Files\synplicity\fpga_80\lib\xilinx\unisim.v":8503:7:8503:11|Synthesizing module IBUFG
    #     [0] = W: [1] = CG364 [2] = Path [3] = sline [4] = scol [5]=eline [6]= ecol [7] = mesasge.
    @line_array = split (":", $line);
    $line_array[1] =~ s/\s+//g;
    if ($debug == 1)
    { print log_file "--..---------------------------------------------------------------------------\n";
      print log_file Dumper @line_array;
      print log_file "DBG_LINE_LOG: $line\n";
    }
    #
    # HASH STRUCT: %file_hash_warn = ( <Warn_code> => 
    #                                          ( path => [], sline => [], message => [$entry], exist->[])
    #                                );
    if ($line =~ /^\@E:/g)
      { &sub_load_file_hash(\@line_array, "E");
      } # eo if Error
    #
    if ($line =~ /^\@W:/g)
      { 
	if ($line_array[1] =~ /\s?\w{1,2}\d{3,4}\b/g)
	  { 
	    &sub_load_file_hash(\@line_array, "W");
	  }
	else
	  { 
	    &sub_load_file_hash(\@line_array, "W", "ZZ777");
	  }
      } # eo if warning
    #
    # FYI: NOTES have a bug in the report for the msg below as it does not print the path.
    # "@N: MF179 :|Found 12 bit by 12 bit '==' comparator, 'COMBO.read_state_next45'"
    #
    if ($line =~ /^\@N:/g && $line_array[1] =~ /\s?\w{1,2}\d{3,4}\b/g)
      { #&sub_load_file_hash(\@line_array, "N");
	if ($line_array[2] =~ /$RTL_PATH_ARR[0]/ig || $line_array[2] =~ /$RTL_PATH_ARR[4]/ig)
	{&sub_load_file_hash(\@line_array, "N");}
      } # eo if Note
   
  } # eo foreach my $line (@file_array)

if ($debug == 2)
  { printf log_file "\nDBG: main_file_hash\n";
    print log_file Dumper %main_file_hash;
  }
#
# ====================================
# Compare All file vs DBase, mark Dbase matches as existing
# ====================================
#
# Report ERRORS
printf log_file "\nINFO : Looking for errors in $synplify_file file\n";
printf "\nINFO : Looking for errors in $synplify_file file\n";
$tmp = keys %{$main_file_hash{error}};
if ($tmp > 0)
  { printf log_file "-- ERROR : Found %d ERRORS in report\n", $tmp;
  }
else 
  { printf log_file "\t No errors found\n";}
#
if ($saved_hash_exist == 1)
  { #
    # Compare Notes
    &sub_compare_items("N");
    #
    # Compare Warnings 
    &sub_compare_items("W");
    #
    # Compare Errors
    &sub_compare_items("E");
  } # eo $saved_hash_exist == 1
else
  { printf log_file "\nINFO : No DataBase found. Hence, NO comparison vs $synplify_file takes place\n";
    printf "\nINFO : No DataBase found. Hence, NO comparison vs $synplify_file takes place\n";
  }
#
# ====================================
# Report Results
# ====================================
#
# New Warning codes from file
if ($saved_hash_exist == 1)
  { #
    &sub_report_results("N");
    #
    &sub_report_results("W");
    #
    &sub_report_results("E");
    #
    printf log_file "\n";
    printf log_file "\t<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>\n";
    printf log_file "\t<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>\n";
    printf log_file "\t            REPORT OF TOTALS\n";
    printf log_file "\t<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>\n";
    printf log_file "\t<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>\n";
    printf log_file "\n";
    #
    &sub_report_totals("N");
    #
    &sub_report_totals("W");
    #
    &sub_report_totals("E");
  }
#
# ====================================
# Save DataBase Hash
# ====================================
#
if ($saved_hash_exist == 0) 
  {  printf log_file "\nINFO : Creating a new $DEF_HASH_FILE using main_file_hash\n";
     printf "\nINFO : Creating a new $DEF_HASH_FILE using main_file_hash\n";
     if ($os eq "w")
       { open (SAVE,">$hash_path\\$DEF_HASH_FILE") || die "--ERROR : Could not save $DEF_HASH_FILE";}
     else
       { open (SAVE,">$hash_path/$DEF_HASH_FILE") || die "--ERROR : Could not save $DEF_HASH_FILE";}
     select (SAVE);
     if ($saved_hash_exist == 0)
       {  print Dumper \%main_file_hash;}
     else
       {  print Dumper \%main_saved_hash;}
     select (STDOUT);
     close SAVE;
}
#
# ====================================
# Exit script
# ====================================
#
my $secs = 5;
printf log_file "\nINFO : Freeze shell for $secs seconds so you can review results...\n";
printf "\nINFO : Freeze shell for $secs seconds so you can review results...\n"; 
if ($os eq "w")
  { printf "\t log file at: $log_path\\$log_file\n";}
else
  { printf "\tLog File at: $log_path/$log_file\n";}
sleep ($secs);
printf "\nINFO : Done!\n";
printf log_file "\nINFO : Done!\n";

#
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#<<                                    SUBROUTINES                                           <<
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#
sub sub_load_saved_hash {
  my ($tmp) = 0;
  printf log_file "\nINFO : Loading saved Hash\n";
  printf "\nINFO : Loading saved Hash\n";
  if ($os eq "w")
    { $tmp = do "$hash_path\\$DEF_HASH_FILE" or  die "\nCould not recup $DEF_HASH_FILE\n";}
  else
    { $tmp = do "$hash_path/$DEF_HASH_FILE" or  die "\nCould not recup $DEF_HASH_FILE\n";}
  %main_saved_hash = %{$tmp};
  foreach $key (keys %main_saved_hash)    
    {  if ($debug == 4)
	{ printf log_file "\n$key\n=========\n";
	}
       #
      foreach $code (keys %{$main_saved_hash{$key}})
	{  for ($i=0;$i<=$#{$main_saved_hash{$key}{$code}{exist}};$i++)
	     {  $main_saved_hash{$key}{$code}{exist}[$i] = 0;}	   
	   # 
	   #-------------------	
	   if ($debug == 4)
	     { printf log_file "\n$code\n---------\n";
	       #
	       $j=0;
	       foreach $entry (@{$main_saved_hash{$key}{$code}{path}})
		 { $tmp = $entry; 
		   foreach $path (@RTL_PATH_ARR) {$tmp =~ s/$path//g;}
		    $line_num = $main_saved_hash{$key}{$code}{sline}[$j];
		    printf log_file "\t\t-> $tmp : %4d : %s \n", $line_num, $main_saved_hash{$key}{$code}{message}[$j];
		    $j++;
		  } # eo foreach $exist (@{$main_saved_hash{$main_key}{$code}{exist}})
	     } # eo  if ($debug == 4)
	   #-----------
	   #
	 }
    }
  #
  if ($debug == 2)
    { print log_file Dumper %main_saved_hash;
      printf log_file "DBG: Print Keys\n";
      print log_file Dumper (keys %main_saved_hash);
    }
} # eo sub_load_saved_hash;

sub sub_load_file_hash ($$; $)
  {
    my ($iarr, $option, $icode) = @_;
    my ($main_key)              = 0;
    my (@tmp_arr)               = ();
    #
    if ($option eq "W")
      { $main_key = "warn";
      }
    if ($option eq "E")
      {	$main_key = "error";
      }
    if ($option eq "N")
      {	$main_key = "note";
      }
    if (defined $icode)
      { $tmp_arr[0] = $iarr->[0];
	$tmp_arr[1] = $icode;
	$tmp_arr[2] = $iarr->[1];
	$tmp_arr[3] = $iarr->[2];
	$tmp_arr[7] = $iarr->[6];
	@{$iarr} = @tmp_arr;
      }
    printf log_file "\t ICODE: $icode\n" if ($option eq "W" && $debug == 1);
    #
    $iarr->[1] =~ s/\s+//g;
    $iarr->[2] =~ s/\s+//g;
    #
    $iarr->[2] =~ tr/[A-Z]/[a-z]/;
    $iarr->[3] =~ tr/[A-Z]/[a-z]/;
    $iarr->[7] =~ tr/[A-Z]/[a-z]/;
    print log_file ("DBG1(Loading Hash from log): $icode : $iarr->[1] : path => $iarr->[2], sline => $iarr->[3], message => $iarr->[7]\n") if ($debug == 1);
    push (@{$main_file_hash{$main_key}{$iarr->[1]}{path}},    $iarr->[2]);  # Path
    push (@{$main_file_hash{$main_key}{$iarr->[1]}{sline}},   $iarr->[3]); # Start line
    push (@{$main_file_hash{$main_key}{$iarr->[1]}{message}}, $iarr->[7]); # Warning message
    push (@{$main_file_hash{$main_key}{$iarr->[1]}{exist}},   0);
    #
  }

sub sub_compare_items ($)
{   my ($option) = @_;
    my (@tmp) = ();
    my ($hfile_ptr, $hsave_ptr, $ncode_ptr, $nentry_ptrentry, $main_key, $logo) = 0;
    my ($file_ix, $saved_ix, $found_match, $entry, $path ) = 0;
    #
    if ($option eq "W")
      { $hfile_ptr  = \%{$main_file_hash{warn}};
	$hsave_ptr  = \%{$main_saved_hash{warn}};
	$ncode_ptr  = \@new_warn_codes;
	$nentry_ptr = \%new_warn_entry;
	$main_key   = "warn";
	$logo       = "WARNINGS";
      }
    if ($option eq "E")
      { $hfile_ptr  = \%{$main_file_hash{error}};
	$hsave_ptr  = \%{$main_saved_hash{error}};
	$ncode_ptr  = \@new_error_codes;
	$nentry_ptr = \%new_error_entry;
	$main_key   = "error";
	$logo       = "ERRORS";
      }
    if ($option eq "N")
      { $hfile_ptr  = \%{$main_file_hash{note}};
	$hsave_ptr  = \%{$main_saved_hash{note}};
	$ncode_ptr  = \@new_note_codes;
	$nentry_ptr = \%new_note_entry;
	$main_key   = "note";
	$logo       = "NOTES";
      }
    #
    @tmp = keys %{$hfile_ptr};
    if (($#tmp+1) > 0)
      { printf log_file "\nINFO : Comparing $logo between Data base and $synplify_file\n";
	printf "\nINFO : Comparing $logo between Data base and $synplify_file\n";
	foreach $code (keys %{$hfile_ptr})
	  { if (exists $hsave_ptr->{$code})
	      { $file_ix = 0;
		foreach $path (@{$hfile_ptr->{$code}{path}})
		  { $saved_ix = 0;
		    $found_match =0;
		    $entry = $main_file_hash{$main_key}{$code}{path}[$file_ix];
		    if ($debug == 3) 
		      { foreach $path (@RTL_PATH_ARR) { $entry =~ s/$path//g;}
			printf log_file "\n\tDBG: Looking for %s : %s : %s : %s\n", $main_key, $code, $entry, $main_file_hash{$main_key}{$code}{message}[$file_ix];
		      }	
		  FIND_PATH_IN_SHASH: foreach $spath (@{$hsave_ptr->{$code}{path}})
		      { 
			if ($spath eq $path && $hsave_ptr->{$code}{message}[$file_ix] == $hfile_ptr->{$code}{message}[$saved_ix] &&
			   $hsave_ptr->{$code}{exist}[$saved_ix] == 0)
			  {
			    $found_match = 1;			  
			    $hsave_ptr->{$code}{exist}[$saved_ix] = 1; #report
			    printf log_file "\t * Found Match\n" if ($debug == 3);
			    last FIND_PATH_IN_SHASH;
			}
			$saved_ix++;
		      } # eo FIND_PATH_IN_SHASH;
		    #
		    if ($found_match == 0)
		      { printf log_file "\t * No match found\n" if ($debug == 3);
			push(@{$nentry_ptr->{$code}}, $file_ix); #report
		      }
		    $file_ix++;
		  } # eo foreach $path (@{$main_file_hash{warn}{$code}{path}})
	      }
	    else
	      { push (@{$ncode_ptr}, $code);}
	  } #eo foreach $item (keys %{$main_file_hash{warn}})
      }
    else
      {	printf log_file "\nINFO : No $logo found in $synplify_file file\n";
	printf "\nINFO : No $logo found in $synplify_file file\n";
      } # eo  if (grep {$_ eq $main_key} keys %main_file_hash)
} # eo sub_compare_items

sub sub_report_results ($)
{   my ($option) = @_;
    my (@tmp) = ();
    my ($i, $j, $exist, $old_entries, $code, $entry, $path, $tmpf, $tmps) = 0;
    my ($line_nnum) = 0;
    if ($option eq "W")
      {	$ncode_ptr  = \@new_warn_codes;
	$nentry_ptr = \%new_warn_entry;
	$main_key   = "warn";
	$logo       = "WARNINGS";
      }
    if ($option eq "E")
      {	$ncode_ptr  = \@new_error_codes;
	$nentry_ptr = \%new_error_entry;
	$main_key   = "error";
	$logo       = "ERRORS";
      }
    if ($option eq "N")
      {	$ncode_ptr  = \@new_note_codes;
	$nentry_ptr = \%new_note_entry;
	$main_key   = "note";
	$logo       = "NOTES";
      }
    #
    printf log_file "\n";
    printf log_file "\t<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>\n";
    printf log_file "\t<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>\n";
    printf log_file "\t            REPORT OF  $logo\n";
    printf log_file "\t<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>\n";
    printf log_file "\t<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>\n";
    printf log_file "\n";
    if ($#{$ncode_ptr} >= 0)
      { printf log_file "\nINFO : New $logo codes were found in $synplify_file\n";
	printf "\nINFO : New $logo codes were found in $synplify_file\n";
	foreach $code (@{$ncode_ptr})
	  { 
	    printf log_file "\t$logo for code %s:\n", $code;
	    $j=0;
	    foreach $entry (@{$main_file_hash{$main_key}{$code}{path}})
	      { foreach $path (@RTL_PATH_ARR) {$entry =~ s/$path//g;}
		$line_num = $main_file_hash{$main_key}{$code}{sline}[$j];
		printf log_file "\t\t-> $entry : %4d : %s \n", $line_num, $main_file_hash{$main_key}{$code}{message}[$j];
		$j++;
	      } # eo foreach $entry (@{$main_file_hash{$main_key}{$item}{path}})
	  } # eo  foreach $item (@{$ncode_ptr})
      }
    else 
      { printf log_file "\nINFO : No New $logo codes were found in $synplify_file\n";
	printf "\nINFO : No New $logo codes were found in $synplify_file\n";
      }
    #
    # New Warning items for existing codes from file
    #
    @tmp = keys %{$nentry_ptr};
    if (@tmp > 0)
      {  foreach $code (@tmp)
	   {  printf log_file "\nINFO : New Entries for $logo code $code were found in $synplify_file\n";
	      printf "\nINFO : New Entries for $logo code $code were found in $synplify_file\n";
	      foreach $index (@{$nentry_ptr->{$code}})
		{ $entry =  $main_file_hash{$main_key}{$code}{path}[$index];
		  foreach $path (@RTL_PATH_ARR) {$entry =~ s/$path//g;}
		  $line_num = $main_file_hash{$main_key}{$code}{sline}[$index];
		  printf log_file "\t\t-> $entry : %4d : %s \n", $line_num, $main_file_hash{$main_key}{$code}{message}[$index];
		} # eo foreach $index (@{$new_warn_entry{$code}})
	    } # eo foreach $code (@tmp)
       }
    else
      { printf log_file "\nINFO : No New Entries for $logo in $synplify_file\n";
	printf "\nINFO : No New Entries for $logo in $synplify_file\n";
      }
    #
    # Warnings from Data Base not found in file.
    printf log_file "\nINFO : $logo entries in DataBase not found in $synplify_file\n";
    printf "\nINFO : $logo entries in DataBase not found in $synplify_file\n";
    $old_entries = 0;
    foreach $code (keys %{$main_saved_hash{$main_key}})
      { $j=0;
	foreach $exist (@{$main_saved_hash{$main_key}{$code}{exist}})
	  { if ($exist == 0)
	      {  $entry = $main_saved_hash{$main_key}{$code}{path}[$j];
		 foreach $path (@RTL_PATH_ARR) {$entry =~ s/$path//g;}
		 $line_num = $main_saved_hash{$main_key}{$code}{sline}[$j];
		 printf log_file "\t\t-> $code : $entry : %4d : %s \n", $line_num, $main_saved_hash{$main_key}{$code}{message}[$j];
		 $old_entries++;
	       }
	    $j++;
	  } # eo foreach $exist (@{$main_saved_hash{$main_key}{$code}{exist}})
      } # eo foreach $code (keys %main_saved_hash)
    #
    if ($old_entries == 0)
      {  printf log_file "\tAll entries in DataBase found in $synplify_file\n";
	 printf "\tAll entries in DataBase found in $synplify_file\n";}
  } # eo sub sub_report_results

sub sub_report_totals ($)
{   my ($option) = @_;
    my (@tmp)    = ();
    my ($i, $j, $exist, $old_entries, $code, $entry, $path, $tmpf, $tmps) = 0;
    if ($option eq "W")
      {	$ncode_ptr  = \@new_warn_codes;
	$nentry_ptr = \%new_warn_entry;
	$main_key   = "warn";
	$logo       = "WARNINGS";
      }
    if ($option eq "E")
      {	$ncode_ptr  = \@new_error_codes;
	$nentry_ptr = \%new_error_entry;
	$main_key   = "error";
	$logo       = "ERRORS";
      }
    if ($option eq "N")
      {	$ncode_ptr  = \@new_note_codes;
	$nentry_ptr = \%new_note_entry;
	$main_key   = "note";
	$logo       = "NOTES";
      }
    #
    # Total number warnings per code
    printf log_file "\nINFO : $logo Totals:\n";
    printf log_file "\nCODE\t FILE\t DBASE\tNOTES\n";
    printf log_file "===================================\n";
    printf  "\nINFO : $logo Totals:\n";
    printf  "\nCODE\t FILE\t DBASE\tNOTES\n";
    printf  "===================================\n";
    #
    $code = "NONE ";
    $tmpf = 0;
    $tmps = 0;
    $tmp = keys %{$main_file_hash{$main_key}};
    #
    if ($tmp <= 0)
      {	printf log_file "%5s\t%3d\t%3d\tNONE\n", $code, $tmpf, $tmps;
	printf "%5s\t%3d\t%3d\tNONE\n", $code, $tmpf, $tmps;
      }
    else
      {
	foreach $code (keys %{$main_file_hash{$main_key}})
	  { printf log_file "%5s\t", $code;
	    printf "%5s\t", $code;
	    $tmpf = $#{$main_file_hash{$main_key}{$code}{path}}; 
	    $tmpf++;
	    printf log_file "%3d\t", $tmpf;
	    printf "%3d\t", $tmpf;
	    #
	    $tmps = 0;
	    $main_saved_hash{$main_key}{$code}{reported} = 0;
	    if (exists $main_saved_hash{$main_key}{$code})
	      {  $tmps = $#{$main_saved_hash{$main_key}{$code}{path}};
		 $main_saved_hash{$main_key}{$code}{reported} = 1;
		 $tmps++;
	       }
	    printf log_file "%3d\t", $tmps;
	    printf "%3d\t", $tmps;
	    if ($tmpf != $tmps)
	      { printf log_file "--ERROR : $logo Missmatch\n";
		printf "--ERROR : $logo Missmatch\n";
	      }
	    elsif ($logo eq "ERRORS" && ($tmpf > 0 || $tmps > 0 ))
	      { printf log_file "--ERROR : $logo Found\n";
		printf "--ERROR : $logo Found\n";}
	    else
	      { printf log_file "\n";
		printf "\n";}
	  } # eo foreach $code (keys %{$main_file_hash{$main_key}})
	#
	# Adding W/E/N report of items in DbAse but not in file
	#
	foreach $code (keys %{$main_saved_hash{$main_key}})
	  { if ($main_saved_hash{$main_key}{$code}{reported} == 0)
	      {  printf log_file "%5s\t", $code;
		 printf "%5s\t", $code;
		 $tmpf = 0;
		 printf log_file "%3d\t", $tmpf;
		 printf "%3d\t", $tmpf;
		 #
		 $tmps = 0;
		 $tmps = $#{$main_saved_hash{$main_key}{$code}{path}};
		 $tmps++;
		 printf log_file "%3d\t", $tmps;
		 printf "%3d\t", $tmps;
		 if ($tmpf != $tmps)
		   {  printf log_file "--ERROR : $logo Missmatch\n";
		      printf "--ERROR : $logo Missmatch\n";
		    }
		 elsif ($logo eq "ERRORS" && ($tmpf > 0 || $tmps > 0 ))
		   {  printf log_file "--ERROR : $logo Found\n";
		      printf "--ERROR : $logo Found\n";
		    }
		 else
		   {  printf log_file "\n";
		      printf "\n";
		    }
	       } # eo if ($main_saved_hash{$main_key}{$code}{reported} == 0)
	  } # eo foreach $code (keys %{$main_file_hash{$main_key}})
      } #eo $#{keys %{$main_file_hash{$main_key}}}
    printf log_file "===================================\n";
    printf "===================================\n";
  } # eo sub sub_report_results

