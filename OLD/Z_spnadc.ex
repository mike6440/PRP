#!/usr/bin/expect --

set PROGRAMNAME Z_spn.ex
set VERSION 1
set EDITDATE 120721

puts "
RUN PROGRAM $PROGRAMNAME, VERSION $VERSION, EDITDATE $EDITDATE"

set loguser 1;#   test 0-quiet, 1=verbose
log_user $loguser;

#===================================================================
#   PROCEDURE TO START AVG ADC PROGRAM
#==================================
proc SpawnAvgAdc { setupfile infoname sutxt} {
	spawn perl avgadc.pl $sutxt;
	set AV $spawn_id;
	write_info $infoname "SPAWN ADC AV spawn_id = $spawn_id"
	# WAIT FOR THE STARTUP PROMPT
	set timeout 2
	expect {
		# TIMEOUT (avg program) WITH NO REPLY
		timeout {
			send -i $AV "quit\r\n"
			send_user "ADC AV STARTUP, Timeout with no reply\n"
			exit 1
		}
		# REPLY FROM AVG PROGRAM
		"ADC--" {
			send_user "AVGADC is ready\n"
		}
	}
	return $AV
}

#===================================================================
#   PROCEDURE TO START AVG SPN PROGRAM
#==================================
proc SpawnAvgSpn { setupfile infoname sutxt} {
	spawn perl avgspn.pl $sutxt;
	set AV $spawn_id;
	write_info $infoname "SPAWN SPN AV spawn_id = $spawn_id"
	# WAIT FOR THE STARTUP PROMPT
	set timeout 2
	expect {
		# TIMEOUT (avg program) WITH NO REPLY
		timeout {
			send -i $AV "quit\r\n"
			send_user "SPN AV STARTUP, Timeout with no reply\n"
			exit 1
		}
		# REPLY FROM AVG PROGRAM
		"SPN--" {
			send_user "AVGSPN is ready\n"
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

		# MAIN
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
		# ARMPATH
append armpath $env(DAQFOLDER) "/ARM"
send_user "ARMPATH = $armpath\n"
		# WRITE A HEADER TO INFO FILE
set tm [timestamp -gmt -format "%y%m%d%H%M%S"];
set infoname "$datapath/spn_info.txt";
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
		# DEAD TIME WITH NO ADC
spawn -noecho ./getsetupinfo.pl $setupfile "ADC DEAD TIME ALARM"
expect -re "(\.*)(\r)";
write_info $infoname  "ADC DEAD TIME ALARM: $expect_out(1,string)"
set adcdeadtime $expect_out(1,string);
puts "ADC DEAD TIME: $adcdeadtime";
		# SPAWN GET_ADC -- free running
send_user "OPEN GET_ADC\n";
set cmd "expect get_adc.ex [exec cat tmp]";
send_user "cmd = $cmd\n";
set ADC [spawn expect get_adc.ex [exec cat tmp]];
	# OPEN ADC PORT FAILS
if { $ADC == 0 } {
	send_user "GET_ADC SPAWN FAILS ON START UP\n"
	exit 1
} else {
	send_user "GET_ADC SPAWN SUCCESS, ID = $ADC\n"
}
		# ADC AVG PROGRAM
set ADCAV [SpawnAvgAdc $setupfile $infoname $setupfile]
send_user "ADCAV = $ADCAV\n"
		# SPN
		# DEAD TIME WITH NO SPN
spawn -noecho ./getsetupinfo.pl $setupfile "SPN DEAD TIME ALARM"
expect -re "(\.*)(\r)";
write_info $infoname  "SPN DEAD TIME ALARM: $expect_out(1,string)"
set spndeadtime $expect_out(1,string);
puts "SPN DEAD TIME: $spndeadtime";
		# SPAWN GET_SPN -- free running
send_user "OPEN GET_SPN\n";
set cmd "expect get_spn.ex [exec cat tmp]";
send_user "cmd = $cmd\n";
set SPN [spawn expect get_spn.ex [exec cat tmp]];
	# OPEN ADC PORT FAILS
if { $SPN == 0 } {
	send_user "GET_SPN SPAWN FAILS ON START UP\n"
	exit 1
} else {
	send_user "GET_SPN SPAWN SUCCESS, ID = $SPN\n"
}
		# SPN AVG PROGRAM
set SPNAV [SpawnAvgSpn $setupfile $infoname $setupfile]
send_user "SPNAV = $SPNAV\n"


		# MAIN LOOP
write_info $infoname "===== BEGIN MAIN LOOP ====="
		# RECORD COUNTERS
set Nrecsadc 0
set Nrecsspn 0
set day0 0 						;# to initiate the first raw file
set hour0 "2000010100"			;# ARM HOURLY FILES
		# EXPECT LOOP
set timemsg1 [timestamp -gmt]	;# --- MISSING SPN INPUT TRANSMIT TIME
set timespn $timemsg1			;# --- TIME THE SPN IS RECEIVED 
set timespnlast 1e8      		;# --- TIME OF THE LAST RECEIVED SPN
set timemsg2 $timemsg1			;# --- MISSING ADC INPUT TRANSMIT TIME
set timeadc $timemsg1			;# --- TIME THE RAD IS RECEIVED 
set timeradlast 1e8      		;# --- TIME OF THE LAST RECEIVED RAD
while 1 {
	set dt [timestamp -gmt]
			# CHECK FOR A GAP IN ADC STRINGS
	if { [expr $dt - $timemsg2] > 60 && [expr $dt - $timeadc] > $adcdeadtime} {
		send_user "NO RAW ADC since [time format $timeadc -format "%y%m%d,%H%M%S"].\n"
		set timemsg2 $dt
	}
			# CHECK FOR A GAP IN SPN RAW STRINGS
	if { [expr $dt - $timemsg1] > 60 && [expr $dt - $timespn] > $spndeadtime} {
		send_user "NO RAW SPN since [time format $timespn -format "%y%m%d,%H%M%S"].\n"
		set timemsg1 $dt
	}
			# CHECK FOR A NEW DAY -- NEW RAW FILES
	set day1 [clock format $dt -format "%j -timezone UTC"]		;# julian day   
	if {$day1 != $day0} {
		send_user "DAY CHANGE\r\n"
		set day0 $day1
				# NEW ADC FILE
		set fname [clock format $dt -format "%y%m%d" -timezone UTC]
		set adcrawname "$datapath/adc_raw_$fname.txt";
		if {[file exists $adcrawname]} {
			send_user "Appending to ADC file $adcrawname\n"
		} else {
			set F [open $adcrawname w 0600]
			puts $F "nrec yyyy MM dd hh mm ss v0 v1 v2 v3 v4 v5 v6 v7"
			close $F
		}
				# NEW SPN FILE
		set spnrawname "$datapath/spn_raw_$fname.txt";
		if {[file exists $spnrawname]} {
			send_user "Appending to SPN file $spnrawname\n"
		} else {
			set F [open $spnrawname w 0600]
			puts $F "nrec yyyy MM dd hh mm ss total  diffuse sun"
			close $F
		}
		write_info $infoname "---NEW DAY---"
		write_info $infoname "adcrawname = $adcrawname"
		write_info $infoname "spnrawname = $spnrawname"
	}
			# ARM HOUR FILE NAME
	set hour1 [clock format $dt -format "%y%m%d%H" -timezone UTC]
	if { ![string match $hour1 $hour0] } {
		puts "NEW HOUR";
		set hour0 $hour1
				# ARM ADC FILE
		set adcrawnameh "$armpath/adc_raw_$hour1.txt";
		puts "ADC HOUR RAW FILE NAME = $adcrawnameh";
		if {[file exists $adcrawnameh]} {
			send_user "Appending to file $adcrawnameh\n"
		} else {
			set F [open $adcrawnameh w 0600]
			puts $F "nrec yyyy MM dd hh mm ss v0 v1 v2 v3 v4 v5 v6 v7"
			close $F
		}
				# SPN ADC FILE
		set spnrawnameh "$armpath/spn_raw_$hour1.txt";
		puts "SPN HOUR RAW FILE NAME = $spnrawnameh";
		if {[file exists $spnrawnameh]} {
			send_user "Appending to file $spnrawnameh\n"
		} else {
			set F [open $spnrawnameh w 0600]
			puts $F "nrec yyyy MM dd hh mm ss total  diffuse sun"
			close $F
		}
	}
			# SAMPLING LOOP
	set timeout 1
	#send_user "256\n";
	expect {
				# GET ADC PACKET
		set spawn_id $ADC
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
				# SPN DATA
		set spawn_id $SPN
		-re "(SPNRAW .*)\n\r" { 
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

