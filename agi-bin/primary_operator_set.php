#!/usr/bin/php -q 
<?php 

include_once 'netsds.inc'; 

$pgdbh = netsds_connect();

/* SQL queries */ 
$get_history_pairs = "select distinct calldate,src,split_part(dstchannel,'-',1) as dstoperator from cdr where calldate > ( now() - interval '1 hour' ) and dstchannel like 'SIP/8%' and channel like 'SIP/101%' order by calldate"; 

$check_exist_pair = pg_prepare($pgdbh,"check_exist_pair","select distinct operator from primary_operators where number=$1");
$delete_exist_pair = pg_prepare($pgdbh, "delete_exist_pair", "delete from primary_operators where number=$1"); 
$set_primary_operator = pg_prepare($pgdbh,"insert_new_operator","insert into primary_operators (operator,number) values ($1,$2)");

/* Get History for last hour */ 
$res = pg_query($pgdbh,$get_history_pairs) or die ("Query failed!"); 
$a = pg_fetch_all($res); 
foreach ($a as $row) { 
		// print_r($row);  
		// got: [calldate],[src],[dstoperator] 
		$res1 = pg_execute($pgdbh,"check_exist_pair", array ($row['src']) );  // Select operator 
		$res1_operator = pg_fetch_row($res1); 
		if ($res1_operator == FALSE) { // Net tut nikogo, 
			insert_new_values($row); 
		} else { 
			// Let's check 
			if ($row['dstoperator'] == trim ($res1_operator[0]) ) { 
					// Skip.
					echo "Skipping pair " . sprintf("%s-%s",$row['src'],$row['dstoperator']) . "\n";  
			} else { 
					// Drop it and inser new record 
					delete_primary_operator ($row); 
					insert_new_values($row); 
			}
		}
}

pg_close($pgdbh); 
exit(0); 

function delete_primary_operator ($row ) {
	global $pgdbh; 	
	pg_execute($pgdbh,"delete_exist_pair",array($row['src']) ); 
}
function insert_new_values($row) { 
	global $pgdbh; 
	pg_execute($pgdbh,"insert_new_operator",array($row['dstoperator'],$row['src']) ); 
}
