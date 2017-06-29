#!/usr/bin/perl -w


@x = `ls -1t $ENV{DAQFOLDER}`;

print"LIST OF DATA SETS - NEWEST FIRST\n";
$i=0;
foreach $str (@x) {
	$i++;
	chomp($str);
	print"$i $str\n";
}

printf"SELECT DATA SET (1-%d): \n", $#x+1;

chomp($set=<STDIN>);
$set--;

$db = "$ENV{PRP2FOLDER}/data/$x[$set]";
print"Data set: $db\n";

$da = "$ENV{PRP2FOLDER}/export/$x[$set].tar.gz";
print"Archive file: $da\n";

system"tar -zcvf $da $db";
$str = `du -sk $da`;

print"EXPORT COMPLETE size (KB) Name = $str\n";






