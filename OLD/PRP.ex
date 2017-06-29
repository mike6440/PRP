#!/usr/bin/expect --

# CALLING
#    ./G "/Users/rmr/swmain/apps/prp2ex/setup/test_setup.txt" sx1xx
# where arg0 = setup file
# arg1 = nnnnn, for status of cdu,rad,tcm,gps,wxt
#   where n = 'x' => not included, skip
#   n = 's' => simulate the sensor
#   n = [1,2,3,4,5] => port for that instrument
#
#v02 -- add GPS
#v03 - Write for RAD coming into PDS-3.

#==========================================
#       ./G.ex "??"
#
#Data collection program for PRP2.
#Adapted from isarsbg/G08
#
# v03 runs only the RSR.

#===================================================

set PROGRAMNAME G
set VERSION v04
set EDITDATE 100301

puts "
RUN PROGRAM $PROGRAMNAME, VERSION $VERSION, EDITDATE $EDITDATE"

log_user 0  ;# 0-quiet, 1=verbose


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
	puts "PROGRAM G, PRP2 DATA COLLECTION AND INSTRUMENT OPERATION."
	puts "CALL: 
    ./G cmd0 cmd1 cmd2 ...
where
cmd0 is the set up file path/filename,
    example --  setup/test_setup.txt
cmd1 is five flags for the run configuration.
    flags are for <cdu><rad><tcm><gps><wxt> and are one of the following:
     'S' means simulate that input
     'X' means that input is missing
     '10001',--,'10005' specifies the multiport port number for the input sensor.

Example call:
      \.\/G \"setup\/test\_setup.txt\" 13s5x
means CDU-port 1, RAD-port 3, TCM-simulate, GPS-port 5, WXT-missing. 
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
log_user 0  ;# 0-quiet, 1=verbose

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

# HEAD SERIAL NUMBER
spawn -noecho ./getsetupinfo.pl $setupfile "HEAD SERIAL NUMBER"
expect -re "(\.*)(\r)";
set headsn $expect_out(1,string)
write_info $infoname  "HEAD SN: $headsn";

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

# LOW TEMPERATURE SHUTOFF
spawn -noecho ./getsetupinfo.pl $setupfile "LOW TEMPERATURE STANDBY"
expect -re "(\.*)(\r)";
set low_temp_standby $expect_out(1,string)
write_info $infoname  "LOW TEMPERATURE STANDBY: $low_temp_standby"


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

## RAD
spawn -noecho ./getsetupinfo.pl $setupfile "RAD HUB COM NUMBER"
expect -re "(\.*)(\r)";
set radport $expect_out(1,string)
write_info $infoname  "RAD HUB COM NUMBER: $radport"

## TCM
spawn -noecho ./getsetupinfo.pl $setupfile "TCM HUB COM NUMBER"
expect -re "(\.*)(\r)";
set tcmport $expect_out(1,string)
write_info $infoname  "TCM HUB COM NUMBER: $tcmport"

## GPS
spawn -noecho ./getsetupinfo.pl $setupfile "GPS HUB COM NUMBER"
expect -re "(\.*)(\r)";
set gpsport $expect_out(1,string)
write_info $infoname  "GPS HUB COM NUMBER: $gpsport"

## WXT
spawn -noecho ./getsetupinfo.pl $setupfile "WXT HUB COM NUMBER"
expect -re "(\.*)(\r)";
set wxtport $expect_out(1,string)
write_info $infoname  "WXT HUB COM NUMBER: $wxtport"

#=================
# OPEN SET FILE NAMES AND NOTE TIME
#=================
# THIS JULIAN DAY
# day0 = START JULIAN DAY
set day0 [timestamp -format "%j"]
write_info $infoname "start year day: $day0";
# day1 = current day used to detect a new day at midnight
set day1 $day0

log_user 0  ;# test 0-quiet, 1=verbose


#============================================================
# RSR
# KERMIT/SIMULATE CONNECTION
# RUN AVGRSR.PL IF CONNECTED
#==================
# SIMULATE
if [string match $rsrport 's'] {
	send_user "spawn perl simulate/rsr_simulator.pl 10\n";#		10 seconds output from RAD
	spawn perl simulate/rsr_simulator.pl 2
	set RSR	$spawn_id;
	write_info $infoname "RSR SIMULATE INPUT"
# MISSING
} elseif { $rsrport == 0 } {
	set RSR -1
	set RSRAV -1
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
# $RSR is the spawn_id for the Kermit process 
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
#============================================================
# RAD
# KERMIT/SIMULATE CONNECTION
# RUN AVGRAD.PL IF CONNECTED
#==================
# SIMULATE
if [string match $radport 's'] {
	send_user "spawn perl simulate/rad_simulator.pl 15\n";#		15 seconds output from RAD
	spawn perl simulate/rad_simulator.pl 15
	set RAD	$spawn_id;
	write_info $infoname "RAD SIMULATE INPUT"
# MISSING
} elseif {$radport == 0 } {
	set RAD -1
	set RADAV -1
	write_info $infoname "SKIP RAD INPUT"
# OPEN TELNET CONNECTION AND BEGIN AVG PROGRAM
} else {
	send_user "\n=========== OPEN RAD PORT $hub_url $radport ==============\n";
	set RAD [spawn_kermit $hub_url $radport];
	# OPEN PORT FAILS
	if { $RAD == 0 } {
		write_info $infoname "RAD KERMIT SPAWN FAILS ON START UP"
		exit 1
	}
}
# $RSR is the spawn_id for the Kermit process 
############### BEGIN AVGRAD.PL
spawn perl avgrad.pl $setupfile;
set RADAV $spawn_id;

write_info $infoname "SPAWN RADAV spawn_id = $spawn_id"
# WAIT FOR THE STARTUP PROMPT
set timeout 5
expect {
	# TIMEOUT (avg program) WITH NO REPLY
	timeout {
		send -i $RADAV "quit\r\n"
		send_user "RADAV STARTUP, Timeout with no reply\n"
		exit 1
	}
	# REPLY FROM AVG PROGRAM
	"RAD--" {
		send_user "AVGRAD is ready\n"
	}
}

#============================================================
# TCM
# KERMIT/SIMULATE CONNECTION
# RUN AVGTCM.PL IF CONNECTED
#==================
# SIMULATE
if [string match $tcmport 's'] {
	send_user "spawn perl simulate/tcm_simulator.pl 1\n";#		1 seconds output from TCM
	spawn perl simulate/tcm_simulator.pl 15
	set TCM	$spawn_id;
	write_info $infoname "TCM SIMULATE INPUT"
# MISSING
} elseif { $tcmport == 0 } {
	set TCM -1
	set TCMAV -1
	write_info $infoname "SKIP TCM INPUT"
# OPEN TELNET CONNECTION AND BEGIN AVG PROGRAM
} else {
	send_user "\n=========== OPEN TCM PORT $hub_url $tcmport ==============\n";
	set TCM [spawn_kermit $hub_url $tcmport];
	# OPEN PORT FAILS
	if { $TCM == 0 } {
		write_info $infoname "TCM KERMIT SPAWN FAILS ON START UP"
		exit 1
	}
}
# $TCM is the spawn_id for the Kermit process 
############### BEGIN AVGRAD.PL
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

#============================================================
# GPS
# KERMIT/SIMULATE CONNECTION
# RUN AVGTCM.PL IF CONNECTED
#==================
# SIMULATE
if {[string match $gpsport 's']} {
	send_user "spawn perl simulate/gps_simulator.pl 5\n";#		1 seconds output from TCM
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
	send_user "\n=========== OPEN GPS PORT $hub_url $tcmport ==============\n";
	set GPS [spawn_kermit $hub_url $gpsport];
	# OPEN PORT FAILS
	if { $GPS == 0 } {
		write_info $infoname "GPS KERMIT SPAWN FAILS ON START UP"
		exit 1
	}
}
# $GPS is the spawn_id for the Kermit process 
############### BEGIN AVGRAD.PL
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


set force_rsr_standby  0;# start in operation mode
set ktemp 1;# start with temp standby flag in operate mode.

log_user 0 ;# 0-quiet, 1=verbose  #test

write_info $infoname "===== BEGIN MAIN LOOP ====="
set timeout 5;

# === MAIN LOOP ==================
while 1 {
	set iraw 0
	set timeout 20
	expect { 
		timeout {send_user "main loop timed out at $timeout secs\n";}		;# we should rcv sometinh in 10 secs
		#==================== RAD SECTION ==================================#	
		-i $RAD
			-re "(\\\$WI\.*)\r\n" {
				set radstr $expect_out(1,string)
				write_raw $datapath "rad" $radstr;
				send_user "==> $radstr\n"
				send -i $RADAV "$radstr\n"
			}
		-i $RADAV
			eof					 {send_user "avgrad.pl has crashed\n";}
			;# The program avgrad.pl send a message when it has an average
			-re "(RADAV\.*)\r\n" {
				;# when the avg message is received we sent it to terminal
				set avstr $expect_out(1,string)
				send_user "*** $avstr\n"
				;# now check the last field for a command to turn the rsr on or off
				;# split the string into fields
				set avlist [split $avstr " "]
				;# take the last field and trim whitespace
				set radswitch [string trim [lindex $avlist end]]
				send_user "rad-rsrswitch = $radswitch\n";
				if {$force_rsr_standby == 1} {
					set radswitch -1; 
					send_user "RSR in standby\n"
				}
				;# take action based on the value
				;# 0 = do nothing, -1 = turn RSR off, 1 = turn RSR on
				switch -- $radswitch {
					"1" {send_user "RAD turn RSR on\n"; send -i $RSR "H" }
					"0" {send_user "RAD turn RSR off\n"; send -i $RSR "L"}
					default {}
				}
			}
			
		#==================== RSR SECTION ==================================#	
		-i $RSR  
			"##*##" {
				set rawstr $expect_out(0,string);
				set str [write_raw $datapath "rsr" $rawstr];	;# write the string to raw file
				send -i $RSRAV "$rawstr\n"						;# send raw str to avgrsr.pl
			}
		-i $RSRAV
			eof					{send_user "avgrsr.pl has crashed\n";}
			"<<RSR*>>"			{send_user "==> $expect_out(0,string)\n"}
			-re "<<(RSAV\.*)>>"		{
				;# when the avg message is received we sent it to terminal
				set avstr [string trim $expect_out(1,string)]
				send_user "*** $avstr\n"
				;# now check the last field for a command to turn the rsr on or off
				;# split the string into fields
				set avlist [split $avstr " "]
				;# take the last field and trim whitespace
				set rsrswitch [string trim [lindex $avlist end]]
				send_user "rsr-rsrswitch = $rsrswitch\n";
				if {$force_rsr_standby == 1} {
					set rsrswitch -1; 
					send_user "RSR in standby\n"
				}
				;# take action based on the value
				;# -1 = go to low, 0 = do nothing, 1 = turn RSR to high
				switch -- $rsrswitch {
					"1" { 
						if {$ktemp != 0} {
							send_user "RSR turn RSR on\n"; send -i $RSR "H"
						}
					}
					"0" {send_user "RSR turn RSR off\n"; send -i $RSR "L"}
					default {}
				}
			}
		#==================== TCM SECTION ==================================#	
		-i $TCM  
			-re "(\\\$C\.*)\r\n" {
				set tcmstr $expect_out(1,string);
				write_raw $datapath "tcm" $tcmstr;	;# write the string to raw file
				send -i $TCMAV "$tcmstr\n"						;# send raw str to avgrsr.pl
			}
		-i $TCMAV
			eof						{write_info $infoname "avgtcm.pl has crashed\n";}
			"<<TCMRW*>>"			{send_user "==> $expect_out(0,string)\n"}
			-re "(TCMAV\.*)\r\n"	{
				;# when the avg message is received we sent it to terminal
				set avstr [string trim $expect_out(1,string)]
				send_user "*** $avstr\n"
				# Choose the 13 element from the string.
				set temptcm [exec ./misc/parse_tcm.pl $avstr 13]
				# if temperature is non-missing then process the flag.
				# note hysterisis of 5 deg.
				send_user "temperature = $temptcm\n";
				if {$temptcm > -100} {
					if {$temptcm < $low_temp_standby} {
						set ktemp 0
						send_user "LOW TEMPERATURE -- STANDBY MODE\n";
						send -i $RSR "L"
					}
					if {$temptcm > [expr $low_temp_standby +5] && $ktemp == 0} {
						set ktemp 1
						send_user "TEMP GT THRESHOLD: SWITCH FROM STANDBY TO OPERATE\n";
					}
				}
			}
			
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
}

#			set rawstr [string trimright $expect_out(0,string)];# a mess but it makes sense
#		-i $RSR  -re "(##\.*##)" {
#		-i $RSR  -"(##*##)" {
