#!/usr/bin/env perl 
#===============================================================================
#
#         FILE:  online.pl
#
#        USAGE:  ./online.pl 
#
#  DESCRIPTION:  
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Alex Radetsky (Rad), <rad@rad.kiev.ua>
#      COMPANY:  Net.Style
#      VERSION:  1.0
#      CREATED:  20.04.2012 18:05:59 EEST
#     REVISION:  ---
#===============================================================================

use 5.8.0;
use strict;
use warnings;

use NetSDS::Asterisk::Manager;
use NetSDS::Util::DateTime; 
use CGI; 
use DBI;
use Data::Dumper;
use Config::General;
use Template; 

my $cgi = CGI->new;
print $cgi->header(-content-type => 'text/html',
                  -charset => 'UTF-8');
									
my $template = Template->new( {
  INCLUDE_PATH => '/home/rad/git/VAS-tools/templates',
	INTERPOLATE => 1,
		  } ) || die "$Template::ERROR\n";

my $queuename = $cgi->param('queue');
my $fromtime = $cgi->param('fromtime');
my $tilltime = $cgi->param('tilltime'); 
my $fromdate = $cgi->param('fromdate');
my $tilldate = $cgi->param('tilldate');

my $fromdatetime = filldatetime ($fromdate,$fromtime);
my $tilldatetime = filldatetime ($tilldate,$tilltime); 

my $config = new Config::General("/etc/NetSDS/ves-media.conf");
my %hash_conf = $config->getall;
my $conf = \%hash_conf; 

my $dbh = undef;

db_connect();  

#
# Connect to Asterisk Manager
#

my $manager = NetSDS::Asterisk::Manager->new ( 
		host => 'localhost',
		port => '5038',
		username => 'netsds',
		secret => 'FollowTheWideRabbit2001',
		events => 'Off',
); 

my $is_connected = $manager->connect; 
unless ( defined ( $is_connected ) ) { 
	warn 'Asterisk Manager does not connected. ' . $manager->geterror; 
	die;
}

#
# Get QueueStatus to detect agents states and penalty.
#

my $sent = $manager->sendcommand ( Action => 'QueueStatus' );
unless ( defined ( $sent ) ) { 
	warn 'Could not send action to Asterisk Manager. ' . $manager->geterror; 
	die; 
}

my $answer = undef; 
my $agentsStatus = undef;
my $agentsPenalty = undef; 

while ( $answer = $manager->receive_answer ) { 
#warn Dumper ( $answer );
  if ( defined ( $answer->{'Event'} ) ) { 
  	if ( $answer->{'Event'} =~ /QueueMember/i ) { 
			if ( $answer->{'Queue'} =~ /$queuename/i ) {
				if ( defined ( $answer->{'Name'} ) ) { 
				  my $agentname = $answer->{'Name'}; 
					$agentsStatus->{$agentname} = $answer->{'Status'};
					$agentsPenalty->{$agentname} = $answer->{'Penalty'}; 
			  	#warn Dumper ($answer); 
				}
			}
		}
	}
}

#
# Output Agents states and penalty
#

#foreach my $agent ( sort keys %$agentsStatus ) { 
#	print join ( ' : ', $agent, $agentsStatus->{$agent}, $agentsPenalty->{$agent} ) . "<br>"; 	
#}

#
# Get Status to collect information about active calls 
#

$sent = $manager->sendcommand ( Action => 'Status' ); 
unless ( defined ( $sent ) ) { 
	warn 'Could not send action to Asterisk Manager. ' . $manager->geterror; 
	die; 
}

# Будущий ключ для хэша звонков
my $acctcode = undef; 
# Хэш (код) = кол-во звонков 
my $list_acctcodes = undef; 
# Будущий ключ для хэша позиций
my $position = undef; 
my $pk = undef; 
# Хэш (позиция) = кол-во звонков на данной позиции 
my $list_positions = undef; 

while ( $answer = $manager->receive_answer ) {
#	warn Dumper ($answer);
  
	if ( defined ( $answer->{'Event'} ) ) { 
		if ( $answer->{'Event'} =~ /^Status/i ) { 
			if ( defined ( $answer->{'Accountcode'} ) ) { 
				if ( $answer->{'Accountcode'} ne '' ) { 
					$acctcode = $answer->{'Accountcode'};
					if ( defined ( $list_acctcodes->{$acctcode} ) ) { 
						$list_acctcodes->{$acctcode} = $list_acctcodes->{$acctcode} + 1; 
					} else { 
						$list_acctcodes->{$acctcode} = 1; 
					}
				}
		  }
			if ( defined ( $answer->{'Context'} ) ) { 
				if ( defined ( $answer->{'Extension'} ) ) { 
					if ( defined ( $answer->{'Priority'} ) ) { 
					  
						$position = join (',', 
							$answer->{'Context'},
							$answer->{'Extension'},
							$answer->{'Priority'}
						);

						$acctcode = $answer->{'Accountcode'}; 
						$pk = $position . ':' . $acctcode; 						

						if ( defined ( $list_positions->{$pk} ) ) { 
							$list_positions->{$pk} = $list_positions->{$pk} + 1; 
						} else { 
							$list_positions->{$pk} = 1; 
						}
					}
				}
			}
    }
  }
}

#print "List of account codes and count of calls.<br>"; 
#foreach $acctcode ( keys %$list_acctcodes ) {
#	print $acctcode . " : " . $list_acctcodes->{$acctcode} . "<br>"; 
#}

my @str_position; 
my $cls = undef; 

#print "List of account codes and positions and count of calls.<br>";
foreach $pk ( keys %$list_positions ) { 
	@str_position = get_str_position_from_pk ( $pk );
# ( warning, 2012 ) for example. 
#	print $pk . '->' . $str_position[0] .'->' .$str_position[1] .  " = " .  $list_positions->{$pk} . "<br>"; 
	$cls->{$str_position[0]}->{$str_position[1]} = $list_positions->{$pk}; 

}

#---
# Show statistic
#---

#print "Counters of calls<br>"; 
#my $key; 

#foreach $key ( keys %{$conf->{'positions'}} ) { 
#	print $key . " : " . get_count_of_calls($key) . "<br>"; 
#}

my $template_vars = { 
	date_now     => date_now(),
	warning_cnt  => get_count_of_calls('warning'), 
	greeting_cnt => get_count_of_calls('greeting'),
	mainmenu_cnt => get_count_of_calls('mainmenu'),
	waitdtmf_cnt => get_count_of_calls('waitdtmf'),
  wait_expert1_cnt => get_count_of_calls('wait_expert1'),
	wait_expert2_cnt => get_count_of_calls('wait_expert2'),
  expert1_cnt => get_count_of_calls ('expert1'),
	expert2_cnt => get_count_of_calls ('expert2'), 
  wait_for_cloud_cnt => get_count_of_calls ('wait_for_cloud'),
	cc01_state => get_state_by_int ($agentsStatus->{'Agent/701'}), 
	cc01_rt => get_rt_by_state ('Agent/701'),
	cc02_state => get_state_by_int ($agentsStatus->{'Agent/702'}), 
	cc02_rt => get_rt_by_state ('Agent/702'),
	cc03_state => get_state_by_int ($agentsStatus->{'Agent/703'}), 
	cc03_rt => get_rt_by_state ('Agent/704'),
	cc04_state => get_state_by_int ($agentsStatus->{'Agent/705'}), 
	cc04_rt => get_rt_by_state ('Agent/705'),
	cc05_state => get_state_by_int ($agentsStatus->{'Agent/705'}), 
	cc06_rt => get_rt_by_state ('Agent/705'),
	zagalom_cnt => get_count_of_calls(undef), 


	warning_online => show_active_calls('warning'), 
	greeting_online => show_active_calls('greeting'),
  mainmenu_online => show_active_calls('mainmenu'),
	waitdtmf_online => show_active_calls('waitdtmf'),
	wait_expert1_online => show_active_calls('wait_expert1'),
	wait_expert2_online => show_active_calls('wait_expert2'),
  wait_for_cloud_online => show_active_calls('wait_for_cloud'),
	zagalom_online => show_active_calls(undef),

  warning_min => sprintf("%.2f",get_minutes ('warning')), 
	warning_avg => get_average ('warning'), 
  greeting_min => sprintf("%.2f",get_minutes ('greeting')),
	greeting_avg => get_average ('greeting'),
	mainmenu_min => sprintf("%.2f",get_minutes ('mainmenu')),
	mainmenu_avg => get_average ('mainmenu'), 
  waitdtmf_min => sprintf("%.2f",get_minutes ('waitdtmf')),
	waitdtmf_avg => get_average ('waitdtmf'),
	wait_expert1_min => sprintf("%.2f",get_minutes ('wait_expert1')),
	wait_expert1_avg => get_average ('wait_expert1'),
	wait_expert2_min => sprintf("%.2f",get_minutes ('wait_expert2')),
	wait_expert2_avg => get_average ('wait_expert2'),
	wait_for_cloud_min => sprintf("%.2f",get_minutes ('wait_for_cloud')),
	wait_for_cloud_avg => get_average ('wait_for_cloud'),
	zagalom_min => sprintf("%.2f",get_minutes (undef)), 
	zagalom_avg => get_average (undef),


	dtmfplus => get_dtmf_plus(), 
	dtmfminus => get_dtmf_minus(),

};

$template->process('online.tt',$template_vars) || die $template->error() . "\n";

exit (0);

#-----------------------------------------
# Subs list 
#-----------------------------------------

=item B<get_dtmf_plus> , B<get_dtmf_minus> 

 Возвращают количество звонков, которые прошли waitdtmf и не прошли, соответственно. 

=cut 

sub get_dtmf_plus { 
	
	my $pos = 'waitdtmf'; 
	my $sql = "select count(id) as dtmfplus from ivr.navigation_taps_logs where moment between ? and ? and previous_context=?"; 
	my $sth = $dbh->prepare ($sql); 

	eval { 
		$sth->execute($fromdatetime,$tilldatetime,$pos); 
	}; 
	if ( $@ ) { 
		warn $dbh->errstr; 
		exit(-1);
	}

	my $res = $sth->fetchrow_hashref; 
  unless ( defined ( $res ) ) { # No more rows. 
	    return 0;
	}
	return $res->{'dtmfplus'};
}

sub get_dtmf_minus { 

	my $dtmfplus = get_dtmf_plus(); 
	my $warning =  get_count_of_calls('warning'); 

	return $warning - $dtmfplus; 

}

=item B<get_minutes> , B<get_average> 

 Возвращает минуты и среднее пребывание в секундах на разделе. 

=cut 

sub get_minutes { 
	my $pos = shift; 
	my $sql = undef; 

  unless ( defined ( $pos ) ) { 
		$sql = "select (sum(seconds)::float/60)::numeric as minutes from ivr.navigation_taps_logs where moment between ? and ?";
	} else { 
 		$sql = "select (sum(seconds)::float/60)::numeric as minutes from ivr.navigation_taps_logs where current_context=? and moment between ? and ?";
  }
	my $sth = $dbh->prepare($sql);

  eval {
		unless ( defined ( $pos ) ) { 
			$sth->execute($fromdatetime,$tilldatetime);
		} else { 
    	$sth->execute($pos,$fromdatetime,$tilldatetime);
		}
  };
  if ( $@ ) {
    warn $dbh->errstr;
    exit(-1);
  }

  my $res = $sth->fetchrow_hashref;
  unless ( defined ( $res ) ) { # No more rows. 
    return 0;
  }

  return $res->{'minutes'};

}

sub get_average { 
	my $pos = shift; 
	my $sql = undef; 

	unless ( defined ( $pos ) ) { 
		$sql = 'select sum(seconds) as s1, count(seconds) as s2, (sum(seconds)::float/count(seconds)) as average from ivr.navigation_taps_logs where moment between ? and ?';
	} else { 
		$sql = 'select avg(seconds)::integer as average from ivr.navigation_taps_logs where current_context=? and moment between ? and ?';
	} 
  my $sth = $dbh->prepare($sql);

  eval {
		unless ( defined ( $pos ) ) { 
			$sth->execute($fromdatetime,$tilldatetime);
		} else { 
    	$sth->execute($pos,$fromdatetime,$tilldatetime);
		}
  };
  if ( $@ ) {
    warn $dbh->errstr;
    exit(-1);
  }

  my $res = $sth->fetchrow_hashref;
  unless ( defined ( $res ) ) { # No more rows. 
    return 0;
  }

  return $res->{'average'};

} 
=item B<show_active_calls> 

 Возвращает строку, которую надо запихнуть в колонку "Online" указанной таблицы. 

=cut 

sub show_active_calls { 
	my $pos = shift; 
	my $str = '';
	my $count = 0; 
	
	my $zcount = undef; 

	unless ( defined ( $pos ) ) { # Переданный параметр is undef, что означает тот факт, 
																# что надо посчитать все текущие звонки по DNID без учета позиций. 
		foreach my $cpos ( sort keys %{$cls} ) { 
			foreach my $cdnid ( sort keys %{$cls->{$cpos}} ) { 
				unless ( defined ( $zcount->{$cdnid} ) ) { 
					$zcount->{$cdnid} = $cls->{$cpos}->{$cdnid};
				} else { 
					$zcount->{$cdnid} = $zcount->{$cdnid} + $cls->{$cpos}->{$cdnid};
				} 
			}
		} 
		foreach my $cdnid ( sort keys %$zcount ) { 
			$count = $zcount->{$cdnid}; 
			$str .= get_div_by_calls_and_dnid ( $count, $cdnid );
  	}
		return $str; 
  }
	foreach my $cdnid ( sort keys %{$cls->{$pos}} ) { 
		$count = $cls->{$pos}->{$cdnid};  
		$str .= get_div_by_calls_and_dnid ( $count, $cdnid );  
  }
	return $str; 
}

=item B<get_div_by_calls_and_dnid> (count, dnid)

	Возвращает строковую переменную вида 
	<div style="width: 10px; text-align: center; background-color: green; float: left; ">1</div>

=cut 

sub get_div_by_calls_and_dnid { 
	my $count = shift; 
	my $dnid  = shift;

	my $width = $count * 10; 
	my $bgcolor = $conf->{'colors'}->{$dnid}; 

	return sprintf ("<div style=\"width: %d px; text-align: center; background-color: %s; float: left; \">%d</div>", $width, $bgcolor, $count );

}

=item B<get_rt_by_state> 

	Возвращает рейтинг (пеналти) если состояние его != 5; 

=cut 

sub get_rt_by_state { 
	my $agent  = shift; 

	if ($agentsStatus->{$agent} != 5) { 
		return $agentsPenalty->{$agent}; 
	} 
	return undef; 
}
=item B<get_state_by_int> 

 Возвращает строковое описание состояния оператора очереди. 

=cut 

sub get_state_by_int { 
	my $iState = shift; 

	return "NotInUse" if $iState == 1; 
	return "In Use" if $iState == 2; 
	return "Busy" if $iState == 3; 
	return "Unavail." if $iState == 5;
	return "Ringing" if $iState == 6; 
	return "Unknown: $iState"; 

}
=item B<filldatetime>

 Преобразовывает дату и время (даже если они не заданы) в параметр, который годится для работы с БД.
 Пример: 2012-12-21, 12:00 функция преобразует в "2012-12-21 12:00:00", 
 undef,23:12 функция преобразует в <сегодня> "23:12:00" , где <сегодня> будет текущей датой в формате ГГГГ-ММ-ДД.
 если же будет undef,undef , то функция вернет time() в формате YYYY-MM-DD HH:MM:SS

=cut 

sub filldatetime { 
	my $date = shift; 
	my $time = shift; 

	unless ( defined ( $date ) ) { 
		unless ( defined ( $time ) ) { 
			return date_now();
		}
	} 

  unless ( defined ( $date ) ) { 
		$date = date_date(date_now()); 
	} 

  unless ( defined ( $time ) ) { 
		$time = date_time(date_now()); 
	} 

  return $date . ' ' . $time . ':00'; 
	
}

=item B<db_connect> 

 No comments ;-) 

=cut 

sub db_connect { 

    unless ( defined( $conf->{'db'}->{'main'}->{'dsn'} ) ) {
        warn ("Can't find \"db main->dsn\" in configuration.");
        exit(-1);
    }

    unless ( defined( $conf->{'db'}->{'main'}->{'login'} ) ) {
        warn ("Can't find \"db main->login\" in configuraion.");
        exit(-1);
    }

    unless ( defined( $conf->{'db'}->{'main'}->{'password'} ) ) {
        warn ("Can't find \"db main->password\" in configuraion.");
        exit(-1);
    }

    my $dsn    = $conf->{'db'}->{'main'}->{'dsn'};
    my $user   = $conf->{'db'}->{'main'}->{'login'};
    my $passwd = $conf->{'db'}->{'main'}->{'password'};

    # If DBMS isn' t accessible - try reconnect
		if ( !$dbh or !$dbh->ping ) {  
            $dbh = DBI->connect_cached( $dsn, $user, $passwd, { RaiseError => 1, AutoCommit => 0 } );
    }

    if ( !$dbh ) {
				warn ("Can't connect to database."); 
        exit(-1);
    }

    return 1; 
}
=item B<get_count_of_calls>

 	Считает кол-во звонков побывавших в указанной позиции за указанный период 

=cut 

sub get_count_of_calls { 
	my $position_name = shift;

	unless ( defined ( $position_name ) ) { 
		$position_name = 'warning'; 
	} 
	
  my $sql = "select count(id) as cnt from ivr.navigation_taps_logs where current_context=? and moment between ? and ?";
  my $sth = $dbh->prepare($sql);

	eval { 
  	$sth->execute($position_name,$fromdatetime,$tilldatetime);
	}; 
	if ( $@ ) { 
		warn $dbh->errstr; 
		exit(-1);
	} 
	
	my $res = $sth->fetchrow_hashref; 
  unless ( defined ( $res ) ) { # No more rows. 
		return 0; 
	}

	my $count = $res->{'cnt'}; 

  return $count; 

}

=item B<get_str_position_from_pk>

 Данная функция возвращает позицию в виде описания из конфигурационного файла исходя из строки вида "context,extension,priority:номер"
 Пример результата: "warning",2012 или "greeting",0900123123

=cut 

sub get_str_position_from_pk { 
	my $key = shift; 
  my ( $pos, $dnid ) = split (':',$key);
	my ( $context, $extension, $priority ) = split (',',$pos); 
	
	foreach $key ( keys %{$conf->{'positions'}} ) { 
		if ($conf->{'positions'}->{$key} eq $pos ) {
			return ($key,$dnid);
		}
		if ($conf->{'positions'}->{$key} eq $context) {
			return ($key,$dnid); 
		} 
	} 
	return ('unknown',$dnid);  

}

1;
#===============================================================================

__END__

=head1 NAME

online.pl

=head1 SYNOPSIS

online.pl

=head1 DESCRIPTION

FIXME

=head1 EXAMPLES

FIXME

=head1 BUGS

Unknown.

=head1 TODO

Empty.

=head1 AUTHOR

Alex Radetsky <rad@rad.kiev.ua>

=cut

