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
use CGI; 
use DBI;
use Data::Dumper;

my $cgi = CGI->new;
my $queuename = $cgi->param('queue');

print "Hello, VES-media\n"; 
print "We working on $queuename\n"; 

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

my $sent = $manager->sendcommand ( Action => "QueueStatus" );
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

foreach my $agent ( sort keys %$agentsStatus ) { 
	print join ( ' : ', $agent, $agentsStatus->{$agent}, $agentsPenalty->{$agent} ) . "\n"; 	
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

