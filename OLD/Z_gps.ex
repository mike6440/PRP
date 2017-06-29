#!/usr/bin/expect --

set PROGRAMNAME Z_gps.ex
set VERSION v01
set EDITDATE 100821

puts "
RUN PROGRAM $PROGRAMNAME, VERSION $VERSION, EDITDATE $EDITDATE"

set loguser 0;#   test 0-quiet, 1=verbose
log_user $loguser;

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

#====================================================================
# PROCEDURE WRITE_RAW
# input
#  fileid = the file ID. e.g. tcm makes a file name tcmyyMMdd.raw
#  str=the string to write
#=============
proc write_raw {datapath fileid str} {
	# OPEN THE RAW FILE AS AN APPEND
	set tm [timestamp -format "%y%m%d"];
	set fname "$datapath/$fileid$tm.raw";
	set F [open $fname a]
	# TIME TAG THE STRING
	set tm [timestamp -format "%y%m%d,%H%M%S"]
	set str "$tm,$str";
	puts $F "$str" 
	close $F
	return $str  ;# return the time tagged string
}

#$GPRMC,020238.000,A,4736.1596,N,12217.3073,W,6.84,202.28,090809,,*1F

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


#===========================================
#HELP COMMAND OUTPUT
#===========================================
proc help {} {
	puts "PROGRAM GPS, GPS OPERATION AND AVG PROGRAM."
	puts "CALL: 
    ./GPS setup
where
setup is the set up file path/filename,
    example --  setup/test_setup.txt

Example call:
      \.\/GPS \"setup\/test\_setup.txt\"
";
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
# NO CMD LINE ARGS ==>> HELP
if { $argc == 0} {
	help;
	exit 0;
} else {
	# SETUP FILE DEFINED
	set setupfile [lindex $argv 0]
	
	## SEE IF THE SETUP FILE EXISTS
	if [catch {open $setupfile} sufile] {
		puts "Setup file open fails, exit 1"
		exit 1
	} else {
		puts "SETUP FILE $setupfile EXISTS"
	}
}

#============
# INITIALIZE THE INFO FILE
# We create a new info file each time we start the program.
#==============
## READ THE DATA OUTPUT PATH
spawn -noecho ./getsetupinfo.pl $setupfile "DATA OUTPUT PATH"
expect -re "(\.*)(\r)";
set datapath $expect_out(1,string)
# WRITE A HEADER TO INFO FILE
set tm [timestamp -format "%y%m%d%H%M%S"];
set infoname "$datapath/G$tm.info";
set str  "PROGRAM $PROGRAMNAME, Version $VERSION, Editdate $EDITDATE, Runtime [timestamp -format "%Y%m%d,%H%M%S"]"
write_info $infoname  $str 
write_info $infoname "\n========== BEGIN PROGRAM $PROGRAMNAME ============="

## =========================================
## READ THE SETUPFILE
## ========================================

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

## HEIGHT ABOVE SEA LEVEL
spawn -noecho ./getsetupinfo.pl $setupfile "HEIGHT ABOVE SEA LEVEL"
expect -re "(\.*)(\r)";
write_info $infoname  "HEIGHT ABOVE SEA LEVEL: $expect_out(1,string)"

## PRP2 SERIAL NUMBER
spawn -noecho ./getsetupinfo.pl $setupfile "PRP2 SERIAL NUMBER"
expect -re "(\.*)(\r)";
set prpsn $expect_out(1,string)
write_info $infoname  "PRP2 SERIAL NUMBER: $prpsn"

# PDS SERIAL HUB URL AND OFFSET
spawn -noecho ./getsetupinfo.pl $setupfile "SERIAL HUB URL"
expect -re "(\.*)(\r)";
set hub_url $expect_out(1,string)
write_info $infoname  "SERIAL HUB URL: $hub_url"

# PDS SERIAL HUB OFFSET
spawn -noecho ./getsetupinfo.pl $setupfile "SERIAL HUB OFFSET"
expect -re "(\.*)(\r)";
set hub_offset $expect_out(1,string)
write_info $infoname  "SERIAL HUB OFFSET: $hub_offset"

## GPS
spawn -noecho ./getsetupinfo.pl $setupfile "GPS HUB COM NUMBER"
expect -re "(\.*)(\r)";
set gpsport $expect_out(1,string)
write_info $infoname  "GPS HUB COM NUMBER: $gpsport"


#=================
# OPEN SET FILE NAMES AND NOTE TIME
#=================
# THIS JULIAN DAY
# day0 = START JULIAN DAY
set day0 [timestamp -format "%j"]
write_info $infoname "start year day: $day0";
# day1 = current day used to detect a new day at midnight
set day1 $day0

#============================================================
# GPS
# KERMIT/SIMULATE CONNECTION
# RUN AVGTCM.PL IF CONNECTED
#==================
# SIMULATE
if { $gpsport == -1 } {
	send_user "spawn perl simulate/gps_simulator.pl simulate/gps.txt\n";#		1 seconds output from TCM
	spawn perl simulate/gps_simulator.pl 5
	set GPS	$spawn_id;
	write_info $infoname "GPS SIMULATE INPUT"
# MISSING
} elseif { $gpsport == 0 } {
	set GPS -1
	set GPSAV -1
	write_info $infoname "SKIP GPS INPUT"
# OPEN TELNET CONNECTION AND BEGIN AVG PROGRAM
} else {
	send_user "\n=========== OPEN GPS PORT $hub_url $gpsport ==============\n";
	set GPS [spawn_kermit $hub_url $gpsport];
	# OPEN PORT FAILS
	if { $GPS == 0 } {
		write_info $infoname "GPS KERMIT SPAWN FAILS ON START UP"
		exit 1
	}
}


# $GPS is the spawn_id for the Kermit process 
############### BEGIN AVGRAD.PL
send_user "Launch average program. Setup = $setupfile\n";

spawn perl avggps.pl $setupfile;
set GPSAV $spawn_id;

write_info $infoname "SPAWN GPSAV spawn_id = $spawn_id"
# WAIT FOR THE STARTUP PROMPT
set timeout 5
expect {
	# TIMEOUT (avg program) WITH NO REPLY
	timeout {
		send -i $GPSAV "quit\r\n"
		send_user "AVGGPS STARTUP, Timeout with no reply\n"
		exit 1
	}
	# REPLY FROM AVG PROGRAM
	"GPS--" {
		send_user "AVGGPS is ready\n"
	}
}

write_info $infoname "===== BEGIN MAIN LOOP ====="
set timeout 15;

# === MAIN LOOP ==================
while 1 {
	set iraw 0
	set timeout 20
	expect { 
		timeout {send_user "main loop timed out at $timeout secs\n";}		;# we should rcv sometinh in 10 secs
		#==================== GPS SECTION ==================================#	
		-i $GPS
			-re "(\\\$GPRMC\.*)\r\n" {
				set gpsstr $expect_out(1,string);
				write_raw $datapath "gps" $gpsstr;	;# write the string to raw file
				send -i $GPSAV "$gpsstr\n"						;# send raw str to avgrsr.pl
			}
		-i $GPSAV
			eof						{write_info $infoname "avggps.pl has crashed\n";}
			"<<GPSRW*>>"			{send_user "==> $expect_out(0,string)\n"}
			-re "(GPSAV\.*)\r\n"	{send_user "*** $expect_out(1,string)\n"}
			
	}
}

#			set rawstr [string trimright $expect_out(0,string)];# a mess but it makes sense
#		-i $RSR  -re "(##\.*##)" {
#		-i $RSR  -"(##*##)" {
