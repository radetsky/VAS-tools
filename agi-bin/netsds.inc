<?php 

function netsds_connect () { 

$pgsql_host = "localhost"; 
$pgsql_user = "asterisk"; 
$pgsql_pass = "supersecret"; 
$pgsql_dbms = "asterisk"; 

$pgsql_conn_string = sprintf("host=%s dbname=%s user=%s password=%s", 
		$pgsql_host,
		$pgsql_dbms, 
		$pgsql_user,
		$pgsql_pass); 

$pgdbh = pg_connect($pgsql_conn_string) or die ("Connection Failed."); 

return $pgdbh; 

} 

require_once('phpagi-asmanager.php');


/* GET IP ADDR from OPERATOR: 
		1. sip show peer $operator load 
		2. Addr->IP     : (Unspecified) Port 0 
		3. (Unspecified) or XX.XX.XX.XX 
		4. XX.XX.XX.XX - here IP Address 
 */ 

function netsds_getipaddr_from_sip($operator) { 

	$asm = new AGI_AsteriskManager();
    if($asm->connect()) {
		$peer = $asm->command("sip show peer $operator load");
        if(!strpos($peer['data'], ':')) { 
            echo $peer['data'];
		} else  {
		    $data = array();
	        foreach(explode("\n", $peer['data']) as $line)
 	        {
	          $a = strpos('z'.$line, ':') - 1;
 	          if($a >= 0) { 
				 $data[trim(substr($line, 0, $a))] = trim(substr($line, $a + 1));
			  }
	        } 
			// print_r($data); // debug 
			// echo $data['Addr->IP']."\n"; 
			$value = explode(" ",$data['Addr->IP']); 
			$ipaddr = $value[0]; 
			$asm->disconnect(); 
			if ($ipaddr == '(Unspecified)') { 
				return null; 
			} else { 
				return $ipaddr; 
			}
	    }
		$asm->disconnect();
	}
	return null; 
} 

