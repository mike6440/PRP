#!/usr/bin/perl -w
my $PROGRAMNAME = 'avgrad.pl';
my $VERSION = '06';  
my $EDITDATE = '130502';
		#v01 -- taken from isrtsb.pl
		#v02 -- fix output av files for R processing.
		# v03 -- new file names
		#v04 -- improve file handling.
		#       remove NEXT SAMPLE print.
		#v05 -- prep for Magic
		#v06 -- changed minimum allowable temperature to -10 C. Line
		## CALL --- ./avgrad.pl data/test_setup.txt

		# DATA INPUT
		#$WIR07,10/02/19,17:47:30, 175,   57.6, 467.11, 22.14, 21.25,   7.11, 25.8, 11.9

		#====================
		# PRE-DECLARE SUBROUTINES
		#====================
use lib $ENV{DAQLIB};
use perltools::MRtime;
use perltools::MRstatistics;
use perltools::MRutilities;
use POSIX;
use Scalar::Util qw(looks_like_number);


		#  SETUPFILE
my $setupfile = shift();
print "SETUPFILE = $setupfile ";
if ( -f $setupfile ) {print"EXISTS.\n"}
else { 
	print"DOES NOT EXIST. STOP.\n";
	exit 1;
}


# DEFINE OUT PATH
my $datapath =  FindInfo($setupfile,'RT OUT PATH', ': ');
if ( ! -d $datapath ) { print"!! RT OUT PATH - ERROR, $datapath\n"; die }
# ARM OUT PATH
my $armpath =  $ENV{DAQFOLDER}."/ARM";
if ( ! -d $armpath ) { print"!! ARM RT OUT PATH - ERROR, $armpath\n"; die }
print "ARM RT OUT PATH = $armpath\n";


#========================
# OPEN THE HEADER FILE
#========================
my $pgmstart = now();
$str = dtstr($pgmstart,'iso');
my $pgmstart = now();

my $fnhdr = "$datapath/rad_hdr.txt";
print"OUTPUT HEADER FILE: $fnhdr\n";
open HDR,">>$fnhdr" or die"OPEN HEADERFILE FAILS";
print HDR "===============================================================================\n";

print HDR "PROGRAM: $PROGRAMNAME (Version $VERSION, Editdate $EDITDATE)\n";
print HDR "RUN TIME: ". dtstr($pgmstart) . " utc\n";							# v04

my $avgsecs = FindInfo($setupfile,'RAD AVERAGING TIME', ': ');   # v04
print HDR "RAD AVERAGING TIME (secs): $avgsecs\n";
print HDR "TIME MARK IS CENTERED ON AVERAGING INTERVAL\n";

$Nsamp_min = 3;
print HDR "MINIMUM NO. SAMPLES FOR AN AVERAGE: $Nsamp_min\n";

$missing = FindInfo($setupfile,'MISSING VALUE', ': ');
print HDR "MISSING NUMBER: $missing\n";

$frsrshutdown = FindInfo($setupfile,'RAD FRSR SHUTDOWN CONTROL', ': '); 
print HDR "RAD FRSR SHUTDOWN CONTROL: $frsrshutdown\n";

$frsrthreshold = FindInfo($setupfile,'RAD FRSR SHUTDOWN THRESHOLD', ': '); 
print HDR "RAD FRSR SHUTDOWN THRESHOLD: $frsrthreshold\n";

@strings = FindLines($setupfile, 'RAD COMMENTS:', 100 );
print HDR "RAD COMMENTS:\n";
if ( $#strings > 0 ){
	for($i=1; $i<=$#strings; $i++) { 
		if ( $strings[$i] =~ /^END/i ) {last}
		else { print HDR "$strings[$i]\n";}
	}
}

$Tabs = 273.15;  # absolute temperature at 0degC
print HDR "KELVIN CONVERSION: $Tabs\n";

print HDR "======
NSAMP -- Sample number
DATE -- sample time, UTC
SW = shortwave downwelling irradiance, W/m^2
STDSW = STDEV OF SW
LW = longwave downwelling irradiance, W/m^2
STDLW = STDEV OF LW
PIR = PIR thermopile voltage, millivolts
STDPIR = STDEV OF PIR
TCASE = PIR case temperature, degC
TDOME = PIR dome temperature, degC
TPCB = temperature on the RAD circuit board, degC
BATT = battery voltage less diode drop, volts
RSROFF = Command to RSR to standby, -1=no effect, 0=force standby, 1=operate.
========
nsamp yyyy MM dd hh mm ss    sw stdsw   lw stdlw     pir stdpir    tcase  tdome   tpcb  batt rsroff
";
close HDR;
system "cp $fnhdr $armpath";

#===========================
# OUTPUT DATA FILE
#===========================
$fnavg = $datapath . '/' . "rad_avg_".$str.".txt";
print"RAD AVERAGE OUTPUT FILE: $fnavg\n";
open(AVG, ">$fnavg") or die"OPEN AVG DATA FILE FAILS";	
print AVG "navg yyyy MM dd hh mm ss    sw stdsw   lw stdlw     pir stdpir    tcase  tdome   tpcb  batt rsroff\n";
close AVG;

# ============ DATA PROCESSING PARAMETERS ===========
$SampleFlag = 0;		# 0=standard   1=start at first sample time.

#====================
# OTHER GLOBAL VARIABLES
#====================
use constant YES => 1;
use constant NO => 0;

# ---- ROUTINE HASH VARIABLES --------
@VARS = ('pir', 'lw', 'tcase', 'tdome', 'sw','tpcb','batt');

ClearAccumulatorArrays();		# Prepare for averaging first record

##================
## WAIT FOR THE FIRST RECORD
## the record subroutine will return NO
## until the input updates itis time mark.
##==============
# system('rm tmp.dat');		# start fresh
while ( ReadNextRecord() == NO ) {}
AccumulateStats();

##=================
##FIRST SAMPLE TIME MARKS
##==============
($dt_samp, $dt1, $dt2) = ComputeSampleEndPoints ( now(), $avgsecs, $SampleFlag);
#printf"<<NEXT SAMPLE: dt_samp=%s, dt1=%s, dt2=%s>>\r\n", dtstr($dt_samp,'short'), dtstr($dt1,'short'), dtstr($dt2,'short');

$Nsamp=0;
#================
# BEGIN THE MAIN SAMPLING LOOP
# ===============
while ( 1 ) {
	#=====================
	# PROCESS ALL RECORDS IN AVG TIME
	#=====================
 	while ( 1 ) {
		#---READ NEXT RECORD (loop)---
		while ( ReadNextRecord() == NO ) {}
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
	$Nsamp++;
	
	ClearAccumulatorArrays();		# Prepare for averaging first record
	($dt_samp, $dt1, $dt2) = ComputeSampleEndPoints( $record{dt}, $avgsecs, 0);	#increment $dt1 and $dt2 
	#printf"NEXT SAMPLE: dt_samp=%s, dt1=%s, dt2=%s\r\n", dtstr($dt_samp,'short'), dtstr($dt1,'short'), dtstr($dt2,'short');
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
	
	my ($str, $cmd ,$dtrec, $Nfields, $ftmp);
	my @dat;
	my $flag = 0;
	my @dt;	

	##==================
	## WAIT FOR INPUT
	## Send out a prompt --
	## Loop checking for input, 5 sec
	## send another prompt
	##==================
	print"RAD--\n";
	chomp($str=<STDIN>);
	
	## COMMANDS
	if ( $str =~ /quit/i ) {print"QUIT RAD avg program\n"; exit 0 }
	
#========================
# DATA INPUT
#$WIR07,10/02/19,17:47:30, 175,   57.6, 468.00, 22.00, 21.00,   7.00, 25.8, 11.9
#$WIR07,10/02/19,17:47:30, 175,   57.6, 469.00, 23.00, 22.00,   8.00, 25.8, 11.9
#$WIR07,10/02/19,17:47:30, 175,   57.6, 470.00, 24.00, 23.00,   9.00, 25.8, 11.9
#$WIR07,10/02/19,17:47:30, 175,   57.r, 470.00, 24.00, 23.00,   9.00, 25.8, 11.9
#$WIR07,10/02/19,17:47:30, 175,   57.6, 470.00, 24..0, 23.00,   9.00, 25.8, 11.9
	if($str =~ /\$WIR/ )	{									# identifies a data string
 		#print "Before: $str\n";
		$str =~ s/^.*\$/\$/;									# remove leading stuff
 		#print "After: $str\n";
 		
 		$dtrec = dtstr2dt(substr($str,7,19));					# the time in the record # rt we don't read the time
		@dat = split(/[,\/:*]/, $str);							# parse the data record
 		#$i=0; for (@dat) { printf "%d %s\n",$i++, $_  } #test
 		
#@VARS = ('pir', 'lw', 'tcase', 'tdome', 'sw','tpcb','batt');
#==============================
		# 0 $WIR07		header
		# 1 10			year
		# 2 02			MM
		# 3 19			dd
		# 4 18			hh
		# 5 55			mm
		# 6 50			ss
		# 7  175		Nsamps
		# 8    56.1		pir
		# 9  468.31		lw
		# 10  22.41		tcase
		# 11  21.52		tdome
		# 12    6.98	sw
		# 13  25.9		tpcb
		# 14  11.9		batt
# ============================

		$Nfields = 14;
		if ( $#dat >= $Nfields -1 ) {          # PROCESS DOS OR UNIX
			#print"test245 dat[9] = $dat[9]\n";

			%record = (
				dt => now(),			# the actual record time is the DAQ time
				#v0 => looks_like_number($w[0]) && $w[0]>=0 && $w[0]<=5 ? $w[0]*$slope0 + $offset0 : -999,
				pir => looks_like_number($dat[8]) ? $dat[8] : $missing,
				lw => looks_like_number($dat[9]) ? $dat[9] : $missing,
				tcase => looks_like_number($dat[10]) ? $dat[10] : $missing,
				tdome => looks_like_number($dat[11]) ? $dat[11] : $missing,
				sw => looks_like_number($dat[12]) ? $dat[12] : $missing,
				tpcb => looks_like_number($dat[13]) ? $dat[13] : $missing,
				batt => looks_like_number($dat[14]) ? $dat[14] : $missing
			);
			
			#print"test255 lw = $record{lw}\n";
			#======================
			# CHECK ALL VARIABLES FOR BAD VALUES
			#======================
			if ( $record{pir} < -2048 || $record{pir} > 2048 ) { $record{pir} = $missing; }
			if ( $record{lw} < 100 || $record{lw} > 500 ) { $record{lw} = $missing; }
			if ( $record{tcase} < -10 || $record{tcase} > 50 ) { $record{tcase} = $missing; }  #v06
			if ( $record{tdome} < -10 || $record{tdome} > 50 ) { $record{tdome} = $missing; }  #v06
			if ( $record{sw} < -20 || $record{sw} > 2000 ) { $record{sw} = $missing; }
			if ( $record{tpcb} < 0 || $record{tpcb} > 50 ) { $record{tpcb} = $missing; }
			if ( $record{batt} < 0 || $record{batt} > 20 ) { $record{batt} = $missing; }
			
			
			$str = sprintf"RADRW %s   %.1f  %.1f   %.1f  %.2f %.2f  %.1f  %.1f",
			dtstr($record{dt},'ssv'), $record{sw},$record{lw},$record{pir},$record{tcase},
			$record{tdome},$record{tpcb},$record{batt};
			printf "<<%s>>\n",$str;
			return( YES );  # means we like the data here.
		}
	}
	return ( NO );
}

#*************************************************************/
sub ClearAccumulatorArrays
# CLEAR ACCUMULATOR ARRAYS FOR ALL AVERAGING
# varnames = str2mat('drum','org','kt15','bb2t3','bb2t2','bb2t1','bb1t3','bb1t2','bb1t1');
# varnames = str2mat(varnames,'Vpwr','wintemp','tt8temp','sw1','sw2','pitch','roll','kttemp','pnitemp');  %v2
# varnames = str2mat(varnames,'bb1ap1', 'bb1bb2ap','bb2ap3','kttempcase'); % v3
# nvars = length(varnames(:,1));
# Zeros global hash variable %sum_xx(sum, sumsq, n, min, max) where
#  xx = (drum, kt, bb2t3, bb2t2, bb2t1, bb1t3, bb1t2, bb1t1, Vref, bb1ap1, bb1bb2ap2, bb2ap3, kttempcase,
#	wintemp, tt8temp, Vpwr, sw1, sw2, pitch, roll, sog, cog, az, pnitemp, lat, lon, sog, var, kttemp )
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
			stats1 ( \$sum_\%s{sum},  \$sum_\%s{sumsq},  \$sum_\%s{n},  \$sum_\%s{min},  \$sum_\%s{max}, \$Nsamp_min, \$missing);",
			$_,$_,$_,$_,$_,$_,$_,$_,$_,$_);
		eval $zz ;
	}
}
	
#*************************************************************/
sub SaveStats
{
	my ($dt, $path) = @_;
		
	# On print out the last number will be -1 no action, 0 SW < thershold, 1 SW >= threshold
	my $i;
	if( $frsrshutdown && $samp_sw{mn} > -100 ) {					# frsr flag true and valid SW
		if ( $samp_sw{mn} < $frsrthreshold ) 	{$i = 0}
		else 									{$i = 1}
	} else {$i = -1}

	my $str = sprintf "%d %s   %.1f %.1f   %.1f %.1f   %.1f %.1f   %.3f %.3f   %.3f %.1f %d",
		$Nsamp, dtstr($dt,'ssv'), $samp_sw{mn},$samp_sw{std}, $samp_lw{mn}, $samp_lw{std}, $samp_pir{mn}, $samp_pir{std}, 
		$samp_tcase{mn}, $samp_tdome{mn}, $samp_tpcb{mn}, $samp_batt{mn}, $i;
		
	## WRITE DATA TO OUTPUT FILE
	open(F, ">>$fnavg") or die("Can't open out file\n");
	print F "$str\n";
	close(F);
	
	# ARM AVG FILE
	my @w = datevec($dt_samp);
	my $fnarm = "$armpath/rad_avg_".sprintf("%4d%02d%02d%02d",$w[0],$w[1],$w[2],$w[3]).".txt";
	if ( ! -f $fnarm ) {
		open(FA, ">$fnarm") or die;
		print FA "nsamp yyyy MM dd hh mm ss    sw stdsw   lw stdlw     pir stdpir    tcase  tdome   tpcb  batt  rsroff\n";
	} else {
		open(FA, ">>$fnarm") or die;
	}
	printf FA "%s\n", $str;
	close(FA);
	
	## PRINT OUTPUT LINE IN EXPECT FORMAT
	print "<<RADAV $str>>\n";
}
