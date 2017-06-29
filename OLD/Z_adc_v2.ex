#!/usr/bin/expect --

#===================================================
set PROGRAMNAME Z_adc.ex
set VERSION 2
set EDITDATE 121011
# 
puts "
RUN PROGRAM $PROGRAMNAME, VERSION $VERSION, EDITDATE $EDITDATE"

set loguser 0;#   test 0-quiet, 1=verbose
log_user $loguser;

#===================================================================
#   PROCEDURE TO START AVG PROGRAM
#==================================
proc SpawnAvgAdc { setupfile infoname sutxt} {
	spawn perl avgadc.pl $sutxt;
	set AV $spawn_id;
	write_info $infoname "SPAWN AV spawn_id = $spawn_id"
	# WAIT FOR THE STARTUP PROMPT
	set timeout 2
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
		# READ THE ISAR-RT OUT PATH
spawn -noecho ./getsetupinfo.pl $setupfile "RT OUT PATH"
expect -re "(\.*)(\r)";
set datapath $expect_out(1,string)
send_user "DATAPATH = $datapath\n";
		# ARMPATH
set i1 [string last "data" $datapath]
set str1 [string range $datapath 0 [expr $i1 - 1]]
set i1 [string last "data" $str1]
set str1 [string range $datapath 0 [expr $i1 - 1]]
append armpath $str1 "ARM"
send_user "ARMPATH = $armpath\n"
		# WRITE A HEADER TO INFO FILE
set tm [timestamp -gmt -format "%y%m%d%H%M%S"];
set infoname "$datapath/adc_info.txt";
send_user "INFO FILE = $infoname\n";
		# START UP BANNER
set str  "PROGRAM $PROGRAMNAME, Version $VERSION, Editdate $EDITDATE, Runtime [timestamp -gmt -format "%Y%m%d,%H%M%S"]"
write_info $infoname "\n===== $str ============="
		# READ THE SETUPFILE
log_user  $loguser;  ;#test 0-quiet, 1=verbose
		# DATA INFORMATION
write_info $infoname  "RT OUT PATH: $datapath"
		# 0 +1.4068 ws  16.9  m/s
		# 1 +0.2239 wd  16.1  deg
		# 2 +0.6365 ta  13.65 C
		# 3 +0.5895 rh  59 %
		# 4 +0.8417 spare
		# 5 +0.7794 spare
		# 6 +0.7221 rg  7.2 mm
		# 7 +0.6691 tach .6691 v
write_info $infoname "ADC Chan 0 - spn total"
write_info $infoname "ADC Chan 1 - spn diffuse"
write_info $infoname "ADC Chan 2 - spare"
write_info $infoname "ADC Chan 3 - spare"
write_info $infoname "ADC Chan 4 - spare"
write_info $infoname "ADC Chan 5 - spare"
write_info $infoname "ADC Chan 6 - spare"
write_info $infoname "ADC Chan 7 - spare"
		# DEAD TIME WITH NO RESPONSE
spawn -noecho ./getsetupinfo.pl $setupfile "ADC DEAD TIME ALARM"
expect -re "(\.*)(\r)";
write_info $infoname  "ADC DEAD TIME ALARM: $expect_out(1,string)"
set deadtime $expect_out(1,string);
puts "ADC DEAD TIME: $deadtime";
		## 	DEFINE THE 4017 (485 NTWK) COMMAND
spawn -noecho ./getsetupinfo.pl $setupfile "ADAM 4017 COMMAND"
expect -re "(\.*)(\r)";
set adccmd $expect_out(1,string)
write_info $infoname  "ADAM 4017 COMMAND: $adccmd"
puts "ADAM 4017 COMMAND = $adccmd"
		# PDS SERIAL HUB URL AND OFFSET
spawn -noecho ./getsetupinfo.pl $setupfile "SERIAL HUB URL"
expect -re "(\.*)(\r)";
set hub_url $expect_out(1,string)
#set hub_url env(HUBIP);
write_info $infoname  "SERIAL HUB URL: $hub_url"
		# DEFINE THE PORTS 
spawn -noecho ./getsetupinfo.pl $setupfile "ADC HUB COM NUMBER"
expect -re "(\.*)(\r)";
set adcport $expect_out(1,string)
write_info $infoname  "ADC HUB COM NUMBER: $adcport"
puts "ADC HUB PORT NUMBER = $adcport"
		# SPAWN GET_ADC -- free running
send_user "OPEN GET_ADC\n";
set cmd "expect get_adc.ex [exec cat tmp]";
send_user "cmd = $cmd\n";
set ADC [spawn expect get_adc.ex [exec cat tmp]];
	# OPEN PORT FAILS
if { $ADC == 0 } {
	send_user "GET_ADC SPAWN FAILS ON START UP\n"
	exit 1
} else {
	send_user "GET_ADC SPAWN SUCCESS, ID = $ADC\n"
}
		# AVG PROGRAM
set ADCAV [SpawnAvgAdc $setupfile $infoname $setupfile]
send_user "ADCAV = $ADCAV\n"
		# MAIN LOOP
write_info $infoname "===== BEGIN MAIN LOOP ====="
set timeadc [timestamp -gmt]
		# INITIAL VARIABLES
set Nrecs 0
set day0 0 ;# to initiate the first raw file
set hour0 "2000010100";# ARM HOURLY FILES
set looptime [timestamp -gmt]
		# EXPECT LOOP
set timeout 1
while 1 {
			# LOOP TIME
	set dt [timestamp -gmt]
			# CHECK FOR A GAP IN ISAR RAW STRINGS
	if { [expr $dt - $timeadc] > $deadtime } {
		send_user "NO RAW ADC IN $deadtime SECS.\n"
		set timeadc $dt
		set dt0 $dt
	}
			# CHECK FOR A NEW DAY -- NEW FILES
	set day1 [timestamp -gmt -format "%j"]
	if {$day1 != $day0} {
		send_user "DAY CHANGE\r\n"
		set day0 $day1
		set fname [timestamp -gmt -format "%y%m%d"]
		set rawname "$datapath/adc_raw_$fname.txt";
		if {[file exists $rawname]} {
			#send_user "Appending to file $rawname\n"
		} else {
			set F [open $rawname w 0600]
			puts $F "nrec yyyy MM dd hh mm ss v0 v1 v2 v3 v4 v5 v6 v7"
			close $F
		}
		puts  "---NEW DAY---"
		write_info $infoname "rawname = $rawname"
	}
			# ARM HOUR FILE NAME
	set hour1 [timestamp -gmt -format "%y%m%d%H"]
	if { ![string match $hour1 $hour0] } {
		set hour0 $hour1
		set rawnameh "$armpath/adc_raw_$hour1.txt";
		#puts "ADC HOUR RAW FILE NAME = $rawnameh";
		if {[file exists $rawnameh]} {
			#send_user "Appending to file $rawnameh\n"
		} else {
			set F [open $rawnameh w 0600]
			puts $F "nrec yyyy MM dd hh mm ss v0 v1 v2 v3 v4 v5 v6 v7"
			close $F
		}
	}
	#===================================
	# SAMPLING LOOP
	#===================================
	expect {
				# GET ADC PACKET
		-re "(ADCRAW .*)\n\r" { 
			set rply [string trim $expect_out(1,string)]
					# FULL STRING LENGTH
					# INCREMENT Nrecs
			set Nrecs [expr $Nrecs + 1];
			set timenav [timestamp -gmt];		#v1a time of the last good nav			
					# 	SAVE TO RAW FILE
			set F [open $rawname a 0600]
			set rawstr $Nrecs[timestamp -gmt -format " %Y %m %d %H %M %S "]$rply  ;
			puts $F $rawstr
			close $F		
				# SAVE TO ARM HOUR RAW FILE
			set F [open $rawnameh a 0600]
			#set rawstr $Nrecs[timestamp -gmt -format " %Y %m %d %H %M %S "]$rply  ;
			puts $F $rawstr
			close $F
			send -i $ADCAV "$rply\r\n"
			expect -i $ADCAV -re "<<(ADCRW .*)>>" { send_user "$expect_out(1,string)\n" }	}
			-i $ADCAV -re "<<(ADCAV .*)>>" { send_user "***$expect_out(1,string)\n" }	}
		}
	}
}

