#!/usr/bin/expect --
# CALLING
#       ./Z_rsr.ex setupfile  simflag
# e.g.  ./Z_rsr.ex `cat tmp` sx1xx

# where 
#  setupfile is defined in tmp at the START command.

set PROGRAMNAME Z_rsr.ex
set VERSION v1
set EDITDATE 120808

log_user 0  ;# 0-quiet, 1=verbose



#===============================================================
# PROCEDURE TCM_TEMPERATURE
#   READ THE TCM TEMPERATURE
# inout
#   missing = missing value number (-999)
# output
#   tcm temperature or missing
#==============
proc tcm_temperature {missing} {
	spawn -noecho ./LastData.pl tcm_raw
	expect -re "(\.*)(\r)";
	set str $expect_out(1,string)
	#send_user "STR = $str\n"
	set rec [exec tail -1 $str]
	set rec [string trim $rec]
	#send_user "RECORD = $rec\n"
	set reclist [split $rec " "]
	set timestr [format "%s/%s/%s %s:%s:%s" \
		[string trim [lindex $reclist 2]] \
		[string trim [lindex $reclist 3]] \
		[string trim [lindex $reclist 1]] \
		[string trim [lindex $reclist 4]] \
		[string trim [lindex $reclist 5]] \
		[string trim [lindex $reclist 6]] ]
	set dtlasttcm [clock scan $timestr];
	#send_user "DTLASTTCM = $dtlasttcm\n"
	
	set dtnow [clock seconds]
	#send_user "LOCAL DTNOW = $dtnow\n"
	
	set str [clock format $dtnow -gmt 1 -format "%m/%d/%Y %H:%M:%S"]
	set dtnow [clock scan $str]
	#send_user "NOW TIME IS $str\n"
	#send_user "GMT DTNOW = $dtnow\n"
	
	if { [expr $dtnow - $dtlasttcm] < 600 } {
		set Ttcm [string trim [lindex $reclist end]]
		#send_user "TCM TEMPERATURE = $Ttcm\n"
	} else {
		set Ttcm $missing
		#send_user "TCM TEMP IS MISSING\n"
	}
	return $Ttcm;
}





#====================================================================
# PROCEDURE WRITE_INFO
# input
#  fname = fullfile name towrite the info string
#  str=the string to write
#=============
proc write_info {fname str} {
	set tm [timestamp -format "%y%m%d,%H%M%S"]
	set str "$tm,$str";
	send_user "$str\n"
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
	# START PROCESS -- KERMIT FOR TCM
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
# READ THE COMMAND LINE
# COMMANDS
# 1. SETUP FILE PATH AND NAME, /setup/test_setup.txt
# 2. SIMULATE- dddd where eac d=0/1
#      order of d's is [cdu][rad][tcm][gps][wxt] "crcgw"
#==============
set argc [llength $argv]
for {set i 0} {$i<$argc} {incr i} {
	send_user "$PROGRAMNAME arg $i: [lindex $argv $i]\n"
}

# SETUP FILE DEFINED
set setupfile [lindex $argv 0]

## SEE IF THE SETUP FILE EXISTS
if [catch {open $setupfile} sufile] {
	puts "Setup file open fails, exit 1"
	exit 1
} else {
	puts "SETUP FILE $setupfile,   EXISTS"
}

## READ THE DATA OUTPUT PATH
spawn -noecho ./getsetupinfo.pl $setupfile "DATA OUTPUT PATH"
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
set infoname "$datapath/rsr_info.txt";
puts "RAD INFORMATION FILE: $infoname\n"
set str  "PROGRAM $PROGRAMNAME, Version $VERSION, Editdate $EDITDATE, Runtime [timestamp -format "%Y%m%d,%H%M%S"]"
write_info $infoname  $str 
write_info $infoname "\n========== BEGIN PROGRAM $PROGRAMNAME ============="


## =========================================
## READ THE SETUPFILE
## ========================================
write_info $infoname  "DATA OUTPUT PATH: $datapath"

# PDS SERIAL HUB OFFSET
spawn -noecho ./getsetupinfo.pl $setupfile "SERIAL HUB OFFSET"
expect -re "(\.*)(\r)";
set hub_offset $expect_out(1,string)
write_info $infoname  "SERIAL HUB OFFSET: $hub_offset"

#=======================================
## DEFINE THE PORTS 
# rsrport, radport, tcmport, gpsport, wxtport = 's'/'x'/[1-5]
#Multiport solution
#=======================================
## CDU
spawn -noecho ./getsetupinfo.pl $setupfile "RSR HUB COM NUMBER"
expect -re "(\.*)(\r)";
set rsrport $expect_out(1,string)
write_info $infoname  "RSR HUB COM NUMBER: $rsrport"

# PDS SERIAL HUB URL AND OFFSET
spawn -noecho ./getsetupinfo.pl $setupfile "SERIAL HUB URL"
expect -re "(\.*)(\r)";
set hub_url $expect_out(1,string)
write_info $infoname  "SERIAL HUB URL: $hub_url"

## TIME WITH NO DATA
spawn -noecho ./getsetupinfo.pl $setupfile "RSR DEAD TIME ALARM"
expect -re "(\.*)(\r)";
write_info $infoname  "RSR DEAD TIME ALARM: $expect_out(1,string)"
set rsrdeadtime $expect_out(1,string);
puts "RSR DEAD TIME: $rsrdeadtime";

# AVERAGING TIME
spawn -noecho ./getsetupinfo.pl $setupfile "RSR AVERAGING TIME"
expect -re "(\.*)(\r)";
write_info $infoname  "RSR AVERAGING TIME: $expect_out(1,string)"


# LOW TEMPERATURE STANDBY
spawn -noecho ./getsetupinfo.pl $setupfile "LOW TEMPERATURE STANDBY"
expect -re "(\.*)(\r)";
set LowTempShutdown $expect_out(1,string)
send_user "LOW TEMPERATURE STANDBY = $LowTempShutdown\n"
write_info $infoname  "LOW TEMPERATURE STANDBY: $LowTempShutdown"

set rsr_temperature_standby 0


# MISSING
spawn -noecho ./getsetupinfo.pl $setupfile "MISSING VALUE"
expect -re "(\.*)(\r)";
set missing $expect_out(1,string)
send_user "MISSING VALUE = $missing\n"
write_info $infoname  "MISSING VALUE: $missing"



# KERMIT/SIMULATE CONNECTION
# SIMULATE
if { $rsrport == -1 } {
	send_user "spawn perl simulate/rsr_simulator.pl 10\n";#		10 seconds output from RAD
	spawn perl simulate/rsr_simulator.pl 2
	set RSR	$spawn_id;
	write_info $infoname "RSR SIMULATE INPUT"
# MISSING
} elseif { $rsrport == 0 } {
	set RSR -1
	write_info $infoname "SKIP RSR INPUT"
# OPEN TELNET CONNECTION AND BEGIN AVG PROGRAM
} else {
	send_user "\n====== OPEN RSR PORT $hub_url $rsrport ===============\n";
	set RSR [spawn_kermit $hub_url $rsrport];
	# OPEN PORT FAILS
	if { $RSR == 0 } {
		write_info $infoname "RSR KERMIT SPAWN FAILS ON START UP"
		exit 1
	}
}


# AVG PROGRAM 
############### BEGIN AVGRSR.PL
spawn perl avgrsr.pl $setupfile;
set RSRAV $spawn_id;

write_info $infoname "SPAWN RSRAV spawn_id = $spawn_id"
# WAIT FOR THE STARTUP PROMPT
set timeout 5
expect {
	# TIMEOUT (avg program) WITH NO REPLY
	timeout {
		send -i $RSRAV "quit\r\n"
		send_user "RSRAV STARTUP, Timeout with no reply\n"
		exit 1
	}
	# REPLY FROM AVG PROGRAM
	"RSR--" {
		send_user "AVGRSR is ready\n"
	}
}


set force_rsr_standby  0;# start in operation mode
set ktemp 1;# start with temp standby flag in operate mode.
set rsrcmd 1;
set rsrmode 1;

# =====================
# MAIN LOOP
#======================
set timersr [timestamp -gmt]
# COUNT THE NUMBER OF GOOD RAW RECORDS RECEIVED
set day0 0 ;# to initiate the first raw file
set hour0 "2000010100";# ARM HOURLY FILES

set Nrecsrsr 0
set Nrecs 0



# EXPECT LOOP
while 1 {
		set dt [timestamp -gmt]

	#=====================
	# CHECK FOR A GAP IN RAW STRINGS
	#=====================
	if { [expr $dt - $timersr] > $rsrdeadtime } {
		send_user "NO RAW RSR IN $rsrdeadtime SECS.\n"
		set timersr $dt
	}
	
	#======
	# CHECK FOR A NEW DAY -- NEW FILES
	# FOR RSR SKIP HEADERS, TOO COMPLICATED
	#======
	set day1 [timestamp -gmt -format "%j"]
	if {$day1 != $day0} {
		send_user "DAY CHANGE\r\n"
		set day0 $day1
		# NEW RAW FILE
		set fname [timestamp -gmt -format "%y%m%d"]
		set rawname "$datapath/rsr_raw_$fname.txt";
	}
	## ARM HOUR FILE NAME 
	set hour1 [timestamp -gmt -format "%y%m%d%H"]
	if { ![string match $hour1 $hour0] } {
		puts "NEW HOUR";
		set hour0 $hour1
		# ARM RAW FILE
		set rawnameh "$armpath/rsr_raw_$hour1.txt";
		puts "ARM HOUR RAW FILE NAME = $rawnameh";
	}

	#===================================
	# SAMPLING LOOP
	#===================================
	set timeout 10
	expect { 
		-i $RSR  
		#==========
		# RECEIVE RAW FRSR STRING
		#===========
		"##*##" {

			set rawstr $expect_out(0,string);
			
			# SAVE TO RAW FILE
			set F [open $rawname a 0600]
			set strx [timestamp -gmt -format "$Nrecs %Y %m %d %H %M %S "]$rawstr
			puts $F $strx
			close $F
			
			# SAVE TO ARM HOUR RAW FILE
			set F [open $rawnameh a 0600]
			puts $F $strx
			close $F
			send_user "$strx\n"
			
			# SEND RAW TO AVG AND RCV RESPONSE
			set spawn_id $RSRAV
			send "$rawstr\r\n"
			expect {
				-re "<<(RSR\.*)>>"	{send_user "$expect_out(1,string)\n"} 
			}
			set Nrecs [expr $Nrecs + 1];
		}
		#===============
		# GET A HIGH OR LOW MODE FROM FRSR
		#===============
		"Switch to ON mode." {
			send_user "RECEIVED ON MODE MESSAGE\n"
			set rsrmode 1
		}
		"Switch to LOW mode." {
			send_user "RECEIVED LOW MODE MESSAGE\n"
			set rsrmode 0
		}
		
		-i $RSRAV
		eof					{send_user "avgrsr.pl has crashed\n";}
		"<<RSR*>>"			{send_user "==> $expect_out(0,string)\n"}
		-re "<<(RSAV\.*)>>"		{
			set avstr [string trim $expect_out(1,string)]
			send_user "*** $avstr\n"
			# now check the last field for a command to turn the rsr on or off
			#    0 = low,   1 = high, -1 do nothing
			set avlist [split $avstr " "]
			set rsrcmd [string trim [lindex $avlist end]]
			
			# LOW TEMPERATURE SHUTDOWN
			set x [tcm_temperature $missing]
			send_user "TCM TEMPERATURE = $x\n"
			if { $x > -100 } {
				if { $x <= $LowTempShutdown } {
					set rsr_temperature_standby 1
					send_user "LOW TEMPERATURE, GO TO STANDBY\n"
				}
				else { set rsr_temperature_standby 0 }
			} else {
				set rsr_temperature_standby 1
			}
		}
		
		#================== USER INPUT =========================================#
		-i $user_spawn_id  
		-re ".+" {
			set userstr $expect_out(0,string)
			send_user $userstr
			# L or l stops RSR.
			if {[string match "*l*" "<[string tolower $userstr]>"]} {
				write_info $infoname "USER turn RSR STANDBY\n";
				send -i $RSR "L"
				set force_rsr_standby 1;
			}
			# H or h starts RSR into operation mode.
			if {[string match "*h*" "<[string tolower $userstr]>"]} {
				if { $ktemp == 0 } {
					send_user "LOW TEMP STANDBY BLOCKS H COMMAND\n";
				} else {
					write_info $infoname "USER turn RSR ON\n";
					send -i $RSR "H"
					set force_rsr_standby 0;
				}
			}
			exp_continue
		}
	}
	#=======================
	# FRSR MODE 
	#=======================
	
	if { ($force_rsr_standby == 1 || $rsr_temperature_standby == 1) && $rsrmode } {
		send_user "SEND RSR LOW COMMAND\n"
		send -i $RSR "L"
	}
	if { $force_rsr_standby == 0 && $rsr_temperature_standby == 0} {
		if { ! $rsrmode && $rsrcmd } {
			send_user "SEND RSR H COMMAND\n"
			send -i $RSR "H"
		} 
		if { $rsrmode && ! $rsrcmd } {
			send_user "SEND RSR L COMMAND\n"
			send -i $RSR "L"
		}
	}
}

#			set rawstr [string trimright $expect_out(0,string)];# a mess but it makes sense
#		-i $RSR  -re "(##\.*##)" {
#		-i $RSR  -"(##*##)" {
