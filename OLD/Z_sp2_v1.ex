#!/usr/bin/expect --

set PROGRAMNAME Z_sp2.ex
set VERSION 1
set EDITDATE 130503

puts "
RUN PROGRAM $PROGRAMNAME, VERSION $VERSION, EDITDATE $EDITDATE"

set loguser 0;#   test 0-quiet, 1=verbose
log_user $loguser;

#===================================================================
#   PROCEDURE TO START AVG SP2 PROGRAM
#==================================
proc SpawnAvgSpn { setupfile infoname sutxt} {
	spawn perl avgsp2.pl $sutxt;
	set AV $spawn_id;
	write_info $infoname "SPAWN SP2 AV spawn_id = $spawn_id"
	# WAIT FOR THE STARTUP PROMPT
	set timeout 2
	expect {
		# TIMEOUT (avg program) WITH NO REPLY
		timeout {
			send -i $AV "quit\r\n"
			send_user "SP2 AV STARTUP, Timeout with no reply\n"
			exit 1
		}
		# REPLY FROM AVG PROGRAM
		"SP2--" {
			send_user "AVG_SP2 is ready\n"
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
set infoname "$datapath/sp2_info.txt";
send_user "INFO FILE = $infoname\n";
		# START UP BANNER
set str  "PROGRAM $PROGRAMNAME, Version $VERSION, Editdate $EDITDATE, Runtime [timestamp -gmt -format "%Y%m%d,%H%M%S"]"
write_info $infoname "\n===== $str ============="
		# READ THE SETUPFILE
log_user  $loguser;  ;#test 0-quiet, 1=verbose
		# DATA INFORMATION
write_info $infoname  "RT OUT PATH: $datapath"
		# SP2
		# DEAD TIME WITH NO SP2
spawn -noecho ./getsetupinfo.pl $setupfile "SPN DEAD TIME ALARM"
expect -re "(\.*)(\r)";
write_info $infoname  "SP2 DEAD TIME ALARM: $expect_out(1,string)"
set spndeadtime $expect_out(1,string);
puts "SP2 DEAD TIME: $spndeadtime";
		# SPAWN GET_SPN -- free running
send_user "OPEN GET_SP2\n";
set cmd "expect get_sp2.ex $setupfile";
send_user "cmd = $cmd\n";
spawn expect get_sp2.ex $setupfile
set SPN $spawn_id
	# OPEN SPN PORT FAILS
if { $SPN == 0 } {
	send_user "GET_SP2 SPAWN FAILS ON START UP\n"
	exit 1
} else {
	send_user "GET_SP2 SPAWN SUCCESS, SPN = $SPN\n"
}
		# SPN AVG PROGRAM
set SPNAV [SpawnAvgSpn $setupfile $infoname $setupfile]
send_user "SP2AV = $SPNAV\n"
		# MAIN LOOP
write_info $infoname "===== BEGIN MAIN LOOP ====="
		# RECORD COUNTERS
set Nrecsspn 0
set day0 0 						;# to initiate the first raw file
set hour0 "2000010100"			;# ARM HOURLY FILES
		# EXPECT LOOP
set timemsg1 [timestamp -gmt]	;# --- MISSING SPN INPUT TRANSMIT TIME
set timespn $timemsg1			;# --- TIME THE SPN IS RECEIVED 
set timespnlast 1e8      		;# --- TIME OF THE LAST RECEIVED SPN
while 1 {
	set dt [timestamp -gmt]
			# CHECK FOR A GAP IN SPN RAW STRINGS
	if { [expr $dt - $timemsg1] > 60 && [expr $dt - $timespn] > $spndeadtime} {
		send_user "RAW SP2 data break.\n"
		set timemsg1 $dt
	}
			# CHECK FOR A NEW DAY -- NEW RAW FILES
	set day1 [timestamp -gmt -format "%j"]		;# julian day   
	if {$day1 != $day0} {
		send_user "DAY CHANGE\r\n"
		set day0 $day1
				# NEW SP2 FILE
		set fname [timestamp -gmt -format "%y%m%d"]
		set spnrawname "$datapath/sp2_raw_$fname.txt";
		if {[file exists $spnrawname]} {
			send_user "Appending to SP@ file $spnrawname\n"
		} else {
			set F [open $spnrawname w 0600]
			puts $F "nrec yyyy MM dd hh mm ss total  diffuse sun"
			close $F
		}
		write_info $infoname "---NEW DAY---"
		write_info $infoname "spnrawname = $spnrawname"
	}
			# ARM HOUR FILE NAME
	set hour1 [timestamp -gmt -format "%y%m%d%H"]
	if { ![string match $hour1 $hour0] } {
		puts "NEW HOUR";
		set hour0 $hour1
				# SPN FILE
		set spnrawnameh "$armpath/sp2_raw_$hour1.txt";
		puts "SP2 HOUR RAW FILE NAME = $spnrawnameh";
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
	#send_user "161\n";
	expect {
				# SP2 DATA
		-i $SPN
		-re "(SP2RAW .*)\n" { 
			set rply [string trim $expect_out(1,string)]
					# FULL STRING LENGTH
					# INCREMENT Nrecsspn
			set Nrecsspn [expr $Nrecsspn + 1];
			set timenav [timestamp -gmt];		#v1a time of the last good nav			
					# 	SAVE TO RAW FILE
			set F [open $spnrawname a 0600]
			set rawstr $Nrecsspn[timestamp -gmt -format " %Y %m %d %H %M %S "]$rply  ;
			puts $F $rawstr
			close $F	
				
				# SAVE TO ARM HOUR RAW FILE
			set F [open $spnrawnameh a 0600]
			#set rawstr $Nrecsspn[timestamp -gmt -format " %Y %m %d %H %M %S "]$rply  ;
			puts $F $rawstr
			close $F
			
				# SEND RAW TO AVG AND GET A RESPONSE
			set spawn_id $SPNAV
			send "$rply\r\n"
			expect -re "<<(SP2RW .*)>>" { 
				send_user "$expect_out(1,string)\n" 
			}
			expect -i $SPNAV -re "<<(SP2AV .*)>>" { send_user "***$expect_out(1,string)\n" }
		}
	}
}

