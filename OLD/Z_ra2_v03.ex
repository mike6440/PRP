#!/usr/bin/expect --

set PROGRAMNAME Z_RA2
set VERSION 03
set EDITDATE 130630
#v03  add global variable and eof check w restart

puts "
RUN PROGRAM $PROGRAMNAME, VERSION $VERSION, EDITDATE $EDITDATE"

set loguser 0;
log_user $loguser  ;# 0-quiet, 1=verbose

global RAD RADPID RADAV RADAVPID

#========================================================
		# PROCEDURE TO CONNECT TO RAD  v3
#============================================================
proc SpawnRad { hub_url radport infoname} {
	global RAD RADPID
	if {$radport == 0} {
		send_user "SIMULATE RA2: SPAWN simulate/ra2_simulator.pl\n";
		set RADPID [spawn perl simulate/ra2_simulator.pl] 
		set RAD $spawn_id
		write_info $infoname "SPAWN RA2 SIMULATE, spawn_id = $RAD,  pid = $RADPID"
	} else {
		send_user "OPEN RA2 PORT $hub_url $radport \n";
		spawn_kermit $hub_url $radport
		write_info $infoname "SPAWN RA2 KERMIT, spawn_id = $RAD,  pid = $RADPID"
	}
}


#======================================
#   PROCEDURE TO START AVGRA2 PROGRAM
#==================================
proc SpawnAvgRad { setupfile infoname } {
	global RADAV RADAVPID
	set RADAVPID [spawn perl avgra2.pl $setupfile]
	set RADAV $spawn_id
	write_info $infoname "SPAWN AVGRA2 spawn_id = $RADAV, pid = $RADAVPID"
			# PROGRAM REPLY
	expect {
		eof {
			send_user "AVGRA2 STARTUP, eof\n"
			exit 1
		}
		"RA2--" {
			send_user "AVGRA2 is ready, spawn_id=$RADAV,  pid = $RADAVPID\n"
		}
	}
}

#====================================================================
# PROCEDURE WRITE_INFO
#=============
proc write_info {fname str} {
	set tm [timestamp -format "%y%m%d,%H%M%S"]
	set str "$tm,$str";
	#send_user "$str\n"
	set F [open $fname a]
	puts $F "$str" 
	close $F
	return $str
}

#===========================================================================
# PROCEDURE TO CONNECT TO A PORT USING KERMIT
# input
#	serialport = full path name for the serial port, e.g. /dev/tty.usbserial0
#   baud = desired baud rate, e.g. 9600
#============================================
proc spawn_kermit {hub_url portnumber} {
	global RAD RADPID
			# START PROCESS -- KERMIT
	set RADPID [spawn kermit]
	set RAD $spawn_id
	expect {
		timeout {send_user "KERMIT FAILS TO OPEN\n"; exit 1}
		">>"
	}
	
	send_user "OPEN PORT $hub_url  $portnumber\n";
			# OPEN THE PORT
	send "set host $hub_url $portnumber\r"
	expect ">>"
	send "set tcp keepalive on 0\r\n"
	expect ">>"
	send "set tcp linger OFF\r\n"
	expect ">>"
	send "set tcp nodelay on\r\n"
	expect ">>"
	send "set telnet echo local\r\n"
	expect ">>"
			# this is important for using the rsr menu
			# raw means send CR by itself, not CRLF and NOT CRNul
	send "set telnet newline-mode nvt raw\r\n"
	expect ">>"
			# CONNECT 
	send "connect\r"
	expect {
		timeout {send_user "TIMEOUT, NO CONNECT"; exit 1}
		"Conn*---"  {send_user "PORT $portnumber CONNECTED\n"; return $spawn_id;}
	}
}
#==================== END PROCEDURES =============================================

		# SETUP FILE DEFINED
set setupfile  [lindex $argv 0]
puts "SETUP FILE FROM CMD LINE: $setupfile"
## SEE IF THE SETUP FILE EXISTS
if [catch {open $setupfile} sufile] {
	puts "Setup file open fails, exit 1"
	exit 1
} else {
	puts "SETUP FILE $setupfile EXISTS"
}


		# DATAPATH
spawn -noecho ./getsetupinfo.pl $setupfile "RT OUT PATH"
expect -re "(\.*)(\r)";
set datapath $expect_out(1,string)
send_user "DATAPATH = $datapath\n";

		# ARM DATA PATH DEFINED
append armpath $env(DAQFOLDER) "/ARM"
send_user "ARMPATH = $armpath\n"


		# HEADER FILE
set tm [timestamp -format "%y%m%d%H%M%S"];
set infoname "$datapath/ra2_info.txt";
puts "RA2 INFORMATION FILE: $infoname\n"
set str  "PROGRAM $PROGRAMNAME, Version $VERSION, Editdate $EDITDATE, Runtime [timestamp -format "%Y%m%d,%H%M%S"]"
write_info $infoname  $str 
write_info $infoname "\n========== BEGIN PROGRAM $PROGRAMNAME ============="

write_info $infoname  "RT OUT PATH: $datapath"

spawn -noecho ./getsetupinfo.pl $setupfile "SERIAL HUB2 URL"
expect -re "(\.*)(\r)";
set hub_url $expect_out(1,string)
write_info $infoname  "SERIAL HUB2 URL: $hub_url"

spawn -noecho ./getsetupinfo.pl $setupfile "RA2 HUB COM NUMBER"
expect -re "(\.*)(\r)";
set radport $expect_out(1,string)
write_info $infoname  "RA2 HUB COM NUMBER: $radport"

spawn -noecho ./getsetupinfo.pl $setupfile "RA2 MODEL NUMBER"
expect -re "(\.*)(\r)";
write_info $infoname  "RA2 MODEL NUMBER: $expect_out(1,string)"

spawn -noecho ./getsetupinfo.pl $setupfile "RA2 SERIAL NUMBER"
expect -re "(\.*)(\r)";
write_info $infoname  "RA2 SERIAL NUMBER: $expect_out(1,string)"

spawn -noecho ./getsetupinfo.pl $setupfile "RA2 PSP SERIAL NUMBER"
expect -re "(\.*)(\r)";
write_info $infoname  "RA2 PSP SERIAL NUMBER: $expect_out(1,string)"

spawn -noecho ./getsetupinfo.pl $setupfile "RA2 PIR SERIAL NUMBER"
expect -re "(\.*)(\r)";
write_info $infoname  "RA2 PIR SERIAL NUMBER: $expect_out(1,string)"

spawn -noecho ./getsetupinfo.pl $setupfile "RA2 AVERAGING TIME"
expect -re "(\.*)(\r)";
write_info $infoname  "RA2 AVERAGING TIME: $expect_out(1,string)"

		# TIME WITH NO DATA
spawn -noecho ./getsetupinfo.pl $setupfile "RAD DEAD TIME ALARM"
expect -re "(\.*)(\r)";
write_info $infoname  "RAD DEAD TIME ALARM: $expect_out(1,string)"
set raddeadtime $expect_out(1,string);
puts "RAD DEAD TIME: $raddeadtime";

		# OPEN TELNET CONNECTIO
SpawnRad $hub_url $radport $infoname
send_user "RAD = $RAD, PID=$RADPID\n";

		# TCMAV PROGRAM
SpawnAvgRad $setupfile $infoname

# =====================
# MAIN LOOP
#======================
		# COUNT GOOD RAW RECORDS
set Nrecsrad 0
set day0 0 ;# to initiate the first raw file
set hour0 "2000010100";# ARM HOURLY FILES
set Nrecs 0

set timemsg [timestamp -gmt]	;# --- MISSING INPUT TRANSMIT TIME
set timerad $timemsg			;# --- TIME THE RAD IS RECEIVED 
set timeradlast 1e8      		;# --- TIME OF THE LAST RECEIVED RAD

while 1 {
	set dt [timestamp -gmt]		;# --- LOOP TIME
	
			# TIMEOUT
	if { [expr $dt - $timemsg] > 60 && [expr $dt - $timerad] > $raddeadtime} {
		send_user "NO RAW RA2 since [time format $timerad -format "%y%m%d,%H%M%S"].\n"
		set timemsg $dt
	}
	
			# NEW DAY -- NEW FILES
	set day1 [timestamp -gmt -format "%j"]  
	if {$day1 != $day0} {
		set day0 $day1
		set fname [timestamp -gmt -format "%y%m%d" ]
		set rawname "$datapath/ra2_raw_$fname.txt";
		if {[file exists $rawname]} {
			#send_user "Appending to file $rawname\n"
		} else {
			set F [open $rawname w 0600]
			puts $F "nrecs yyyy MM dd hh mm ss \$WIR07,yy/MM/dd,hh:mm:ss,npts,pir,lw,tcase,tdome,sw,trad,batt"
			close $F
		}
	}
	
			# ARM HOUR FILE NAME
	set hour1 [timestamp -gmt -format "%y%m%d%H"]
	if { ![string match $hour1 $hour0] } {
		set hour0 $hour1
				# ARM RAW FILE
		set rawnameh "$armpath/ra2_raw_$hour1.txt";
		if {[file exists $rawnameh]} {
			#send_user "Appending to file $rawnameh\n"
		} else {
			set F [open $rawnameh w 0600]
			puts $F "nrecs yyyy MM dd hh mm ss \$WIR07,yy/MM/dd,hh:mm:ss,npts,pir,lw,tcase,tdome,sw,trad,batt"
			close $F
		}
	}

	#===================================
	# EXPECT
	#===================================
	set timeout 1
	expect { 
		-i $RAD
		eof {
			send_user "RAD connection eof.\n"
			SpawnRad $hub_url $radport $infoname
			send_user "RE-START RAD, spawn_id = $RAD, pid=$RADPID\n";
		}
		-re "(\\\$WIR\.*)\n" {
			set timerad [timestamp -gmt]    ;# exact time the packet is received.
					# --- TRAP DUP TIMES ----
			if { $timerad <= $timeradlast } {
				send_user "."
				set timerad [expr $timerad + 1]
			}
				set timeradlast $timerad;
						#-------			
				set radstr $expect_out(1,string);
				set radstr [string trimright $radstr]
				set rawstr $Nrecs[timestamp -gmt -format "$Nrecs %Y %m %d %H %M %S "]$radstr
				
						# SAVE TO RAW FILE
				set F [open $rawname a 0600]
				puts $F $rawstr
				close $F
				
						# SAVE TO ARM HOUR RAW FILE
				set F [open $rawnameh a 0600]
				puts $F $rawstr
				close $F
				
						# SEND RAW TO AVG AND RCV RESPONSE
				set spawn_id $RADAV
				send "$radstr\r\n"
				expect {
					-re "<<(RA2RW\.*)>>"	{send_user "$expect_out(1,string)\n"} 
				}
				set Nrecs [expr $Nrecs + 1];
			
		}
		
		-i $RADAV
		eof {
			send_user "AVGRA2 fails.\n";
			SpawnAvgRad $setupfile $infoname
			send_user "RE-START AVGRA2, spawn_id = $RADAV,   pid = $RADAVPID\n";
		}
		-re "<<(RA2AV\.*)>>"  {
			send_user "nsamp yyyy MM dd hh mm ss    sw stdsw   lw stdlw     pir stdpir    tcase  tdome   tpcb  batt rsroff\n"
			send_user "$expect_out(1,string)\n"
		}
	}
}
