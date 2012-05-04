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
		!isset($argv[4])) { 
	  $agi->verbose("Usage: cdr(calldate) cdr(src) custom_dst seconds"); 
	  exit(0); 
}

$cdr_calldate = $argv[1];
$cdr_src = $argv[2]; 
$custom_dst = $argv[3]; 
$seconds = $argv[4]; 

$pgdbh = netsds_connect();
$select = pg_query($pgdbh,"select id from ivr.navigation_taps_logs where cdr_calldate='".$cdr_calldate."' and cdr_src='".$cdr_src."' and custom_dst='".$custom_dst."' order by id desc limit 1");
$row = pg_fetch_row($select);
$agi->verbose("ID is ".$row[0]); 
pg_query($pgdbh,"update ivr.navigation_taps_logs set seconds=$seconds where id=".$row[0]); 
pg_close($pgdbh); 
exit(0); 


?>
