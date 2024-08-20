#!/usr/bin/perl

use Data::Dumper;
    
my (@portarray, @reffarray, @node_arrhash, @rings, @tmp_arr) = ();
my ($seg_cnt) = 0;
# my @fields = qw(port chass slot node ring seg card box tech fiber notes index);
my @fields = qw(port chass slot node ring raps seg card box ip tech sfp notes index); #-- index is internal of script.
my $anillo_text = "anillo";

=pod

REQUIREMENT FOR CSV FILE
------------------------
* No spaces or quotes in name
* All lowercase

* Column with ring names must be called "anillo" in first row.
* csv columns must be in the order of @fields

* Internal segment (within chassis) must be segmento = "int<#>"
* At least one rol = "subc" must exist to trace subrings
* segmento name for a rol=subc port cannot be "int". Normally, I name it subc<#>, but not required.

=cut

#
# Syntax: Filename, Ringname
my $in_file   = @ARGV[0];
my $comm      = @ARGV[1];
#
if ($comm == 0)
{   #
    # ============================================== 
    # Run analysis per ring. Warn for missing rings.
    # Create graphs
    # ==============================================
    #
    if (defined $in_file && (-e "$in_file"))
    {	
	&read_csv_file($in_file);
	@rings = sort (@rings);
    } 
    else
    { die $syntax;}
    #
    #-- Set to 1 so the node name is duplicated in the final text-based graph
    $disp_ring_name = 1;
    #
    foreach my $ring (@rings) 
    {
	$sub_ring_run = 0;
	@tmp_arr = ();
	foreach $hport (@portarray) 
	{ if ($hport->{ring} eq $ring) 
	  { push (@tmp_arr, $hport);
	    if ($hport->{tech} =~ /subc/) {$sub_ring_run = 1;}
	  }
	}
	#
	&sub_run_ring($sub_ring_run, 0);
	#
	#print Dumper @tmp_arr;
	&display_ring ($ring, $disp_ring_name);
    }
    #
    &sub_check_cards;
} # elsif ($comm == 0)


#=====================================================================
#========     SUBROUTINES   
#=====================================================================
   
sub sub_check_cards
{ my (%ring, @dis_arr)=();
  my ($k, $r, $s) = 0;
  #
  $num_slots = @node_arrhash;
  printf ("*** INFO: The network has $num_slots XTM cards\n");
  #
  foreach $s (@node_arrhash)
  {
      foreach $r (@rings)
      {
	  $total = grep(/^$r$/i, @{$s->{ring_arr}});
	  if ($total > 2)
	  { printf ("*** ERROR: ring $r collapsed on slot $s->{slot} node $s->{node} $total\n");
	    printf(" Affected rings:\n");
	    
	    @dis_arr = sort(@{$s->{ring_arr}});
	    foreach $k (@rings)
	    { if (grep(/^$k$/i, @dis_arr)) { printf("  $k\n");}
	    }
	  }
      }            
  } #foreach my $s (@node_arrhash)
} #sub sub_check_cards;

sub sub_run_ring
{   my ($sub_ring, $debug) = @_;
    my ($seg_last,  $ring_inst)=0;
    my $ele = @tmp_arr;
    #
    printf "sub_run_ring sub_ring: $sub_ring Debug: $debug\n" if ($debug == 1);
    #print Dumper @tmp_arr;
    #
    if ($sub_ring == 0)
    { &find_ring_chain(0, $ele, $debug);}
    else
    { &find_subring_chain(0, $ele, $debug);}	
    #  
    foreach  $idx (@tmp_arr) {if (exists $idx->{run}) {$ring_inst++;}}
    if ($ring_inst != $ele) 
    { 
      foreach  $idx (@tmp_arr) {if ($idx->{run} == $seg_cnt) {$seg_last=1;}}
      if($seg_last == 1) {$seg_cnt++;}
      #
      if ($sub_ring == 0)
      { &find_ring_chain(1, $ele, $debug);}
      else
      { &find_subring_chain(1, $ele, $debug);}	
    }
    #
    $ring_inst = 0;
    foreach  $idx (@tmp_arr) {if (exists $idx->{run}) {$ring_inst++;}}
    if ($ring_inst != $ele) 
    { printf ("*** ERROR: Ring trace detected $ring_inst ports while total ring has $ele ports\n");}      
   
} # eo sub_run_ring

sub find_ring_chain
{
    my ($state, $ele, $debug) = @_;
    my ($seg, $node, $slot, $port, $running, $ele_type, $ept) = 0;
    #
    if ($state == 0) { $seg_cnt = 0;} #-- Clear Global variable at start of ring trace and if no error.
    printf ("Find_ring_chain: State $state # of Ports: $ele debug $debug  \n") if ($debug == 1);
    printf ("================= Error round  \n") if ($debug == 1 && $state == 1);
    # Run by the ring. based on segments, add the same count for both endpoints => run thru those and print
    #
  LOOP0: while ($running < $ele)
    {
	if ($ele_type == 0) 
	{
	    #-- ele_type == 0 only at the start of the ring trace. Then, the sequence should be
	    #-- 1(end_pt_outer_sgtA_CardA) -> 2 (other port_cardA) -> 1 (endpt
	    #-- I stay in ele_type=0 until I found combiantion of two endpoinst from different nodes.
	  LOOP1: foreach  $idx (@tmp_arr)
	  { if (!exists $idx->{run})
	    { $idx->{run} = $seg_cnt;
	      $idx->{ept} = 2;  #-- End-point index
	      $idx->{error} = $state;
	      #
	      LOOP2: foreach my $idx2 (@tmp_arr)
	      {   #-- Start a segment trace in an intercity segment "segmento != int")
		  if ($idx2->{seg}  eq $idx->{seg} && 
		      $idx2->{node} ne $idx->{node} &&
		      $idx2->{seg} !~ /^int/)		    
		  {
		      $ept =1;
		      ($seg, $node, $slot, $port) = load_find_ring_info(\%{$idx2}, $seg_cnt, $state, $ept);
		      printf ("Found entry L2 $idx2->{seg}  $idx2->{node} cnt : $seg_cnt \n\n") if ($debug == 1);
		      $seg_cnt++;
		      $ele_type = 1; #-- "We found the other end point for external or subc segment, now find the next port same card/node
		      last LOOP1;
		  }
	      } # LOOP2
	    } # if
	    elsif ($state == 0)
	    { last LOOP0;
	    }
	  } # LOOP1
	} # if ($ele_type = 0)
	elsif ($ele_type == 1)
	{
	    printf ("Next_Port_Same_slot: Prev_Seg: $seg N: $node S: $slot $port cnt : $seg_cnt \n") if ($debug == 1);
	    LOOP3: foreach my $idx2 (@tmp_arr)
	    {
		if ($idx2->{slot} == $slot && 
		    $idx2->{node} eq $node &&
		    $idx2->{port} ne $port &&
		    !exists $idx2->{run})
		{ 
		  $ept =2;
		  ($seg, $node, $slot, $port) = load_find_ring_info(\%{$idx2}, $seg_cnt, $state, $ept);
		  $ele_type = 2; #-- We are inside a card, and we want to look for the other port in diff card or node
		  printf ("  L3 Same slot $seg $node $port cnt : $seg_cnt \n\n") if ($debug == 1);
		  last LOOP3;
		}
	    } # EO loop3  
	} #elsif ($ele_type == 1)
      elsif ($ele_type == 2)
	{
	    printf ("L4: $seg $node S: $slot $port cnt : $seg_cnt \n") if ($debug == 1);
	  LOOP4: foreach my $idx2 (@tmp_arr)
	  {	     
	      if ($idx2->{seg} eq $seg && 
		  $idx2->{node} ne $node &&
		  $seg !~ /^int/ &&
		  !exists $idx2->{run})
	      {
		  #-- We are on another port of the same card as found in Loop3 & we foudn a segment != int.
		  $ept =1;
		  ($seg, $node, $slot, $port) = load_find_ring_info(\%{$idx2}, $seg_cnt, $state, $ept);
		  printf ("Same ext seg, diff node L4 $idx2->{seg}  $idx2->{node} cnt : $seg_cnt \n\n") if ($debug == 1);
		  $seg_cnt++;
		  $ele_type = 1; #-- Let's look for the other end-point for this non-internal segment
		  last LOOP4;		
	      }
	      if ($idx2->{seg} eq $seg && 
		  $idx2->{node} eq $node &&
		  $idx2->{slot} != $slot &&
		  $seg =~ /^int/ &&
		  !exists $idx2->{run})
	      { 	
		  #-- We are on another port of the same card as found in Loop3 & we foudn segment == int (interconnect cards in same chassis).
		  $ept =1;
		  ($seg, $node, $slot, $port) = load_find_ring_info(\%{$idx2}, $seg_cnt, $state, $ept);		  
		  printf ("Same int seg, same node L4 $idx2->{seg}  $idx2->{node} cnt : $seg_cnt \n\n") if ($debug == 1);
		  $seg_cnt++;
		  $ele_type = 1; #-- Let's look for the other end-point for this internal segment
		  $port = $idx2->{port};
		  last LOOP4;
	      }
	} # EO loop4  
      }#elsif ($ele_type == 2)
      $running++;
  } # Loop0
} # eo sub find_ring_chain


sub find_subring_chain
{
    my ($state, $ele, $debug) = @_;
    my ($seg, $node, $slot, $port, $running, $ele_type) = 0;
    #
    if ($state == 0) { $seg_cnt = 0;} #-- Clear Global variable at start of ring trace and if no error.
    printf ("================= Error round  \n") if ($debug == 1 && $state == 1);
    # Run by the ring. based on segments, add the same count for both endpoints => run thru those and print
    #
  LOOP0: while ($running < $ele)
    {
	if ($ele_type == 0) 
	{
	    #-- ele_type == 0 only at the start of the ring trace. Then, the sequence should be
	    #-- 1(end_pt_outer_sgtA_CardA) -> 2 (other port_cardA) -> 1 (end 
	  LOOP1: foreach  $idx (@tmp_arr)
	  { if (!exists $idx->{run} && $idx->{tech} =~ /subc/)
	    { 
		if ($idx->{seg} =~ /int/)
		{ #-- Internal sgt: Stay until I find the other end point card in same node => find other port same card
		 LOOP2I: foreach my $idx2 (@tmp_arr)
		 {   #-- Start a segment trace in an intercity segment "segmento != int")
		     if ($idx2->{seg} eq $idx->{seg} && 
			 $idx2->{node} eq $idx->{node} &&
			 $idx2->{slot} ne $idx->{slot})		    
		     {
			 $idx->{run} = $seg_cnt;
			 $idx->{ept} = 2;  #-- End-point index
			 $idx->{error} = $state;
			 #
			 $ept =1;
			 ($seg, $node, $slot, $port) = load_find_ring_info(\%{$idx2}, $seg_cnt, $state, $ept);		
			 printf ("SUB: Found entry L2 $idx2->{seg}  $idx2->{node} cnt : $seg_cnt \n\n") if ($debug == 1);
			 $seg_cnt++;
			 $ele_type = 1; #-- "We found the other end point for external or subc segment, now find the next port same card/node
			 last LOOP1;
		     }
		 } # LOOP2I
		} # if ($idx->{seg} =~ /int/)
		else		   
		{ #-- External segment: Stay until I find the other endpt in different node => find other port same card
		    LOOP2E: foreach my $idx2 (@tmp_arr)
		 {   #-- Start a segment trace in an intercity segment "segmento != int")
		     if ($idx2->{seg} eq $idx->{seg} && 
			 $idx2->{node} ne $idx->{node})		    
		     {
			 $idx->{run} = $seg_cnt;
			 $idx->{ept} = 2;  
			 $idx->{error} = $state;
			 #
			 $ept =1;
			 ($seg, $node, $slot, $port) = load_find_ring_info(\%{$idx2}, $seg_cnt, $state, $ept);		
			 printf ("SUB: Found entry L2 $idx2->{seg}  $idx2->{node} cnt : $seg_cnt \n\n") if ($debug == 1);
			 $seg_cnt++;
			 $ele_type = 1; #-- "We found the other end point for external or subc segment, now find the next port same card/node
			 last LOOP1;
		     }
		 } # LOOP2E
		} # if !($idx->{seg} =~ /int/)
	    } #if (!exists $idx->{run} && $idx->{tech} =~ /subc/)
	    elsif ($state == 0 && exists $idx->{run}) #-- If all ports in ring have been included and not in error state. quit the search.
	    { last LOOP0;
	    }
	  } # LOOP1
	} # if ($ele_type = 0)
	elsif ($ele_type == 1)
	{
	    printf ("SUB:L3: $seg $node S: $slot $port cnt : $seg_cnt \n") if ($debug == 1);
	    LOOP3: foreach my $idx2 (@tmp_arr)
	    {
		if ($idx2->{slot} == $slot && 
		    $idx2->{node} eq $node &&
		    $idx2->{port} ne $port &&
		    !exists $idx2->{run})
		{ 
		    $ept =2;
		    ($seg, $node, $slot, $port) = load_find_ring_info(\%{$idx2}, $seg_cnt, $state, $ept);		
		  #
		  $ele_type = 2; #-- We have IDed both end points of external segment. We are in a card, and we want to ook for the other port in the same card
		  printf ("SUB:Same slot L3 $seg $node $port cnt : $seg_cnt \n\n") if ($debug == 1);
		  last LOOP3;
		}
	    } # EO loop3  
	} #elsif ($ele_type == 1)
      elsif ($ele_type == 2)
	{
	  printf ("SUB:L4: $seg $node S: $slot $port cnt : $seg_cnt \n") if ($debug == 1);	  
	  LOOP4: foreach my $idx2 (@tmp_arr)
	  {	     
	      if ($idx2->{seg} eq $seg && 
		  $idx2->{node} ne $node &&
		  $seg !~ /^int/ &&
		  !exists $idx2->{run})
	      {
		  #-- We are on another port of the same card as found in Loop3 & we foudn a segment != int.
		  $ept = 1;
		  ($seg, $node, $slot, $port) = load_find_ring_info(\%{$idx2}, $seg_cnt, $state, $ept);		
		  printf ("Same ext seg, diff node L4 $idx2->{seg}  $idx2->{node} cnt : $seg_cnt \n\n") if ($debug == 1);
		  $seg_cnt++;
		  $ele_type = 1; #-- Let's look for the other end-point for this non-internal segment
		  last LOOP4;		
	      }
	      if ($idx2->{seg} eq $seg && 
		  $idx2->{node} eq $node &&
		  $idx2->{slot} != $slot &&
		  $seg =~ /^int/ &&
		  !exists $idx2->{run})
	      { 	
		  #-- We are on another port of the same card as found in Loop3 & we foudn segment == int (interconnect cards in same chassis).
		  $ept = 1;
		  ($seg, $node, $slot, $port) = load_find_ring_info(\%{$idx2}, $seg_cnt, $state, $ept);	
		  printf ("Same int seg, same node L4 $idx2->{seg}  $idx2->{node} cnt : $seg_cnt \n\n") if ($debug == 1);
		  $seg_cnt++;
		  $ele_type = 1; #-- Let's look for the other end-point for this internal segment
		  last LOOP4;
	      }
	} # EO loop4  
      }#elsif ($ele_type == 2)
      $running++;
  } # Loop0
} # eo sub find_subring_chain

sub load_find_ring_info
{ my ($idx, $cnt, $state, $ept) =@_;
  $idx->{run}   = $cnt;
  $idx->{ept}   = $ept;
  $idx->{error} = $state;
  #
  $seg  = $idx->{seg};
  $node = $idx->{node};
  $slot = $idx->{slot};
  $port = $idxqq->{port};
  return ($seg, $node, $slot, $port);
}

sub display_ring
{   my ($ring, $disp_node) = @_;
    my $epoint = 0;
    my $block_entry = 0;
    #    --{ 5-4  "2 : ERP : gtacvill   6-7 }-- gray:sgt"  tech:node:slot:port}--seg   --{port:slot
    printf ("\n**************************\n");
    printf ("******  RING: $ring  ******\n");
    printf ("**************************\n");
    for (my $i=0; $i < $seg_cnt; $i++)
    { foreach my $idx (@tmp_arr)
      { if (!exists $idx->{run})
	{ printf ("**ERROR: Cound not find destination point slot: $idx->{slot} node: $idx->{node}\n");}
	#	
	if ($idx->{run} == $i && $idx->{ept} == 2 && !exists $idx->{done} && $idx->{error} == 0)
	{  	    
	    printf (":$idx->{node}:S$idx->{slot}:$idx->{port} }");
	    #printf (":S%2d:$idx->{port} }", $idx->{slot});
	    if ($block_entry == 2) {printf ("\n\n");$block_entry = 0;}
	    else {$block_entry++;}
	    #
	    if ($idx->{seg} =~ /^int/) { printf("... $idx->{seg}")}
	    elsif ($idx->{seg} =~ /^\D+\d?/) { printf("--- $idx->{seg}")}
	    else { printf("=== $idx->{seg}")}
	    $idx->{done} = 1;
	    DEST_PT: foreach my $idx2 (@tmp_arr)
	    { if ($idx2->{run} == $i && $idx2->{ept} == 1)
	      {
		  if ($idx2->{seg} =~ /^int/) { printf(" ...{")}
		  elsif ($idx2->{seg} =~ /^\D+\d?/) { printf(" ---{")}
		  else { printf(" ==={")}
		  #
		  if ($disp_node ==1) { printf ("$idx2->{port}:S$idx2->{slot}:$idx2->{node} ");}
		  else { printf ("$idx2->{port}:S$idx2->{slot}");}
		  #		  
		  $idx2->{done} = 1;
		  #		  		  
		  last DEST_PT;
	      } # Eo if
	    } # eo DEST_PT: 
	} # eo if ( $idx->{run} == $i)
      } # foreach my $idx (@tmp_arr)
    } # eo for (my $i=0; $i < $seg_cnt; $i++)
    #
    printf ("\n\n");
    #
    $block_entry = 0;
    for (my $i=0; $i < $seg_cnt; $i++)
    { foreach my $idx (@tmp_arr)
      { 
	if ($idx->{run} == $i && $idx->{ept} == 2 && !exists $idx->{done} && $idx->{error} == 1)
	{   printf ("ERROR: $idx->{node}:S$idx->{slot}:$idx->{port} }");
	    if ($block_entry == 2) {printf ("\n\n");$block_entry = 0;}
	    else {$block_entry++;}
	    #
	    if ($idx->{seg} =~ /^int/) { printf("... $idx->{seg}")}
	    elsif ($idx->{seg} =~ /^\D+\d?/) { printf("--- $idx->{seg}")}
	    else { printf("=== $idx->{seg}")}
	    $idx->{done} = 1;
	    DEST_PT2: foreach my $idx2 (@tmp_arr)
	    { if ($idx2->{run} == $i && $idx2->{ept} == 1)
	      {		  
		  if ($idx->{seg} =~ /^int/) { printf(" ...{")}
		  elsif ($idx->{seg} =~ /^\D+\d?/) { printf(" ---{")}
		  else { printf(" ==={")}
		  #
		  if ($disp_node ==1) { printf ("$idx2->{port}:S$idx2->{slot}:$idx2->{node} ");}
		  else { printf ("$idx2->{port}:S$idx2->{slot}");}
		  $idx2->{done} = 1;
		  #
		  last DEST_PT2;
	      } # Eo if
	    } # eo DEST_PT: 
	} # eo if ( $idx->{run} == $i)
      } # foreach my $idx (@tmp_arr)
    } # eo for (my $i=0; $i < $seg_cnt; $i++)
    printf ("\n\n");
} # sub display_ring


sub read_csv_file
{   #
    # I: This sub assumes no "" in the csv files, all are one field entries.
    #
    my ($filen) = @_;
    my (%hash_fast_qid, %hash_tb_qid, %rec) = ();
    #
    open(list_handle, "$filen")||die "MR_EROR: File $file_n does not exist. Quitting\n";
    #
    my ($line, $k, $nodecnt, $new) = 0;
    #
    while ($line  = <list_handle>)
    { 
	chomp ($line);
	$line =~ s/\s?//g; # remove all spaces (In port field I add a sapce to avoid excel seeing as date).
	$line = lc($line);
	#
	@line_arr = split(",", $line);
        #
	#== 0 Puerto, 1 Chassis, 2 Slot, 3 Nodo, 4 anillo, 5 segmento
	#== 6 EMXP, 7 TM301, 8 OPT/ERPS, 9Gris/DWDM
	#
	$line_arr[3] =~ s/_//g;
	%rec =();
	my $field_cnt = @fields;
	for (my $k=0; $k<$field_cnt; $k++)
	{ 
	    $rec{$fields[$k]} = $line_arr[$k];
	}  # eo for
	#	
	push (@portarray, {%rec});
	#
	# Create Array of HAshes for slots
	$new =1;
	foreach my $s (@node_arrhash)
	{ if ($s->{slot} == $rec{slot} && $s->{node} eq $rec{node}) {$new =0;}}
	#
	if ($new == 1 && $rec{slot} =~ /\d+/) 
	{  push (@node_arrhash, {%rec});
	}
	#
	$new =1;
	foreach my $r (@rings)
	{ if ($r eq $rec{ring}) {$new =0;}}
	#
	if ($new == 1 && $rec{ring} =~ /\w+/ && $rec{ring} !~ /$anillo_text/) 
	{  push (@rings, $rec{ring});
	}
	
    } # Eo while

    foreach my $s (@node_arrhash)
    { foreach my $p (@portarray)
      {
	 if ($s->{slot} == $p->{slot} && $s->{node} eq $p->{node})
	 {
	     push (@{$s->{ring_arr}}, $p->{ring});
	     push (@{$s->{port_arr}}, $p->{port});
	 }
      }       	
    }
    
  } # sub read_csv_file









