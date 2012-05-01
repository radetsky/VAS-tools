#!/usr/bin/php -q 
<?php 

// IVR history. Version 0.2.0. 

// It requires netsds.inc to connect to the database 
// It requires phpagi to work with Asterisk.  

/* Usage: 
	cdr(calldate),cdr(src),custom destination, 
	dtmf, previous context, current_context, 
	previous ID, seconds (integer) in previous context. 

*/ 

include_once 'netsds.inc'; 
/* navigation and taps logs */ 
$agi = new AGI(); 

if (!isset($argv[1]) or 
		!isset($argv[2]) or 
		!isset($argv[3]) or 
		!isset($argv[4]) or 
		!isset($argv[5]) or 
		!isset($argv[6]) or 
		!isset($argv[7]) or 
		!isset($argv[8])) { 
	  $agi->verbose("Usage: cdr(calldate) cdr(src) custom_dst dtmf previous_context current_context previous_id previous_seconds"); 
	  exit(0); 
}

$cdr_calldate = $argv[1];
$cdr_src = $argv[2]; 
$custom_dst = $argv[3]; 
// $moment = now(); 
$dtmf = $argv[4];
$previous_context = $argv[5]; 
$current_context = $argv[6];
$previous_id = $argv[7]; 
$previous_seconds = $argv[8]; 

$pgdbh = netsds_connect();

$agi->verbose("Previous id is $previous_id");
if ($previous_id > 0) { 
	// We have previous ID.
	$agi->verbose("Setting seconds for previous position to $previous_seconds");
	pg_query($pgdbh,"update ivr.navigation_taps_logs set seconds=$previous_seconds where id=$previous_id"); 
}

$query = sprintf("insert into ivr.navigation_taps_logs (cdr_calldate, cdr_src, custom_dst, dtmf, previous_context, current_context ) values ('%s','%s','%s','%s','%s','%s') returning id;",$cdr_calldate,$cdr_src,$custom_dst,$dtmf,$previous_context,$current_context ); 

$insert = pg_query($pgdbh,$query);
$row = pg_fetch_row($insert);

$agi->verbose("PREVIOUS_ID must be ".$row[0]);
$agi->exec("Set","PREVIOUS_ID=".$row[0]); 
pg_close($pgdbh); 
$agi->verbose("IVR history saved");

exit(0); 


?>
