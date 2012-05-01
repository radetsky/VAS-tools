#!/usr/bin/php -q 
<?php 

require 'phpagi.php';
include_once 'netsds.inc'; 


$agi = new AGI(); 
if (isset($argv[1])) { 
	$msisdn = $argv[1]; 
} else { 
		$agi->verbose("MSISDN does not exist."); 
		exit(0); 
} 

$pgdbh = netsds_connect();
$query = "select operator from primary_operators where number='".$msisdn."'"; 
$res = pg_query($pgdbh,$query) or die ("Query failed.");
$a = pg_fetch_array($res); 
$listed = $a[0]; 
pg_close($pgdbh); 

if ($listed) { 
	$agi->verbose("OPERATOR: ".$listed); 
	$agi->set_variable("PRIMARY_OPERATOR",trim($listed)); 
}

?>
