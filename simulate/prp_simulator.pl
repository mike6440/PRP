#! /usr/bin/perl

use lib $ENV{DAQLIB};
use perltools::MRtime;
#use Device::SerialPort qw( :PARAM :STAT 0.07 );

$fin="prp.txt";

my $irec = 0;
my ($i1,$narg,$p);

$narg = $#ARGV;
if($narg>=0){
	foreach(@ARGV){print"  $_\n"}
}
# $p=FindUSBPort();
# print"port=$p\n";
# 
# die;

while (1) {
	$irec = 0;
	open(F,"<$fin") or die("fin error\n");

	# Loop through all the data records.
	while (<F>) {
		chomp( $str = $_);

		# STRIP OFF THE BEGINNING TIME USING SED
		print"$str\r\n";
		sleep(2);
		$irec++;
	}
	print"Starting over\n";
	close F;
}

sub FindUSBPort {
	my @w = `ls /dev/tty*PL* 2>/dev/null`;
	my @x = `ls /dev/tty*USB* 2>/dev/null`;
	my @y = `ls /dev/tty*usb* 2>/dev/null`;
	@w=(@w,@x,@y);
	if ( $#w < 0 ){print"No USB\n"; exit 1}
	chomp($w[0]);
	return $w[0];
}
