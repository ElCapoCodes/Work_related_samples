eval 'exec perl -S $0 ${1+"$@"}'
    if 0;

=pod

CLI EXAMPLES
============

!SETTING UP ETH MGMT PORT
Reff: Pg 173 Manual

OS906C>
OS906C> enable
OS906C# configure terminal
OS906C(config)# show interface    // Shows all interfaces enabled.
OS906C(config)# interface out-of-band eth0
OS906C(config-eth0)# ip 192.168.10.235/24
OS906C(config-eth0)# management   // Enables all: SNMP/TELNET/SSH/TFTP protocols.
OS906C(config-eth0)# write memory // Save configuration


!Disable User Timeout

OS906C> enable
OS906C# configure terminal
OS906C(config)# line vty   // Enters "Line Mode".
OS906C(config-line)# no exec-timeout global
OS906C(config-line)# ATTENTION: LOGOUT timeout is disabled.
OS906C(config-eth0)# write memory // Save configuration

./.


=cut

use lib "/home//bin/library";
#require 5.002;
use Net::Telnet ();
use Data::Dumper;
#
my $ip         = @ARGV[0];
my $poll_mode  = @ARGV[1];
my $in_file    = @ARGV[2];
my $option     = "mrv";
#
my (@list_of_commands, @lines) = ();
#
my $syntax = << "SYNTAX_TEXT";

SYNTAX:
------

$0 <ip> poll_skip <file_name>
 Ex: $0 10.10.1.233 poll_skip ./commands_to_run.txt new

 ip        = MRV IP address.

 poll_skip   = Skip going into alternate telnet port to modify polling. [ONLY OPTION]

 file_name = File with commnds to run in MCP (Comments are ignored (// comments)).
             or "nofile" 

 options   = [REMOVED]

Note: This script is a modified copy from that used for 825 & still found in Laptop bin.

SYNTAX_TEXT



if ($#ARGV < 0 || (defined $in_file && ($in_file ne "nofile" && !(-e "$in_file"))) || 
    $ip =~ /-h(\w*)/i)
  { die $syntax;}
#
$login_logout        = "Login";
$login_logout_aux    = "Login";
$timeout             = 20;
$seed                = time;
#
if (defined $in_file && (-e "$in_file"))
{
  &read_file($in_file);
  #
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
  if (defined $option)
    {  $logfile = "telnet_". $host."_".$option.".log";}

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
    # I: Mode after login = Admin mode
    @lines = $telnet_connection->login("uname", "password");
    printf (@lines);
    $telnet_connection->prompt("/OS906C/");
    print "L: Entered Admin Mode\n";
    #
    # I: Enter enable mode. (Other modes: linux)
    $string = "enable";
    $telnet_connection->cmd(String => "$string", Cmd_remove_mode => 1, Timeout => $timeout, Output => \@lines);
    printf(@lines);
    $telnet_connection->prompt("/OS906C/"); # new
    print "Entered Enable mode..\n";
    #
    # I: Set terminal to display all output continuosly.
    $string = "no cli-paging\n";
    $telnet_connection->cmd(String => "$string", Cmd_remove_mode => 1, Timeout => $timeout, Output => \@lines);
    printf(@lines);
    $telnet_connection->prompt("/OS906C/");
    #
    # I: Show general info about the box
    $string = "show version\n";    
    $telnet_connection->cmd(String => "$string", Cmd_remove_mode => 1, Timeout => $timeout, Output => \@lines);
    printf(@lines);
    $telnet_connection->prompt("/OS906C/");
    # Disable/Enable Software Polling: [REMOVED]
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
  #print Dumper (@list_of_commands);
  while (@list_of_commands)
    { $entry = shift @list_of_commands;
      if ($entry =~ /^scr_/i)
	{
	  if ($entry eq "scr_sleep")
	    { &scr_sleep ($entry);
	    }
	}
      elsif ($entry !~ /^dbg|^bun|^conn/i)
	{ &telnet_command($entry);
	  &telnet_command(""); # Needed to get output of previous command.
	}
    }
}

sub telnet_command ($;$){
  my ($command, $silent) = @_;
  my $timeout = 120;
  #
  @lines = ();
  return if ($login_logout eq "Login");
  #
  if ($option =~ /debug/i) { $telnet_connection->prompt("/debug/");}
  elsif ($option =~ /bun/i) { $telnet_connection->prompt("/bun/");}
  else { $telnet_connection->prompt("/OS906C/");}  
  $telnet_connection->cmd(String => "$command", Timeout => $timeout, Output => \@lines);
  #
  sleep 1;
  if (!(defined $silent) || $silent == 0)
  {  printf("scr_cmd: $command = @lines\n");}
}


sub scr_sleep {
  my ($entry) = @_;
  #$entry =~ s/scr_//gi;
  my @time2sleep = split (" ",$entry);
  printf "===============> SLEEP for $time2sleep[1] secs\n";
  sleep $time2sleep[1];
}


#==============================================================
#==============================================================
#==== SPECIFIC ROUTINES
#==============================================================
#==============================================================



