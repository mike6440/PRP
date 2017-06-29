#!/usr/bin/expect --

#===================================================

set PROGRAMNAME Z_adc.ex
set VERSION 1
set EDITDATE 120707
# 
puts "
RUN PROGRAM $PROGRAMNAME, VERSION $VERSION, EDITDATE $EDITDATE"

set loguser 0;#   test 0-quiet, 1=verbose
log_user $loguser;

#===================================================================
#	PROCEDURE TO READ THE ADAM 4017
#  >+1.4068+0.2239+0.6372+0.5893+0.8412+0.7788+0.7216+0.6688
#==================================
proc GetAll4017 { spawnid cmd } {
	#send_user "Sending $cmd to spawnid $spawnid\n"
	set spawn_id $spawnid
	set timeout 1
	send "$cmd\r"
	expect {
		timeout { set reply4017 "0"; send_user "\n4017 timeout\n" }
		"+*" {
			set reply4017 $expect_out(0,string)
		}
	}
	return $reply4017
}



#===================================================================
#   PROCEDURE TO START AVG PROGRAM
#==================================
proc SpawnAvgAdc { setupfile infoname sutxt} {
	spawn perl avgadc.pl $sutxt;
	set AV $spawn_id;
	write_info $infoname "SPAWN AV spawn_id = $spawn_id"
	# WAIT FOR THE STARTUP PROMPT
	set timeout 1
	expect {
		# TIMEOUT (avg program) WITH NO REPLY
		timeout {
			send -i $AV "quit\r\n"
			send_user "AV STARTUP, Timeout with no reply\n"
			exit 1
		}
		# REPLY FROM AVG PROGRAM
		"ADC--" {
			send_user "AVGADC is ready\n"
		}
	}
	return $AV
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
	
# START PROCESS -- KERMIT FOR ISAR MODEM
spawn kermit
set PDS $spawn_id
set timeout 1
expect {
	timeout {"KERMIT FAILS TO OPEN\n"; exit 1}
	">>"
}

	send_user "OPEN PORT $portnumber\n";
	## OPEN THE PORT
	send "set host $hub_url $portnumber\r"
	expect ">>"
	send_user "set host $hub_url $portnumber\n";
	
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
		"Conn*---"  {send_user "PORT $portnumber CONNECTED\n"; return $spawn_id;}
		timeout {send_user "TIMEOUT, NO CONNECT"; exit 1}
	}
}

#==================== END PROCEDURES =============================================


#==============
# OS
# Define the operating system -- unamestr = "Darwin" or Linux
#=============
#set unamestr [exec uname]
#puts "system = $unamestr"

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

#============
# INITIALIZE THE INFO FILE
# We create a new info file each time we start the program.
#==============
## READ THE RT OUT PATH
spawn -noecho ./getsetupinfo.pl $setupfile "RT OUT PATH"
expect -re "(\.*)(\r)";
set datapath $expect_out(1,string)
send_user "DATAPATH = $datapath\n";

#=======================
#    ARM FOLDER DEFINED
#    datapath = /..../data/data_yyyyMMddThhmmssZ
#    cut at the second to the end "data"
#=======================
set i1 [string last "data" $datapath]
set str1 [string range $datapath 0 [expr $i1 - 1]]
set i1 [string last "data" $str1]
set str1 [string range $datapath 0 [expr $i1 - 1]]
append armpath $str1 "ARM"
send_user "armpath = $armpath\n"

# WRITE A HEADER TO INFO FILE
set tm [timestamp -gmt -format "%y%m%d%H%M%S"];
set infoname "$datapath/InfoADC.txt";
send_user "INFO FILE = $infoname\n";

set str  "PROGRAM $PROGRAMNAME, Version $VERSION, Editdate $EDITDATE, Runtime [timestamp -gmt -format "%Y%m%d,%H%M%S"]"
write_info $infoname "\n===== $str ============="

## =========================================
## READ THE SETUPFILE
## ========================================
log_user  $loguser;  ;#test 0-quiet, 1=verbose

write_info $infoname  "RT OUT PATH: $datapath"

## TIME WITH NO ADC
spawn -noecho ./getsetupinfo.pl $setupfile "ADC DEAD TIME ALARM"
expect -re "(\.*)(\r)";
write_info $infoname  "ADC DEAD TIME ALARM: $expect_out(1,string)"
set deadtime $expect_out(1,string);
puts "ADC DEAD TIME: $deadtime";

# PDS SERIAL HUB URL AND OFFSET
spawn -noecho ./getsetupinfo.pl $setupfile "SERIAL HUB URL"
expect -re "(\.*)(\r)";
set hub_url $expect_out(1,string)
write_info $infoname  "SERIAL HUB URL: $hub_url"

#=======================================
## DEFINE THE PORTS 
#=======================================
spawn -noecho ./getsetupinfo.pl $setupfile "ADC HUB COM NUMBER"
expect -re "(\.*)(\r)";
set adcport $expect_out(1,string)
write_info $infoname  "ADC HUB COM NUMBER: $adcport"
puts "ADC HUB PORT NUMBER = $adcport"

#=================
# WRITE TO RAW
#=================
set fname [timestamp -gmt -format "%y%m%d"]
set rawname "$datapath/adc_raw_$fname.txt";
puts "ADC RAW FILE NAME = $rawname";
write_info $infoname  "OPEN RAW FILE $rawname";

## ARM HOUR FILE NAME
set fnameh [timestamp -gmt -format "%y%m%d%H"]
set rawnameh "$armpath/adc_raw_$fnameh.txt";
puts "ADC HOUR RAW FILE NAME = $rawnameh";


log_user  $loguser;  ;#test 0-quiet, 1=verbose
#============================================================
# KERMIT/SIMULATE CONNECTION
#==================
if {$adcport == 0} {
	send_user "SIMULATE ADC: SPAWN simulate/zeno_simulator.pl\n"
	spawn perl simulate/adc_simulator.pl 
	set ADC	$spawn_id;
	write_info $infoname "ADC SIMULATE, id = $ADC"
} else {
	send_user "OPEN ADC PORT $hub_url $adcport \n";
	set ADC [spawn_kermit $hub_url $adcport];
	# OPEN PORT FAILS
	if { $ADC == 0 } {
		write_info $infoname "ADC KERMIT SPAWN FAILS ON START UP"
		exit 1
	} else {
		write_info $infoname "ADC KERMIT SPAWN SUCCESS, ID = $ADC"
	}
}


#==========================
# AVG PROGRAM
#================
set ADCAV [SpawnAvgAdc $setupfile $infoname $setupfile]

# =====================
# MAIN LOOP
# Wait for a string from isar
# Send the string to isar_avg program
#======================
write_info $infoname "===== BEGIN MAIN LOOP ====="
set timeadc [timestamp -gmt]
# COUNT THE NUMBER OF GOOD ISAR RECORDS RECEIVED
set Nrecs 0
set day0 0 ;# to initiate the first raw file
set hour0 "2000010100";# ARM HOURLY FILES

# EXPECT LOOP
while 1 {
	set dt [timestamp -gmt]
	
	#=====================
	# CHECK FOR A GAP IN ISAR RAW STRINGS
	#=====================
	if { [expr $dt - $timeadc] > $deadtime } {
		send_user "NO RAW ADC IN $deadtime SECS.\n"
		set timeadc $dt
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
		set rawname "$datapath/adc_raw_$fname.txt";
		if {[file exists $rawname]} {
			send_user "Appending to file $rawname\n"
		} else {
			set F [open $rawname w 0600]
			puts $F "nrec yyyy MM dd hh mm ss v0 v1 v2 v3 v4 v5 v6 v7"
			close $F
		}
		write_info $infoname "---NEW DAY---"
		write_info $infoname "rawname = $rawname"
	}
	
	## ARM HOUR FILE NAME
	set hour1 [timestamp -gmt -format "%y%m%d%H"]
	if { ![string match $hour1 $hour0] } {
		puts "NEW HOUR";
		set hour0 $hour1
		set rawnameh "$armpath/adc_raw_$hour1.txt";
		puts "ADC HOUR RAW FILE NAME = $rawnameh";
		if {[file exists $rawnameh]} {
			send_user "Appending to file $rawnameh\n"
		} else {
			set F [open $rawnameh w 0600]
			puts $F "nrec yyyy MM dd hh mm ss v0 v1 v2 v3 v4 v5 v6 v7"
			close $F
		}
	}
	
	#===================================
	# SAMPLING LOOP
	#===================================
	while 1 {
		set rply [GetAll4017 $ADC "\#01"]
		if { [string length $rply] >= 57 } {
			
			# ADD SPACE IN FRONT OF + OR -
			set str [string trim $rply]
			set str [string map { + " +" } $str]
			
			# INCREMENT Nrecs
			set Nrecs [expr $Nrecs + 1];
			set timeadc [timestamp -gmt];		#v1a time of the last good isar
			
			# SAVE TO RAW FILE
			set F [open $rawname a 0600]
			set rawstr $Nrecs[timestamp -gmt -format " %Y %m %d %H %M %S "]$str  ;
			puts $F $rawstr
			close $F

			# SAVE TO ARM HOUR RAW FILE
			set F [open $rawnameh a 0600]
			set rawstr $Nrecs[timestamp -gmt -format " %Y %m %d %H %M %S "]$str  ;
			puts $F $rawstr
			close $F

			# SEND ADCRAW TO AVG AND RCV RESPONSE
			set spawn_id $ADCAV
			send "ADC $str\r\n"
			expect { 
				-re "<<(\[^>]*)>>" { send_user ">>$expect_out(1,string)\n" }				
				}
			}
			
			# CHECK FOR AN AVG STRING
			set timeout 1
			#<<ADCAV 1 2012 07 08 06 29 00  17.3 17.3 019 0.7 -999.0   16.99 5.77 62.3 5.8 5.6 0.7>>
			expect {
				-re "ADCAV(.*)#\r" {
					set avgstr $expect_out(1,string);
					send_user "ADC AVG: navg yyyy MM dd hh mm ss ws vs vd stdws stdwd ta stdta rh stdrh rg tach\n";
					send_user "ADC AVG: $avgstr\n"
				}
			}
		}
		sleep 1
	}
	exit
}

