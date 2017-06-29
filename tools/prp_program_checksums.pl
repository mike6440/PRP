#!/usr/bin/perl -w
#prp_program_checksums.pl
# use strict;
# use warnings;

$Name='PRP';

$Media="/media/rmrco";
#$Media="/Volumes";

$swpath="$ENV{HOME}/swmain/apps/$Name/sw";
print"swpath = $swpath\n";

my ($archivepath) = @ARGV;
if( not defined $archivepath ){
	print"ERROR -- No archive drive specified\n";
	exit;
}
$archivepath="$archivepath/swmain/apps/$Name/sw";
print"archivepath=$archivepath\n";
$archiveflag=1;
if(! -d $archivepath){
	print"archive path: $archivepath MISSING\n";
	$archiveflag=0;
}

$pgms='ArchivePrp
avgprp
Cleanupprp
ClearPrpData
DaqUpdate
FindUSBPort
getsetupinfo
help.txt
kerm232
kermss
KickStart
KillScreen
LastDataFolder
LastDataRecord
LastDataTime
PrepareForRun
SetDate
term_to_prp
UpdateDaq
Z_prp
setup/su.txt
../tools/bashrc_add_to_existing.txt
../tools/bashrc_prp.txt
../tools/crontab_prp.txt
../tools/kermrc_prp.txt
../tools/screenrc_prp.txt
../tt8/Prp_v15/PRP402.c';

#print"$pgms\n";
@p=split /\n/,$pgms;

print"  n     sw      archive  File\n";
# 0	29540	29540	ArchiveRosr

$i=0; foreach $f (@p){	
	$e=' ';
	# SW FOLDER
	$ff="$swpath/$f";
	if(! -f $ff){
		#print"file $ff missing\n";
		$s='-9999';
		$e='*';
	} else {
		@f=split / /,`sum $ff`;
		$s=$f[0];
	}
	# ARCHIVE FOLDER
	$ff="$archivepath/$f";
	if(! -f $ff){
		#print"archive file $ff missing\n";
		$e='*';
		$sa='-9999';
	} else {
		@f=split / /,`sum $ff`;
		$sa=$f[0];
	}
	if($sa ne $s){$e='*'}
	if($archiveflag==1){printf"%s%2d\t%d\t%d\t%s\n",$e,$i,$s,$sa,$f}
	else{printf"%d\t%d\t%s\n",$i,$s,$f}
	$i++;
}
