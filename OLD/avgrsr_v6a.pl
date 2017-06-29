#!/usr/bin/perl -w
my $PROGRAMNAME = 'avgrsr.pl';
my $VERSION = '06';  
my $EDITDATE = '121107';
#v01 -- taken from avggps.pl
#v02 -- file output with spaces and labeled for R
#v03 -- new file names
#v04 -- improve file handling.
#v05 -- add stdev of shadowratio to output string line
#v06 -- $glavg is now the max of the two globals.
## CALL --- ./avgrsr.pl data/test_setup.txt

my $setupfile = shift();
#my $setupfile = '/Users/rmr/swmain/apps/prp2/setup/test_setup.txt';
print "setup file = $setupfile\n";

$Mode = 0;
$Nwds = 0;
$Thead = 0;

#====================
# PRE-DECLARE SUBROUTINES
#====================
use lib $ENV{DAQLIB};
use perltools::MRtime;
use perltools::MRstatistics;
use perltools::MRutilities;
use POSIX;
#v0 => looks_like_number($w[0]) && $w[0]>=0 && $w[0]<=5 ? $w[0]*$slope0 + $offset0 : -999,
use Scalar::Util qw(looks_like_number);


print"\n======================== START PROCESSING $PROGRAMNAME =======================\n";

# DEFINE OUT PATH
my $datapath =  FindInfo($setupfile,'RT OUT PATH', ': ');
if ( ! -d $datapath ) { print"!! RT OUT PATH - ERROR, $datapath\n"; die }
# ARM OUT PATH
my $armpath = $ENV{DAQFOLDER}."/ARM";
#my $armpath =  FindInfo($setupfile,'ARM RT OUT PATH', ': ');
if ( ! -d $armpath ) { print"!! ARM RT OUT PATH - ERROR, $armpath\n"; die }
print "ARM RT OUT PATH = $armpath\n";

#===========================
# OUTPUT DATA FILE
#===========================
my $pgmstart = now();

$str = dtstr($pgmstart,'iso');
$fnavg = $datapath . '/' . "rsr_avg_".$str.".txt";
print"RSR AVERAGE OUTPUT FILE: $fnavg\n";

#----------------- HEADER ----------------

$header = "PROGRAM: $PROGRAMNAME (Version $VERSION, Editdate $EDITDATE)
RUN TIME: " . dtstr(now()) . " utc\n";

$isarsn = FindInfo($setupfile,'FRSR SERIAL NUMBER', ': ');
$header = $header."FRSR SERIAL NUMBER: $isarsn\n";

$isarsn = FindInfo($setupfile,'HEAD SERIAL NUMBER', ': ');
$header = $header."HEAD SERIAL NUMBER: $isarsn\n";

$Nchans = FindInfo($setupfile,'RSR CHANNELS', ': ');
$header = $header."RSR CHANNELS: $Nchans\n";

$Nblks = FindInfo($setupfile,'RSR SWEEP BLOCKS', ': ');
$header = $header."RSR SWEEP BLOCKS: $Nblks\n";

$ShadowRatioThreshold = FindInfo($setupfile,'RSR SHADOW RATIO THRESHOLD', ': ');
$header = $header."RSR SHADOW RATIO THRESHOLD: $ShadowRatioThreshold\n";

$header = $header."RSR OUT PATH: $datapath\n";

my $avgsecs = FindInfo($setupfile,'RSR AVERAGING TIME', ': ');
$header = $header."RSR AVERAGING TIME (secs): $avgsecs\n";
$header = $header."TIME MARK IS CENTERED ON AVERAGING INTERVAL\n";

$Nsamp_min = 10;
$header = $header."MINIMUM NO. SAMPLES FOR AN AVERAGE: $Nsamp_min\n";

## RSR SHUTDOWN CONTROL
# If shutdownflag == 1 and avg from $shutdownchannel < $shutdownthreshold == go to LOW
$shutdownflag = FindInfo($setupfile, 'RSR SHUTDOWN CONTROL',':');
$header = $header."RSR SHUTDOWN CONTROL: $shutdownflag\n";

$shutdownchannel = FindInfo($setupfile, 'RSR SHUTDOWN CHANNEL',':');
$header = $header."RSR SHUTDOWN CHANNEL: $shutdownchannel\n";

$shutdownthreshold = FindInfo($setupfile, 'RSR SHUTDOWN THRESHOLD',':');
$header = $header."RSR SHUTDOWN THRESHOLD: $shutdownthreshold\n";

$missing = FindInfo($setupfile,'MISSING VALUE', ': ');
$header = $header."MISSING NUMBER: $missing\n";

# v01a Conversion was 273.15.
$Tabs = 273.15;  # absolute temperature at 0degC
$header = $header."KELVIN CONVERSION: $Tabs\n";

@strings = FindLines($setupfile, 'RSR COMMENTS:', 100 );
$header = $header."RSR COMMENTS:\n";
if ( $#strings > 0 ){
	for($i=1; $i<=$#strings; $i++) { 
		if ( $strings[$i] =~ /^END/i ) {last}
		else { $header = $header."$strings[$i]\n";}
	}
}


## PRINT OUT THE HEADER
print"\n-------- HEADER ----------------\n$header\n";
my $outfile= "$datapath/rsr_info.txt";
open(HDR, ">>$outfile") or die;	
print"INFORMATION FILE: $outfile\n";
print HDR "===============================================================================\n";
print HDR "$header
=======
Line
1: Date, T_head in degC, Shadow Ratio
2: global0, bin0,...bin11,... bin22, global1 for channel 0 in W/m^2
3-8: global0, bin0,...bin11,... bin22, global1 for channel 1-6 in W/m^2/nm
========\n";
close HDR;


# ============ DATA PROCESSING PARAMETERS ===========
$SampleFlag = 0;		# 0=standard   1=start at first sample time.

#====================
# OTHER GLOBAL VARIABLES
#====================
use constant YES => 1;
use constant NO => 0;
use constant PI => 3.14159265359;


## CREATE THE @VARS STRING OF HASH VARIABLES
# There are the following 2-byte quantities:
# (Thead+20)*10, shadowratio*10, shadowthreshold*10 = 3
# global 0 and global 1 for each of 7 channels = 14
# 23 bins for 7 channels = 161
# A total of 178 numbers.
$NMaxDatWds = 178;
my $cmd = "\@VARS = ('a000'";
for($i=0; $i<$NMaxDatWds; $i++){ 
	$cmd = $cmd.sprintf ",'a%03d'",$i;
}
$cmd = $cmd.');';
eval($cmd);
#print"VARS: @VARS\n";

# CLEAR ACCUMULATOR ARRAYS
ClearAccumulatorArrays();		# Prepare for averaging first record

# WAIT FOR THE FIRST RECORD -- the process is in hold until the first good record come in.
$N_H = 0;    #N_H is the count of H modes in a full sample.
while ( ReadNextRecord($datapath) == NO ) {};
AccumulateStats();

##=================
## SAMPLE TIME MARKS
##==============
my ($dt_samp,$dt1,$dt2);
($dt_samp, $dt1, $dt2) = ComputeSampleEndPoints ( now(), $avgsecs, $SampleFlag);
#v4 printf"<<NEXT SAMPLE: dt_samp=%s, dt1=%s, dt2=%s>>\r\n", dtstr($dt_samp,'short'), dtstr($dt1,'short'), dtstr($dt2,'short');

#================
# BEGIN THE MAIN SAMPLING LOOP
# ===============
while ( 1 ) {
	#=====================
	# PROCESS ALL RECORDS IN AVG TIME
	#=====================
 	while ( 1 ) {
		#---READ NEXT RECORD (loop)---
		while ( ReadNextRecord($datapath) == NO )	{}
		#---NEW RECORD, CHECK FOR END---
		if ( $record{dt} >= $dt2 ) { last; }
		else {		
			AccumulateStats();
		}
	}
	#====================
	# COMPUTE SAMPLE STATS
	#====================
	ComputeStats();
	SaveStats($dt_samp, $datapath);
	if ( $Mode =~ /H/ ) {$N_H=1} else {$N_H=0}
	
	ClearAccumulatorArrays();		# Prepare for averaging first record
	($dt_samp, $dt1, $dt2) = ComputeSampleEndPoints( $record{dt}, $avgsecs, 0);	#increment $dt1 and $dt2 
	#v4 printf"NEXT SAMPLE: dt_samp=%s, dt1=%s, dt2=%s\r\n", dtstr($dt_samp,'short'), dtstr($dt1,'short'), dtstr($dt2,'short');
	AccumulateStats(); 			# deals with the current record
	#=======================
	# END OF THE LOOP
	#=======================
}
exit(0);





#*************************************************************/
sub ReadNextRecord
{
	my ($datapath, $rawout) = @_;
	
	my ($str, $cmd ,$dtrec, $Nfields, $ftmp, $i, $j);
	my @dat;
	my $flag = 0;
	my @dt;	

	##==================
	## WAIT FOR INPUT
	## Send out a prompt --
	## Loop checking for input, 5 sec
	## send another prompt
	##==================
	print"RSR--\n";
	chomp($str=<STDIN>);
	## COMMANDS
	if ( $str =~ /quit/i ) {print"QUIT RSR avg program\n"; exit 0 }
	
	$record{dt} = now();
#========================
# INPUT STRING
# FROM TT8 SOFTWARE SUBROUTINE PACKBLOCK
	# Pack the sweep by sweep data into a character block
	# A description of the lines.
	# STANDBY (Low mode)
	#  headtemp, adc{chan0], adc{chan1],...[adc[chan6],
	# OPERATE MODE
	#  headtemp, shadowratio*10, threshold*10, globalleft[chan0]...globalleft[chan6],
	#    globalright[chan0],...globalright[chan6], sweepblocks[chan0], sweepblocks{chan1],...
	#    sweepblock[chan6].
	# 
# VARS
#VARS: a000 a001 a002...a177
#a000 = 10*(temhead-20)
#a001 = 
	if($str =~ /##/ )	{					# identifies a data string
		#print"Begin string decode\n";
		($Nwds,$Mode,$Thead)=DecodeRSR($str, \@dat);
		$Thead = $Thead / 10 - 20;
		#print"ReadNextRecord Mode = $Mode\n";
		
		# HIGH MODE
		if ( $Mode =~ /H/i ) {
			$N_H++;
			for( $i=0; $i <= $#dat; $i++) {
			#looks_like_number($w[0]) && $w[0]>=0 && $w[0]<=5 ? $w[0]*$slope0 + $offset0 : -999
				$cmd = sprintf("\$record\{a%03d\} = looks_like_number(\$dat\[%d\]) ? \$dat\[%d\] : \$missing;",$i,$i,$i);
				eval($cmd);
			}
			printf "<<RSRH %s %d %s %.1f %.1f %.1f >>\r\n", 
				dtstr($record{dt},'ssv'), , $Nwds, $Mode, $Thead, $dat[1]/10, $dat[2]/10;
			return (YES);
			
		# LOW MODE
		# 
		} else { 
			printf "<<RSRL %s %d %s %.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f >>\r\n", 
				dtstr($record{dt},'ssv'), $Nwds, $Mode, $Thead,
				$dat[1],$dat[2],$dat[3],$dat[4],$dat[5],$dat[6],$dat[7];
			
			$record{a000} = looks_like_number($dat[0]) ? $dat[0] : $missing;
			$record{a001} = 0; 
			$record{a002} = 0;
			
			for( $i=1; $i <= 7; $i++) {
				$cmd = sprintf("\$record\{a%03d\} = looks_like_number(\$dat\[%d\]) ? \$dat\[%d\] : $missing;",$i+2,$i,$i);
				eval($cmd);
			}
			
			for( $i=10; $i <= $#VARS; $i++) {
				$cmd = sprintf("\$record\{a%03d\} = \$missing;",$i);
				eval($cmd);
			}
			return (YES)
		}
	}
	return (NO);
}

#==========================================================================
sub DecodeRSR
# ##0357,Hoo4RG068e?]GSOCW=_if78f?^GPOFW6_1g685878386828k7n768e1D0D0J0N0S64828584878683
# 838i?i?h?k?0@i?`?e?k?I3D0D0P0N0e<f?b?f?g?m?i?i?h?ZG^GZG]G\G]GZG\G[G05D0D0N0N08C^GXGZG
# ^GXG\G^G\GQOPOMOSOJOSOOOLONOU6D0D0P0N0@IROTOTOPOTOOOOOROCWGWCW?WBWFWHWGWJW78D0D0K0N0O
# ODW@WAWFWGWEWDWDW8_9_8_;_<_8_=_;_<_[9D0D0O0N0`U4_<_7_6_3_7_7_9_kfjfmfofnfif2g4g7g>;D0
# D0L0N0;\ofnfhfffgfkflfmf*ks/##
{
	my $S = shift();	## this is the input string.
	my $d = shift();  	## this is the output array
	my ($b1,$b2, $x,$i,$j);
	my $nwds = (substr($S,2,4)-1)/2;
	my $mode = substr($S,7,1);
	#printf"test DecodeRSR, Nwords = %d, mode = %s\n", $Nwds, $mode;
	
	# The RSR psuedoascii string is made up of 2 character (12 bit) integers.
	# High mode:357 bytes
	# mode = 1 byte
	# head temp = 2 bytes
	# shadow ratio = 2 bytes
	# threshold ratio 2 bytes
	# global 0 = 7 words, global 1 = 7 words x 2 bytes/word = 28 bytes
	# 23 bins/channel x 2 bytes/bin x 7 channels = 322 bytes 
	$i = 0;
	while($i < $nwds) {
		$j = 8 + 2*$i;
		$c1 = substr($S,$j,1);
		$c2 = substr($S,$j+1,1);
		$b1 = ord( $c1 ) - 48;
		$b2 = ord($c2) - 48;
		$x = $b2*64+$b1;
		push @{$d}, $x;
		#printf"%3d, c1 = %s, c2 = %s, b1 = %d, b2 = %d, x = %d\n", $i, $c1, $c2, $b1, $b2, $x;
		$i++;
	}
	#print"DecodeRSR Thead = ${$d}[0]\n";
	return($nwds, $mode, ${$d}[0]);
}

#*************************************************************/
sub ClearAccumulatorArrays
# CLEAR ACCUMULATOR ARRAYS FOR ALL AVERAGING
{
	my ($i, @x, @y);
	#=================
	#	SET UP THE HASHES
	#=================
	my %xx = ( sum => 0, sumsq => 0, n => 0, min => 1e99, max => -1e99 );
	my %yy = ( mn => $missing, std => $missing, n => 0, min => $missing, max => $missing );
	# ---- INITIALIZE HASHES -------
	foreach ( @VARS ) 
	{
		eval "%sum_$_ = %xx;   %samp_$_ = %yy;";
	}
}


#*************************************************************/
sub AccumulateStats
# Add to the sums for statistical averages
# Increments global hash variable %sum_xx(sum, sumsq, n, min, max) where
#  xx = (kt, bb2t3, bb2t2, bb2t1, bb1t3, bb1t2, bb1t1, Vref, bb1ap1, bb1bb2ap2, bb2ap3, kttempcase,
#	wintemp, tt8temp, Vpwr, sw1, sw2, pitch, roll, sog, cog, az, pnitemp, lat, lon, sog, var, kttemp )
{
	my ($d1, $d2, $ii);
	my ($x, $y, $s);
	
		foreach ( @VARS )
		{
			my $zstr = sprintf("\@s = %%sum_%s;  %%sum_%s = Accum (\$record{%s}, \@s);", $_, $_, $_);
			eval $zstr;
		}
	#Test, print out variables.
	
}

#*************************************************************/
sub Accum
# Accum(%hash, $datum);   global: $missing
{
	my ($x, @a) = @_;
	my %r = @a;
	#printf("Accum : %.5f\n", $x);
	if ( $x > $missing )
	{
		$r{sum} += $x;
		$r{sumsq} += $x * $x;
		$r{n}++;
		$r{min} = min($r{min}, $x);
		$r{max} = max($r{max}, $x);
		@a = %r;
	}
	return( @a );
}

#*************************************************************/
sub ComputeStats
# ComputeStats();
#  xx = (drum, kt, bb2t3, bb2t2, bb2t1, bb1t3, bb1t2, bb1t1, Vref, bb1ap1, bb1bb2ap2, bb2ap3, kttempcase,
#	wintemp, tt8temp, Vpwr, sw1, sw2, pitch, roll, sog, cog, az, pnitemp, lat, lon, sog, var, kttemp )
{
	my $i;
	my ($mean, $stdev, $n, $x, $xsq);
	
	#====================
	# SCALARS
	# sub (mn, stdpcnt, n, min, max) = stats(sum, sumsq, N, min, max, Nsamp_min);
	#=====================
	foreach ( @VARS ) {
		my $zz = sprintf( "( \$samp_\%s{mn}, \$samp_\%s{std}, \$samp_\%s{n}, \$samp_\%s{min}, \$samp_\%s{max}) =
			stats1 ( \$sum_\%s{sum},  \$sum_\%s{sumsq},  \$sum_\%s{n},  \$sum_\%s{min},  \$sum_\%s{max}, \$Nsamp_min, \$missing );",
			$_,$_,$_,$_,$_,$_,$_,$_,$_,$_);
		eval $zz ;
	}
}
	

#*************************************************************/
sub SaveStats
## Create a string with all the data then save the string to file and print out with framing
{
	my ($dt, $path) = @_;
	my $modecommand=1;
	my $str = dtstr($dt,'iso');
	my $timestr = dtstr($dt,'ssv');
	
	## STANDARD OUT FILE
	open(F,">>$fnavg") or die;
	
	## ARM OUT FILE
	my @w = datevec($dt_samp);
	my $fnarm = "$armpath/rsr_avg_".sprintf("%4d%02d%02d%02d",$w[0],$w[1],$w[2],$w[3]).".txt";
	open(FA, ">>$fnarm") or die;
	
	$str1=sprintf"\$samp_a%03d{mn}", $shutdownchannel+3; 
	$str2=sprintf"\$samp_a%03d{mn}", $shutdownchannel+10;
	$cmd=sprintf("\$glavg = (%s + %s)/2;",$str1,$str2);
	eval($cmd);
	if ($N_H >= $Nsamp_min ) {
		## RSR SHUTOFF FLAG
		# $shutdownflag, $shutdownchannel, $shutdownthreshold
		# On print out the last number will be 0 no action or -1 SW < threshold
		if( $shutdownflag && $glavg > -100 ) {					# frsr flag true and valid SW
			if ( $glavg < $shutdownthreshold ) 	{$modecommand = 0} # LOW MODE turn frsr off
			else 								{$modecommand = 1} # high mode and high input, do nothing
		} else {$modecommand = -1} # do nothing
				
		# time thead glavg threshold shadowratio std_shadowratio shadowthreshold modecommand
		$str = sprintf"<<RSAV %s   %6.1f   %6.1f %6.1f    %6.1f %6.1f  %6.1f   %d >>", 
			$timestr,$samp_a000{mn}/10 - 20, $glavg, $shutdownthreshold, 
			$samp_a001{mn}/10, $samp_a001{std}/10, $samp_a002{mn}/10, $modecommand; #v05
		printf("%s\r\n", $str);  ## output to terminal
		$str = $str."\n";  ## output to file
		
		# GLOBAL_1 averages
		for($i=3; $i<=9; $i++) { 
			eval(sprintf("\$str = \$str.sprintf \" %%6.1f\",\$samp_a%03d{mn};",$i));
		}
		$str = $str."\n";
		
		# GLOBAL_2 averages
		for($i=10; $i<=16; $i++) { 
			eval(sprintf("\$str = \$str.sprintf \" %%6.1f\",\$samp_a%03d{mn};",$i));
		}
		$str = $str."\n";
		
		# SWEEP BINS
		my $k=17;
		for($j=0; $j<7; $j++) {
			for($i=0; $i<23; $i++) { 
				eval(sprintf("\$str = \$str.sprintf \" %%6.1f\", \$samp_a%03d{mn};",$k));
				$k++;
			}
			$str = $str."\n";
		}
		print F $str;
		print FA $str;
		
	## LOW MODE OPERATION
	} else {	
		## RSR SHUTOFF GLOBAL VALUE
		#$str1=sprintf"\$glavg = \$samp_a%03d{mn}", $shutdownchannel+3; 
		#eval($str1);
		
		## shutdown requested AND the number is good
		if( $shutdownflag && $glavg > -100 ) {					# frsr flag true and valid SW
			if ( $glavg >= $shutdownthreshold ) {$modecommand = 1} # SWITCH FRSR ON
			else 								{$modecommand = 0} # do nothing
		} else {$modecommand = -1}
		
		# time, thead, global 0-6, shutoff
		# LOW LINE 1
		$str = sprintf"<<RSAV %s %6.1f", 
			$timestr, $samp_a000{mn} /10 - 20;
		for($i=3; $i<=9; $i++) { 
			eval(sprintf("\$str = \$str.sprintf \" %%6.1f %%6.1f\",\$samp_a%03d{mn}, \$samp_a%03d{std};",$i,$i));
		}
		$str = $str.sprintf(" %d>>\n", $modecommand);
		print $str; # print out the output line
		print F $str;
		print FA $str;
	}
	close F;
	close FA;
}
#                               Thead  
#*** RSAV 2012 08 09 23 37 00   31.2  -16.0    0.0    0.0    0.0  194.0    0.0  176.0    0.0    0.0    0.0  308.1  191.4 -848.0    0.0 0
