#! /usr/bin/perl

use lib $ENV{MYLIB};
use perltools::MRtime;
#use Device::SerialPort qw( :PARAM :STAT 0.07 );

$fin="prp.txt";

my $irec = 0;
my ($i1,$narg,$p);

$narg = $#ARGV;
if($narg>=0){
	foreach(@ARGV){print"  $_\n"}
}

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
