#!/usr/bin/expect --
# KERMIT CONNECTION


log_user 1;

## DEFINE THE PORTS
spawn -noecho ./getserialports.pl
expect -re "(\.*)\r\n(\.*)\r\n(\.*)\r\n(\.*)\r\n(\.*)\r\nEND" {
	set port1 $expect_out(1,string)
	set port2 $expect_out(2,string)
	set port3 $expect_out(3,string)
	set port4 $expect_out(4,string)
	set port5 $expect_out(5,string)
	puts "port1 = $port1";
	puts "port2 = $port2";
	puts "port3 = $port3";
	puts "port4 = $port4";
	puts "port5 = $port5";
}
set d "set tcmport \$port[lindex $argv 0]";
eval $d;
send_user "TCM is on port [lindex $argv 0], $tcmport\n";

# START PROCESS -- KERMIT FOR TCM MODEM
spawn kermit
expect {
	timeout {"KERMIT FAILS TO OPEN\n"; exit 1}
	"C-Kermit>"
}
send_user "KERMIT IS OPEN.\n"
set TCM $spawn_id

# A FEW START UP COMMANDS
## CLEAR BUFFER
expect *
## PRINT KERMIT VERSION NUMBER
send "version\r"
expect -gl "C*\n " {send_user "VERSION: $expect_out(0,string)"}
send "prompt >>\r"
expect ">>" {send_user "SET PROMPT>>\n"}


set timeout 3
## OPEN THE PORT
send "set line $tcmport\r"
expect "\n>>"
## SPEED
send "set speed 9600\r"
## DUPLEX
set duplex half
expect "\n>>"
## FLOW CONTROL
send "set flow none\r"
expect "\n>>"
## CARRIER WATCH
send "set carrier-watch off\r"
expect "\n>>"
## CONNECT 
send "connect\r"
expect {
	"Conn*---"  {send_user "TCM CONNECTED\n"}
	timeout {send_user "TIMEOUT, NO CONNECT"; exit 1}
}


set spawn_id $TCM
interact

exit 0
