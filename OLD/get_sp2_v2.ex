#!/usr/bin/expect

log_user 0;
#===========================================================================
# PROCEDURE TO CONNECT TO A PORT USING KERMIT
#============================================
proc spawn_kermit {hub_url portnumber} {
	set pid [spawn kermit]
	set timeout 4	
	expect {
		">>"
	}	
		# START KERMIT
	spawn kermit
	set PDS $spawn_id
	set timeout 1
	expect {
		timeout {"KERMIT FAILS TO OPEN\n"; exit 1}
		">>"
	}
	#send_user "OPEN PORT $portnumber\n";
	## OPEN THE PORT
	send "set host $hub_url $portnumber\r"
	expect ">>"
	#send_user "set host $hub_url $portnumber\n";
	
	## FINE TUNING TCP/IP
	send "set tcp recvbuf 1000\r\n"
	expect ">>"
	send "set tcp keepalive off\r\n"
	expect ">>"
	send "set tcp linger on 100\r\n"
	expect ">>"
	send "set tcp nodelay on\r\n"
	expect ">>"
	send "set telnet echo local\r\n"
	expect ">>"
	## this is important for using the rsr menu
	## raw means send CR by itself, not CRLF and NOT CRNul
	send "set telnet newline-mode nvt raw\r\n"
	expect ">>"


	## CONNECT 
	send "connect\r"
	expect {
		"Conn*---"  {return $spawn_id;}
	}
}

#=========================== END OF PROCEDURES =====================================
		# SETUP FILE
set setupfile  [lindex $argv 0]
send_user "SETUP FILE FROM CMD LINE: $setupfile"
		# EXISTS
if [catch {open $setupfile} sufile] {
	send_user "Setup file open fails, exit 1"
	exit 1
} else {
	send_user "SETUP FILE $setupfile EXISTS"
}
		# HUB IP
spawn -noecho ./getsetupinfo.pl $setupfile "SERIAL HUB2 URL"
expect -re "(\.*)(\r)";
set hub_url $expect_out(1,string);
send_user "HUB2 IP: $hub_url\n";
		# DEFINE THE PORTS 
spawn -noecho ./getsetupinfo.pl $setupfile SP2 HUB COM NUMBER"
expect -re "(\.*)(\r)";
set spnport $expect_out(1,string)
puts "SP2 HUB PORT NUMBER = $spnport"
		# CONNECT / SIMULATE
if {$spnport == 0} {
	send_user "SIMULATE SPN: SPAWN simulate/adc_simulator.pl\n"
	spawn perl simulate/spn_simulator.pl 
	set SPN	$spawn_id;
	send_user "SPN SIMULATE, id = $SPN\n"
} else {
	send_user "OPEN SPN PORT $hub_url $spnport \n";
	set SPN [spawn_kermit $hub_url $spnport];
	# OPEN PORT FAILS
	if { $SPN == 0 } {
		send_user "SPN KERMIT SPAWN FAILS ON START UP\n"
		exit 1
	} else {
		send_user "SPN KERMIT SPAWN SUCCESS, ID = $SPN\n"
	}
}
		# QUERY LOOP
set timeout 1
set spawn_id $SPN
set replySPN "0"
		# MAIN LOOP
set looptime 0
while 1 {
	set dt [timestamp -gmt]
	if { [expr $dt - $looptime] > 0 } { 
		send -i $SPN "R"
		send -i $SPN "S"
		#send -i $SPN "RS\n"
		expect {
			timeout { set replySPN "0"; send_user "\nSPN timeout\n" }
			-re "( .*,.*,.*)" {
					set str $expect_out(1,string)
					#send_user "\nTEST $str\n"
					split $str " ,"
					#exit
					set replySPN [string trimright $str]   ;# remove cr/lf and any spaces
			}
		}
		send_user "SP2RAW $replySPN\r\n";
		set looptime [timestamp -gmt]		
	}
}
