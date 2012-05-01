#!/usr/bin/php -q 
<?php 

// It requires netsds.inc to connect to the database 
// It requires phpagi 

include_once 'netsds.inc'; 
/* navigation and taps logs */ 
$agi = new AGI(); 

if (!isset($argv[1]) or 
		!isset($argv[2]) or 
		!isset($argv[3]) or 
		!isset($argv[4]) or 
		!isset($argv[5]) or 
		!isset($argv[6])) { 
	$agi->verbose("Usage: cdr(calldate) cdr(src) custom_dst dtmf previous_context current_context"); 
	exit(0); 
}

$cdr_calldate = $argv[1];
$cdr_src = $argv[2]; 
$custom_dst = $argv[3]; 
// $moment = now(); 
$dtmf = $argv[4];
$previous_context = $argv[5]; 
$current_context = $argv[6]; 

$pgdbh = netsds_connect();
$query = sprintf("insert into ivr.navigation_taps_logs (cdr_calldate, cdr_src, custom_dst, dtmf, previous_context, current_context ) values ('%s','%s','%s','%s','%s','%s');",$cdr_calldate,$cdr_src,$custom_dst,$dtmf,$previous_context,$current_context ); 
pg_query($pgdbh,$query); 
pg_close($pgdbh); 
$agi->verbose("Navigation logs saved",3);

exit(0); 


?>
