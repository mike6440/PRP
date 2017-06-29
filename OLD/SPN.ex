#!/usr/bin/expect --

#===================================================
set PROGRAMNAME PRP_spn.ex
set VERSION 1
set EDITDATE 120420
# 
puts "
RUN PROGRAM $PROGRAMNAME, VERSION $VERSION, EDITDATE $EDITDATE"

set loguser 0;#   test 0-quiet, 1=verbose
log_user $loguser;



#===================================================================
#   PROCEDURE TO START AVG PROGRAM
#==================================
proc SpawnAvgSpn { setupfile infoname } {
	spawn perl avgspn.pl $setupfile;
	set SPNAV $spawn_id;
	write_info $infoname "SPAWN SPNAV spawn_id = $spawn_id"
	# WAIT FOR THE STARTUP PROMPT
	set timeout 2
	expect {
		# TIMEOUT (avg program) WITH NO REPLY
		timeout {
			send -i $SPNAV "quit\r\n"
			send_user "SPNAV STARTUP, Timeout with no reply\n"
			exit 1
		}
		# REPLY FROM AVG PROGRAM
		"SPN--" {
			send_user "AVGSPN is ready\n"
		}
	}
	return $SPNAV
}


#====================================================================
# PROCEDURE WRITE_INFO
# input
#  fname = fullfile name towrite the info string
#  str=the string to write
#=============
proc write_info {fname str} {
	set tm [timestamp -gmt -format "%y%m%d,%H%M%S"]
	set str "$tm,$str";
	set F [open $fname a]
	puts $F "$str" 
	close $F
	return $str
}

#============================================
# PROCEDURE TO CONNECT TO A PORT USING KERMIT
#============================================
proc spawn_kermit {hub_url portnumber} {
	# START PROCESS -- KERMIT
	send_user "Launch kermit\n";		
	set pid [spawn kermit]
	set timeout 4	
	expect {
		timeout {send_user "KERMIT FAILS TO OPEN\n"; exit 1}
		">>"
	}
	
	send_user "OPEN PORT $portnumber\n";
	## OPEN THE PORT
	send "set host $hub_url $portnumber\r"
	expect ">>"
	send_user "set host $hub_url $portnumber\n";
	
	## FINE TUNING TCP/IP
	send "set tcp keepalive on 0\r\n"
	expect ">>"
	send "set tcp linger OFF\r\n"
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
		"Conn*---"  {send_user "PORT $portnumber CONNECTED\n"; return $spawn_id;}
		timeout {send_user "TIMEOUT, NO CONNECT"; exit 1}
	}
}
#==================== END PROCEDURES =============================================


#==============
# OS
# Define the operating system -- unamestr = "Darwin" or Linux
#=============
set unamestr [exec uname]
puts "system = $unamestr"

#==============
# SETUP FILE DEFINED
#==============
set setupfile  [lindex $argv 0]
## SEE IF THE SETUP FILE EXISTS
if [catch {open $setupfile} sufile] {
	puts "SETUP FILE $setupfile DOES NOT EXIST. STOP."
	exit 1
} else {
	puts "SETUP FILE $setupfile EXISTS"
}

#============
# INITIALIZE THE INFO FILE
# We create a new info file each time we start the program.
#==============
## READ THE RT OUT PATH
spawn -noecho ./getsetupinfo.pl $setupfile "DATA OUTPUT PATH"
expect -re "(\.*)(\r)";
set datapath $expect_out(1,string)
send_user "DATAPATH = $datapath\n";

# WRITE A HEADER TO INFO FILE
set tm [timestamp -gmt -format "%y%m%d%H%M%S"];
set infoname "$datapath/InfoZmet.txt";

set str  "PROGRAM $PROGRAMNAME, Version $VERSION, Editdate $EDITDATE, Runtime [timestamp -gmt -format "%Y%m%d,%H%M%S"]"
write_info $infoname  $str 
write_info $infoname "\n========== BEGIN PROGRAM $PROGRAMNAME ============="
write_info $infoname  "DATA OUTPUT PATH: $datapath"

## EXPERIMENT NAME
spawn -noecho ./getsetupinfo.pl $setupfile "EXPERIMENT NAME"
expect -re "(\.*)(\r)";
set expname $expect_out(1,string)
write_info $infoname  "EXPERIMENT NAME: $expname"

## GEOGRAPHIC LOCATION
spawn -noecho ./getsetupinfo.pl $setupfile "GEOGRAPHIC LOCATION"
expect -re "(\.*)(\r)";
write_info $infoname  "GEOGRAPHIC LOCATION: $expect_out(1,string)"

## PLATFORM NAME
spawn -noecho ./getsetupinfo.pl $setupfile "PLATFORM NAME"
expect -re "(\.*)(\r)";
write_info $infoname  "PLATFORM NAME: $expect_out(1,string)"

## LOCATION ON PLATFORM
spawn -noecho ./getsetupinfo.pl $setupfile "LOCATION ON PLATFORM"
expect -re "(\.*)(\r)";
write_info $infoname  "LOCATION ON PLATFORM: $expect_out(1,string)"

## TIME WITH NO SPN
spawn -noecho ./getsetupinfo.pl $setupfile "SPN DEAD TIME ALARM"
expect -re "(\.*)(\r)";
write_info $infoname  "SPN DEAD TIME ALARM: $expect_out(1,string)"
set zdeadtime $expect_out(1,string);
puts "SPN DEAD TIME: $zdeadtime";

# PDS SERIAL HUB URL AND OFFSET
spawn -noecho ./getsetupinfo.pl $setupfile "SERIAL HUB URL"
expect -re "(\.*)(\r)";
set hub_url $expect_out(1,string)
write_info $infoname  "SERIAL HUB URL: $hub_url"

# SPN SAMPLE TIME
spawn -noecho ./getsetupinfo.pl $setupfile "SPN SAMPLE TIME"
expect -re "(\.*)(\r)";
set spnsampletime $expect_out(1,string)
write_info $infoname  "SPN SAMPLE TIME: $spnsampletime"

#=======================================
## DEFINE THE PORTS 
# gpsport, sbdport, spnport
#=======================================
## SPN
spawn -noecho ./getsetupinfo.pl $setupfile "SPN HUB COM NUMBER"
expect -re "(\.*)(\r)";
set spnport $expect_out(1,string)
write_info $infoname  "SPN HUB COM NUMBER: $spnport"
puts "SPN HUB PORT NUMBER = $spnport"

#=================
# OPEN SET FILE NAMES AND NOTE TIME
#=================
# THIS JULIAN DAY
# day0 = START JULIAN DAY
set day0 [timestamp -gmt -format "%j"]
write_info $infoname "start year day: $day0";
# day1 = current day used to detect a new day at midnight
set day1 $day0

#=================
# WRITE TO RAW AND AVG FILE
#=================
set fname [timestamp -gmt -format "%y%m%d"]
set spnrawname "$datapath/spn_raw_$fname.txt";
puts "SPN RAW FILE NAME = $spnrawname";
write_info $infoname "START PROGRAM $PROGRAMNAME, version $VERSION";
write_info $infoname  "OPEN RAW FILE $spnrawname";
write_info $infoname  "OPEN FILE $infoname";
puts "SPN INFO FILE NAME = $infoname";

#============================================================
# KERMIT/SIMULATE CONNECTION
#==================
if {$spnport == 0} {
	send_user "SIMULATE SPN: SPAWN simulate/spn_simulator.pl\n"
	puts "exit 207"
	exit
	spawn perl simulate/spn_simulator.pl 
	set SPN	$spawn_id;
	write_info $infoname "SPN SIMULATE, id = $SPN"
} else {
	send_user "OPEN SPN PORT $hub_url $spnport \n";
	set SPN [spawn_kermit $hub_url $spnport];
	# OPEN PORT FAILS
	if { $SPN == 0 } {
		write_info $infoname "SPN KERMIT SPAWN FAILS ON START UP"
		exit 1
	} else {
		write_info $infoname "SPN KERMIT SPAWN SUCCESS, ID = $SPN"
	}
}

#==========================
# AVGSPN PROGRAM
#================
log_user  $loguser;  ;#test 0-quiet, 1=verbose
set SPNAV [SpawnAvgSpn $setupfile $infoname]

set timeout 3		;# leave enough time for the scan drum to move
set timeout_flag 0  ;# SET THE FLAG TO CATCH $ISAR5 PROBLEMS

# =====================
# MAIN LOOP
# Wait for a string from isar
# Send the string to isar_avg program
#======================
write_info $infoname "===== BEGIN MAIN LOOP ====="
set timespn [timestamp -gmt]
# COUNT THE NUMBER OF GOOD ISAR RECORDS RECEIVED
set Nrecs 0
set day0 0 ;# to initiate the first raw file
set dtspn 0

# EXPECT LOOP
while 1 {
	# DT IS THE CURRENT TIME
	set dt [timestamp -gmt]
	
	#=====================
	# CHECK FOR A GAP IN RAW STRINGS
	#=====================
	if { [expr $dt - $timespn] > $zdeadtime } {
		send_user "NO RAW SPN IN $zdeadtime SECS.\n"
		set timespn $dt
	}
	
	#======
	# CHECK FOR A NEW DAY -- NEW FILES
	#======
	set day1 [timestamp -gmt -format "%j"]
	if {$day1 != $day0} {
		send_user "DAY CHANGE\r\n"
		set day0 $day1
		set fname [timestamp -gmt -format "%y%m%d"]
		set spnrwname "$datapath/spn_raw_$fname.txt";
		if {[file exists $spnrwname]} {
			send_user "Appending to file $spnrwname\n"
		} else {
			set F [open $spnrwname w 0600]
			puts $F "nrec yyyy MM dd hh mm ss spn1 spn2 v2 v3 v4 v5 v6 v7"
			close $F
		}
		write_info $infoname "---NEW DAY---"
		write_info $infoname "spnrwname = $spnrwname"
	}
	
	if { [expr $dt - $dtspn] >= $spnsampletime } {
		send -i $SPN "#01\r"
		expect *
		set dtspn $dt
		
		#================
		# EXPECT FUNCTION -- WAITING FOR RESPONSE
		# +001.98+002.50+002.00+001.93+001.70+001.66+001.64+001.72
		# ===============
		expect { 
			-i $SPN  ">*\r" {
				set spnrawstr [string trimright $expect_out(0,string)]
				#send_user "RCVD: $spnrawstr\n"
				
				# SAVE TO RAW FILE
				set F [open $spnrawname a 0600]
				set rawstr [timestamp -gmt -format "$Nrecs %Y %m %d %H %M %S "]$spnrawstr
				puts $F $rawstr
				close $F
				send_user "$rawstr\n";
				
				# increment Nrecs
				set Nrecs [expr $Nrecs + 1];
				set timetcm [timestamp -gmt];		#v1a time of the last good isar
				
				send -i $SPNAV "$spnrawstr\r"						;# send raw str to avgrsr.pl
				
				#expect -i $SPNAV "<<SPNRW*>>\r"  { send_user "expect_out(0,string)\n" }
			}
			
			-i $SPNAV 
			# OTHER INFO FROM AV PROCESS
			eof {
				write_info $infoname "avgspn.pl has crashed\n";
				exit 1
			}
			#=======================
			# AVERAGE RECORD FROM ISARAV
			#=======================
			-re "(SPNAV.*)\r" {
				set timeout 10
				set spawn_id $SPNAV
				set avgstr $expect_out(1,string)
				send_user "SPN AVG: nrec yyyy MM dd hh mm ss v0 v1 v2 v3 v4 v5 v6 v7   std0 std1 std2 std3 std4 std5 std6 std7\n";
				send_user "SPN AVG: $avgstr\r\n"
			}
		}
	}
}

