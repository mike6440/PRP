#!/usr/bin/perl -w

my @x = `ls -1t $ENV{PRP2DATAPATH}`;

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

open TMP, ">tmp.tx1" or die;
print TMP "$db\n";

exit;
