eval 'exec perl -S $0 ${1+"$@"}'
    if 0;

=pod

Author: Marlon Roa

CLI EXAMPLES
============
 
The "high runner" tasks can be accomplished as follows:
 
Getting back to the root menu (from which all other examples are assumed to start)
 home

Configuring dhcp for the mgmt lan interface
 configure interface mgmt-lan
 dhcp enable/disable

Configuring dhcp for a mgmttnl
 configure mgmttnl <interface> (use ? to see options)
 dhcp enable/disable

To see what you ve done
 show interface <interface> (use ? to see options)
 show mgmttnl <interface> (use ? to see options)

To get to legacy consoles and back
 configure system
   legacy vmi arriso123          .... to get to the old ctrl DBGX or ....  
   legacy quantum arriso123      .... to get to the old "con ena"
     covpfm off                  .... Once inside Quantum => disable polling.
     covinit                     .... Once inside Quantum => enter debug screen.
   exit cli                      .... to get back

./.


=cut

use lib "/home/bin/library";
#require 5.002;
use Net::Telnet ();
use Data::Dumper;
#
my $ip         = @ARGV[0];
#my $poll_mode  = @ARGV[1];
my $in_file    = @ARGV[1];
#my $option     = @ARGV[2];
#
my ($option2replace, $device_ver) = 0;
my (@list_of_commands, @lines) = ();
#
my $syntax = << "SYNTAX_TEXT";

SYNTAX:
------

$0 <ip> <file_name>
 Ex: $0 10.10.1.233 ./commands_to_run.txt

 ip        = MCP IP address.

 file_name = File with commnds to run in MCP (Comments are ignored (// comments)).
             or "nofile" 

=====================================================================================
WARNING: Disable "CLI paging" under user menu option before running this script!!!!
=====================================================================================

SYNTAX_TEXT



if ($#ARGV < 0 || (defined $in_file && ($in_file ne "nofile" && !(-e "$in_file"))) || 
    $ip =~ /-h(\w*)/i)
  { die $syntax;}
#
$device_ver = 206;

#
#
$login_logout        = "Login";
$login_logout_aux    = "Login";
$timeout             = 20;
$seed                = time;
#

if (defined $in_file && (-e "$in_file"))
{
  &read_file($in_file);
  &login($ip);
  &run_file;
}
#
&login($ip);
#
#-------------------------------------------------------------------------
# Subroutine which telnets onto specified MCP
#-------------------------------------------------------------------------
sub login {
  my ($host) = @_;
  printf("$host....\n\n");
  my $logfile = "telnet_". $host.".log";
  #if (defined $option)

  #----------------------------------------------------------
  # Logging on
  #----------------------------------------------------------
  if ( $login_logout eq "Login" ) {
    printf("Telnet to $host....\n\n");

    $telnet_connection = new Net::Telnet (Timeout   => $timeout,
                                          Input_Log => $logfile,
					  Errmode   =>'die',
                                          Host      => "$host",
					  Prompt    => "/(continue)*/g");

    #
    @lines = $telnet_connection->login("uname", "password");
    sleep(1);
    print "Entered root...\n";
    #
    $string = "y\n";
    $telnet_connection->cmd(String => "$string", Cmd_remove_mode => 1, Timeout => $timeout, Output => \@lines);
    printf(@lines);
    #
    sleep(1);
    #
    # Clearing the buffer, so other commands can get the correct output.
    $telnet_connection->getline;
    #
    $login_logout = "Logout";
  }
  #----------------------------------------------------------
  # Logging off
  #----------------------------------------------------------
  else {
    printf("\n\nLogging off of $host....\n\n");
    $string2  = "exit\n";
    @lines = $telnet_connection->put(String => $string2, Timeout => 20);
    sleep 1;
    @lines = $telnet_connection->put(String => $string2, Timeout => 20);
    $telnet_connection->close;
    $login_logout = "Login";
  }
}

sub read_file {
  my ($file_in) = @_;
  my @file_arary;
  my ($i, $ignore_block) = 0;

  if (-e "$file_in")
    { open(list_handle, "$file_in")||die "MR_EROR: File $file_in does not exist.\n";
      @file_array = <list_handle>;
      close(list_handle);
      #
      foreach $entry (@file_array)
	{ 
	  if ($entry =~ /\/\/TARGET=(.+)/i) {$target = $1; printf "*I: Detected Target = $target\n";}
	  if ($entry =~ /\/\*/g) {printf "*I: Found ignore start\n";$ignore_block =1;}
	  if ($entry !~ /\/\//g && $ignore_block != 1)
	    { chomp($entry);
	       push (@list_of_commands, $entry);
	    }
	  if ($entry =~ /\*\//g) {$ignore_block =0; printf "*I: Found ignore end\n";}
	}
    }
}

sub run_file {
  my $entry;
  while (@list_of_commands)
    { $entry = shift @list_of_commands;
	  &telnet_command($entry);
	  &telnet_command(""); # Needed to get output of previous command.
    }
}

sub telnet_command ($;$){
  my ($command, $silent) = @_;
  my $timeout = 120;
  #
  @lines = ();
  return if ($login_logout eq "Login");
  #
  $telnet_connection->prompt("/--\>/");
  $telnet_connection->cmd(String => "$command", Cmd_remove_mode => 1, Timeout => $timeout, Output => \@lines);
  #
  if (!(defined $silent) || $silent == 0)
  { printf("scr_cmd: $command = @lines\n");}
}


sub scr_sleep {
  my ($entry) = @_;
  my @time2sleep = split (" ",$entry);
  printf "===============> SLEEP for $time2sleep[1] secs\n";
  sleep $time2sleep[1];
}

#==============================================================
#==============================================================
#==== SPECIFIC ROUTINES
#==============================================================
#==============================================================

