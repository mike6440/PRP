#!/usr/bin/expect --

set PROGRAMNAME Z_gps.ex
set VERSION 2
set EDITDATE 120720
puts "
RUN PROGRAM $PROGRAMNAME, VERSION $VERSION, EDITDATE $EDITDATE"

set loguser 0;#   test 0-quiet, 1=verbose
log_user $loguser;

#===================================================================
#   PROCEDURE TO START AVGGPS PROGRAM
#==================================
proc SpawnAvgGps { setupfile infoname } {
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
	return $GPSAV
}

#===================================================================
#   PROCEDURE TO COMPUTE LAT AND LON FROM GPS STRING
# $s2 = gps raw string
#  "\$GPRMC,235944,A,4922.9147,N,12418.9757,W,007.7,294.5,030609,019.2,E*61"
#output
# $so = "49.45645,-124.6785"
#===================
proc get_latlonstr {s2} {
	set g [split $s2 ,*]
	## LATITUDE -- CHECK AS A GOOD NUMBER
	set l [lindex $g 3];
	if { ! [string is double $l] } {
		send_user "get_latlonstr: GPS lat string, $l, is not a f.p. number\n";
		set lat -999
	} else {
		set l2 [expr int($l/100)]
		set lat [expr $l2 + ($l - $l2*100)/60]
		if { [string equal -nocase [lindex $g 4] S] } {set lat [expr -$lat] }
		if { $lat < -90 || $lat > 90 } {

			send_user "get_latlonstr: GPS lat out of range, set to missing\n";
			set lat -999;
		}
	}
	
	## LONGITUDE
	set l [lindex $g 5];
	if { ! [string is double $l] } {
		send_user "get_latlonstr: GPS lon string is not a f.p. number\n";
		set lon -999
	} else {
		set l2 [expr int($l/100)]
		set lon [expr $l2 + ($l - $l2*100)/60]
		if { [string equal -nocase [lindex $g 6] W] } {set lon [expr -$lon] }
		if { $lon <= -180 || $lon > 360 } {
			send_user "get_latlonstr: GPS lon out of range, set to missing\n";
			set lon -999;
		}
	}

	## SOG
	set sog [lindex $g 7];
	if { ! [string is double $sog] } {
		send_user "get_latlonstr: GPS sog string is not a f.p. number\n";
		set sog -999
	} else {
		if { $sog < 0 || $sog > 40 } {
			send_user "get_latlonstr: GPS sog out of range, set to missing\n";
			set sog -999;
		}
	}
	
	## COG
	set cog [lindex $g 8];
	if { ! [string is double $cog] } {
		send_user "get_latlonstr: GPS cog string is not a f.p. number\n";
		set cog -999
	} else {
		if { $cog < 0 || $cog > 360 } {
			send_user "get_latlonstr: GPS cog out of range, set to missing\n";
			set cog -999;
		}
	}

	## VAR
	set var [lindex $g 10];
	if { ! [string is double $var] } {
		send_user "get_latlonstr: GPS var string is not a f.p. number\n";
		set var -999
	} else {
		if { [string equal -nocase [lindex $g 11] W] } {set var [expr -$var] } 
		if { $var < -90 || $var > 90 } {
			send_user "get_latlonstr: GPS var out of range, set to missing\n";
			set var -999;
		}
	}

	#===========
	#OUTPUT STRING
	#===========
	set posstr [format "%.6f %.6f %.1f %.0f %.1f" $lat $lon $sog $cog $var]
	return $posstr;
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
	puts "FAILS, exit 1"
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
#    ARM FOLDER DEFINED
append armpath $env(DAQFOLDER) "/ARM"
send_user "ARMPATH = $armpath\n"

# WRITE A HEADER TO INFO FILE
set tm [timestamp -format "%y%m%d%H%M%S"];
set infoname "$datapath/gps_info.txt";
puts "GPS INFORMATION FILE: $infoname\n"
set str  "PROGRAM $PROGRAMNAME, Version $VERSION, Editdate $EDITDATE, Runtime [timestamp -format "%Y%m%d,%H%M%S"]"
write_info $infoname  $str 

# WRITE A HEADER TO INFO FILE
set infoname "$datapath/gps_info.txt";
puts "INFORMATION FILE: $infoname"

set str  "PROGRAM $PROGRAMNAME, Version $VERSION, Editdate $EDITDATE, Runtime [timestamp -gmt -format "%Y%m%d,%H%M%S"]"
write_info $infoname "=================="
write_info $infoname  $str 

## =========================================
## READ THE SETUPFILE
## ========================================
log_user  $loguser;  ;#test 0-quiet, 1=verbose

write_info $infoname  "DATAPATH: $datapath"

# PDS SERIAL HUB URL AND OFFSET
spawn -noecho ./getsetupinfo.pl $setupfile "SERIAL HUB URL"
expect -re "(\.*)(\r)";
set hub_url $expect_out(1,string)
write_info $infoname  "SERIAL HUB URL: $hub_url"

## TIME WITH NO GPS
spawn -noecho ./getsetupinfo.pl $setupfile "GPS DEAD TIME ALARM"
expect -re "(\.*)(\r)";
write_info $infoname  "GPS DEAD TIME ALARM: $expect_out(1,string)"
set zdeadtime $expect_out(1,string);

# GPS FIXED LATITUDE
spawn -noecho ./getsetupinfo.pl $setupfile "GPS FIXED LATITUDE"
expect -re "(\.*)(\r)";
set fixedlat $expect_out(1,string)
write_info $infoname  "GPS FIXED LATITUDE: $fixedlat"

# GPS FIXED LONGITUDE
spawn -noecho ./getsetupinfo.pl $setupfile "GPS FIXED LONGITUDE"
expect -re "(\.*)(\r)";
set fixedlon $expect_out(1,string)
write_info $infoname  "GPS FIXED LONGITUDE: $fixedlon"

## DEFINE THE PORTS 
spawn -noecho ./getsetupinfo.pl $setupfile "GPS HUB COM NUMBER"
expect -re "(\.*)(\r)";
set gpsport $expect_out(1,string)
write_info $infoname  "GPS HUB COM NUMBER: $gpsport"

# KERMIT/SIMULATE CONNECTION
if {$gpsport == 0} {
	spawn perl simulate/gps_simulator.pl 5
	set GPS	$spawn_id;
	write_info $infoname "GPS SIMULATE INPUT, spawn_id = $GPS"
	send_user "GPS SIMULATE INPUT, spawn_id = $GPS\n"
} elseif { $gpsport == -1 } {
	write_info $infoname "NO GPS"
	send_user "NO GPS\n"
	set GPS -1;
} else {
	send_user "OPEN GPS PORT $hub_url, port $gpsport";
	set GPS [spawn_kermit $hub_url $gpsport];
	write_info $infoname "GPS handle = $GPS\n";
	# OPEN PORT FAILS
	if { $GPS == 0 } {
		write_info $infoname "GPS KERMIT SPAWN FAILS ON START UP"
		exit 1
	}
}

#=========================
# GPSAV PROGRAM
#=========================
set GPSAV [SpawnAvgGps $setupfile $infoname]
send_user "AVG PROGRAM SPAWN: $GPSAV\n"

# =====================
# MAIN LOOP
# Wait for a string from isar
# Send the string to isar_avg program
#======================
set timegps [timestamp -gmt]
# COUNT THE NUMBER OF GOOD ISAR RECORDS RECEIVED
set Nrecs 0
set day0 0 ;# to initiate the first raw file
set hour0 "2000010100";# ARM HOURLY FILES

while 1 {
	set dt [timestamp -gmt]
	
	if { [expr $dt - $timegps] > $zdeadtime } {
		send_user "NO RAW GPS IN $zdeadtime SECS.\n"
		set timetcm $dt
		set dt0 $dt
	}
	
	# CHECK FOR A NEW DAY -- NEW FILES
	set day1 [timestamp -gmt -format "%j"]
	if {$day1 != $day0} {
		send_user "DAY CHANGE\r\n"
		set day0 $day1
		set fname [timestamp -gmt -format "%y%m%d"]
		set rawname "$datapath/gps_raw_$fname.txt";
		puts "RAW FILE NAME = $rawname";
		if {[file exists $rawname]} {
		} else {
			set F [open $rawname w 0600]
			puts $F "nrec yyyy MM dd hh mm ss lat lon sog cog var"
			close $F
		}
		write_info $infoname "---NEW DAY---"
		write_info $infoname "rawname = $rawname"
	}
	
	## ARM HOUR FILE NAME
	set hour1 [timestamp -gmt -format "%y%m%d%H"]
	if { ![string match $hour1 $hour0] } {
		set hour0 $hour1
		set rawnameh "$armpath/gps_raw_$hour1.txt";
		puts "ARM HOUR RAW FILE NAME = $rawnameh";
		if {[file exists $rawnameh]} {
		} else {
			set F [open $rawnameh w 0600]
			puts $F "nrec yyyy MM dd hh mm ss lat lon sog cog var"
			close $F
		}
	}
	
	#================
	# EXPECT FUNCTION -- WAITING FOR RESPONSE
	# ===============
	expect { 		
		-i $GPS
		-re "(\\\$GPRMC\.*?)\r" {
			set gpsstr $expect_out(1,string);
			set gpsstr [string trim $gpsstr ]
			set timegps [timestamp -gmt] ;# record the time of the last gps
			
			# SEND TO AVG PROGRAM
			send -i $GPSAV "$gpsstr\r\n"
			
			# SAVE TO RAW FILE
			set strx [get_latlonstr $gpsstr]    ;#GPS decode the NMEA
			set F [open $rawname a 0600]
			set rawstr [timestamp -gmt -format "$Nrecs %Y %m %d %H %M %S "]$strx
			puts $F $rawstr
			close $F
			
			# SAVE TO ARM HOUR RAW FILE
			set F [open $rawnameh a 0600]
			puts $F $rawstr
			close $F
			
			# SEND RAW TO AVG AND RCV RESPONSE
			set timeout 1
			set spawn_id $GPSAV
			send "$rawstr\r\n"
			expect {
				timeout { send_user "AVG timeout\n" }
				-re "<<(GPSRW\.*)>>"	{send_user "$expect_out(1,string)\n"} 
			}
			
			set Nrecs [expr $Nrecs + 1];
		
		}
			
		-i $GPSAV
		eof	{
			write_info $infoname "avggps.pl has crashed\n";
			exit 1;
		}
		
		-re "<<(GPSAV,\.*?)>>\r\n" {send_user "$expect_out(1,string)\n";}
		
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
						#  >20101226,195812,  41,0,1, -2.5,-1.5, 125,  514,3393,3394,3392,2340,2340,2355, 47.603,-122.288, 0.1,   0
				send_user " yyyyMMdd,hhmmss ormv sw0 sw1  ptch roll fgaz  kt b11mv b12  b13  b21  b22  b23   lat     lon     sog  cog \n";
			}
			exp_continue
		}
	}
}

