#!/usr/bin/expect --

set PROGRAMNAME Z_tcm.ex
set VERSION 1
set EDITDATE 120125
# 
puts "
RUN PROGRAM $PROGRAMNAME, VERSION $VERSION, EDITDATE $EDITDATE"

set loguser 0;#   test 0-quiet, 1=verbose
log_user $loguser;

#===================================================================
#   PROCEDURE TO START AVGTCM PROGRAM
#==================================
proc SpawnAvgTcm { setupfile infoname } {
	spawn perl avgtcm.pl $setupfile;
	set TCMAV $spawn_id;
	write_info $infoname "SPAWN TCMAV spawn_id = $spawn_id"
	# WAIT FOR THE STARTUP PROMPT
	set timeout 5
	expect {
		# TIMEOUT (avg program) WITH NO REPLY
		timeout {
			send -i $TCMAV "quit\r\n"
			send_user "TCMAV STARTUP, Timeout with no reply\n"
			exit 1
		}
		# REPLY FROM AVG PROGRAM
		"TCM--" {
			send_user "AVGTCM is ready\n"
		}
	}
	return $TCMAV
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

#===========================================================================
# PROCEDURE TO CONNECT TO A PORT USING KERMIT
# input
#	serialport = full path name for the serial port, e.g. /dev/tty.usbserial0
#   baud = desired baud rate, e.g. 9600
#Note: you need a .kermrc file in the home dir with this line:
#  prompt k>>
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
# SETUP FILE DEFINED
#==============
set setupfile  [lindex $argv 0]
puts "SETUP FILE FROM CMD LINE: $setupfile"
## SEE IF THE SETUP FILE EXISTS
if [catch {open $setupfile} sufile] {
	puts "Setup file open fails, exit 1"
	exit 1
} else {
	puts "SETUP FILE $setupfile EXISTS"
}

## READ THE RT OUT PATH
spawn -noecho ./getsetupinfo.pl $setupfile "RT OUT PATH"
expect -re "(\.*)(\r)";
set datapath $expect_out(1,string)
send_user "DATAPATH = $datapath\n";

#    ARM DATA PATH DEFINED
set i1 [string last "data" $datapath]
set str1 [string range $datapath 0 [expr $i1 - 1]]
set i1 [string last "data" $str1]
set str1 [string range $datapath 0 [expr $i1 - 1]]
append armpath $str1 "ARM"
send_user "ARMPATH = $armpath\n"

# WRITE A HEADER TO INFO FILE
set tm [timestamp -format "%y%m%d%H%M%S"];
set infoname "$datapath/tcm_info.txt";
puts "TCM INFORMATION FILE: $infoname\n"
set str  "PROGRAM $PROGRAMNAME, Version $VERSION, Editdate $EDITDATE, Runtime [timestamp -format "%Y%m%d,%H%M%S"]"
write_info $infoname  $str 

# WRITE A HEADER TO INFO FILE
set tm [timestamp -gmt -format "%y%m%d%H%M%S"];
set infoname "$datapath/tcm_info.txt";
set str  "PROGRAM $PROGRAMNAME, Version $VERSION, Editdate $EDITDATE, Runtime [timestamp -gmt -format "%Y%m%d,%H%M%S"]"
write_info $infoname  $str 
write_info $infoname "\n========== BEGIN PROGRAM $PROGRAMNAME ============="

## =========================================
## READ THE SETUPFILE
## ========================================
write_info $infoname  "RT OUT PATH: $datapath"

## TIME WITH NO TCM
spawn -noecho ./getsetupinfo.pl $setupfile "TCM DEAD TIME ALARM"
expect -re "(\.*)(\r)";
write_info $infoname  "TCM DEAD TIME ALARM: $expect_out(1,string)"
set zdeadtime $expect_out(1,string);
puts "TCM DEAD TIME: $zdeadtime";

# PDS SERIAL HUB URL AND OFFSET
spawn -noecho ./getsetupinfo.pl $setupfile "SERIAL HUB URL"
expect -re "(\.*)(\r)";
set hub_url $expect_out(1,string)
write_info $infoname  "SERIAL HUB URL: $hub_url"

spawn -noecho ./getsetupinfo.pl $setupfile "TCM HUB COM NUMBER"
expect -re "(\.*)(\r)";
set tcmport $expect_out(1,string)
write_info $infoname  "TCM HUB COM NUMBER: $tcmport"
puts "TCM HUB PORT NUMBER = $tcmport"

# KERMIT/SIMULATE CONNECTION
if {$tcmport == 0} {
	send_user "SIMULATE TCM: SPAWN simulate/tcm_simulator.pl\n"
	spawn perl simulate/tcm_simulator.pl 
	set TCM	$spawn_id;
	write_info $infoname "TCM SIMULATE, id = $TCM"
} else {
	send_user "OPEN TCM PORT $hub_url $tcmport \n";
	set TCM [spawn_kermit $hub_url $tcmport];
	# OPEN PORT FAILS
	if { $TCM == 0 } {
		write_info $infoname "TCM KERMIT SPAWN FAILS ON START UP"
		exit 1
	} else {
		write_info $infoname "TCM KERMIT SPAWN SUCCESS, ID = $TCM"
	}
}


#==========================
# AVGTCM PROGRAM
#================
set TCMAV [SpawnAvgTcm $setupfile $infoname]


# =====================
# MAIN LOOP
#======================
set timetcm [timestamp -gmt]
# COUNT THE NUMBER OF GOOD RAW RECORDS RECEIVED
set Nrecsrad 0
set day0 0 ;# to initiate the first raw file
set hour0 "2000010100";# ARM HOURLY FILES
set Nrecs 0

while 1 {
	set dt [timestamp -gmt]
	
	#=====================
	# CHECK FOR A GAP IN RAW STRINGS
	#=====================
	if { [expr $dt - $timetcm] > $zdeadtime } {
		send_user "NO RAW TCM IN $zdeadtime SECS.\n"
		set timetcm $dt
		set dt0 $dt
	}
	
	#======
	# CHECK FOR A NEW DAY -- NEW FILES
	#======
	set day1 [timestamp -gmt -format "%j"]
	if {$day1 != $day0} {
		send_user "DAY CHANGE\r\n"
		set day0 $day1
		set fname [timestamp -gmt -format "%y%m%d"]
		set rwname "$datapath/tcm_raw_$fname.txt";
		if {[file exists $rwname]} {
			send_user "Appending to file $rwname\n"
		} else {
			set F [open $rwname w 0600]
			puts $F "nrec yyyy MM dd hh mm ss comp pitch roll Xmag Ymag Zmag Ttcm"
			close $F
		}
		write_info $infoname "---NEW DAY---"
		write_info $infoname " = $rwname"
	}
	## ARM HOUR FILE NAME
	set hour1 [timestamp -gmt -format "%y%m%d%H"]
	if { ![string match $hour1 $hour0] } {
		puts "NEW HOUR";
		set hour0 $hour1
		# ARM RAW FILE
		set rawnameh "$armpath/tcm_raw_$hour1.txt";
		puts "ARM HOUR RAW FILE NAME = $rawnameh";
		if {[file exists $rawnameh]} {
			#send_user "Appending to file $rawnameh\n"
		} else {
			set F [open $rawnameh w 0600]
			puts $F "nrec yyyy MM dd hh mm ss comp pitch roll Xmag Ymag Zmag Ttcm"
			close $F
		}
	}
	
	#================
	# EXPECT FUNCTION -- WAITING FOR RESPONSE
	#$C83.9P-0.1R-0.7X6.61Y-60.51Z72.32T18.0*77 == standard word
	# ===============
	expect { 		
		-i $TCM
		-re "(\\\$C.*)\r\n" {
			set tcmrawstr [string trimright $expect_out(1,string)]
			set rawlen [string length $tcmrawstr]
			## CHOP OFF THE HEADER AND THE CHECKSUM TAIL v4
			## $C83.9P-0.1R-0.7X6.61Y-60.51Z72.32T18.0*77
			
			set strx [ string range $tcmrawstr 2 end-3 ]
			regsub "P" $strx " " strx
			regsub "R" $strx " " strx
			regsub "X" $strx " " strx
			regsub "Y" $strx " " strx
			regsub "Z" $strx " " strx
			regsub "T" $strx " " strx
			regsub -all "," $strx " " strx
			# increment Nrecs
			set Nrecs [expr $Nrecs + 1];
			set timetcm [timestamp -gmt];		#v1a time of the last good isar
			
			# SAVE TO RAW FILE
			set F [open $rwname a 0600]
			set rawstr $Nrecs[timestamp -gmt -format " %Y %m %d %H %M %S "]$strx  ;#v8d
			puts $F $rawstr
			close $F
			#send_user ">>$rawstr\n"
			
			# SAVE TO ARM HOUR RAW FILE
			set F [open $rawnameh a 0600]
			puts $F $rawstr
			close $F
			
			#===================
			# SEND TO AVG AND AVG FOR RESPONSE
			#===================
			#send -i $TCMAV "$tcmrawstr\r\n"
			# SEND RAW TO AVG AND RCV RESPONSE
			set spawn_id $TCMAV
			send "$tcmrawstr\r\n"
			expect {
				-re "<<(TCMRW\.*)>>"	{send_user "$expect_out(1,string)\n"} 
			}
		}
		
		-i $TCMAV 
 		# AVERAGE RECORD
 		-re "<<(TCMAV.*)>>" {
 			set timeout 10
 			set spawn_id $TCMAV
 			set avgstr $expect_out(1,string)
 			send_user "TCMAV  nrec yyyy MM dd hh mm ss az pitch sigpitch roll sigroll xmag ymag zmag tpni\n";
 			send_user "$avgstr\r\n"
 		}
 						
		#================== USER INPUT =========================================#
		-i $user_spawn_id  
			-re ".+" {
				set userstr $expect_out(0,string)
				send_user $userstr
				#=====================
				# QUIT & SEND SIGNOFF MESSAGE
				#====================
				if {[string match "*quit*" "<[string tolower $userstr]>"]} {
					write_info $infoname "USER QUIT\n";
					#sbdi "USER QUIT $expname" $SBD 2
					exit 0;
				}
				#=====================
				# WRITE A HEADER LINE
				#====================
				if {[string match "*h*" "<[string tolower $userstr]>"]} {
					send_user "PROGRAM $PROGRAMNAME, VERSION $VERSION, EDITDATE $EDITDATE\n";
					send_user "nrec yyyy MM dd hh mm ss az pitch sigpitch roll sigroll xmag ymag zmag tpni\n";
				}
				exp_continue
			}
	}
}

