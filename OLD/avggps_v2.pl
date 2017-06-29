#!/usr/bin/perl -w
my $PROGRAMNAME = 'avggps.pl';
my $VERSION = '02';  
my $EDITDATE = '130524';
#v01 -- taken from avgrad.pl
#v02 -- file output with spaces and labeled for R
#v03 -- new output file names with jday
#v04 -- improve file handling.
#v05 -- new file names
#v06 add Scalar::Util 
#		remove NEXT SAMPLE prints

#====================
# PRE-DECLARE SUBROUTINES
#====================
use lib $ENV{DAQLIB};
print"USING LIBRARY AT $ENV{DAQLIB}\n";
use perltools::MRtime;
use perltools::MRstatistics;
use perltools::MRutilities;
use perltools::MRsensors;
use POSIX;
use Scalar::Util qw(looks_like_number);


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
print"RT OUT PATH = $datapath\n";
# ARM OUT PATH
my $armpath = $ENV{DAQFOLDER}."/ARM";
if ( ! -d $armpath ) { print"!! ARM RT OUT PATH - ERROR, $armpath\n"; die }
print "ARM RT OUT PATH = $armpath\n";

my $pgmstart = now();

#========================
# OPEN THE HEADER FILE
#========================
$str = dtstr($pgmstart,'iso');
my $fnhdr = "$datapath/gps_hdr.txt";
print"OUTPUT HEADER FILE: $fnhdr\n";
open HDR,">>$fnhdr" or die"OPEN HEADERFILE FAILS";
print HDR "=======================================================\n";

print HDR "PROGRAM: $PROGRAMNAME (Version $VERSION, Editdate $EDITDATE)\n";
print HDR "RUN TIME: ". dtstr($pgmstart) . " utc\n";							# v04

print HDR "SETUPFILE: $setupfile\n";
my $avgsecs = FindInfo($setupfile,'GPS AVERAGING TIME', ': ');   # v04
print HDR "GPS AVERAGING TIME (secs): $avgsecs\n";
print HDR "TIME MARK IS CENTERED ON AVERAGING INTERVAL\n";

$Nsamp_min = 3;
print HDR "MINIMUM NO. SAMPLES FOR AN AVERAGE: $Nsamp_min\n";

$missing = FindInfo($setupfile,'MISSING VALUE', ': ');
print HDR "MISSING NUMBER: $missing\n";

@strings = FindLines($setupfile, 'GPS COMMENTS:', 100 );
print HDR "GPS COMMENTS:\n";
if ( $#strings > 0 ){
	for($i=1; $i<=$#strings; $i++) { 
		if ( $strings[$i] =~ /^END/i ) {last}
		else { print HDR "$strings[$i]\n";}
	}
}
print HDR "======
NSAMP -- AVG RECORD COUNTER
DATE -- sample time, UTC
LAT = LATITUDE IN DECIMAL DEGREES, N+, S-
LON = LONGITUDE IN DECIMAL DEGREES, E+, W-
SOG = SPEED OVER GROUND, M/S
COG = COURSE OVER GROUND, DEG TRUE
VAR = MAGNETIC VARIATION, E+, W-
======
nsamp yyyy MM dd hh mm ss lat lon sog cog var\n";
close HDR;
system "cp $fnhdr $armpath";

#===========================
# OUTPUT DATA FILE
#===========================
$fnavg = $datapath . '/' . "gps_avg_".$str.".txt";
print"AVG GPS OUT FILE: $fnavg\n";
open(AVG, ">$fnavg") or die"OPEN AVG DATA FILE FAILS";	
print AVG "navg yyyy MM dd hh mm ss lat lon sog cog var\n";
close AVG;

# ============ DATA PROCESSING PARAMETERS ===========
$SampleFlag = 0;		# 0=standard   1=start at first sample time.

#====================
# OTHER GLOBAL VARIABLES
#====================
use constant YES => 1;
use constant NO => 0;

# $GPRMC,183004,A,4736.2051,N,12217.2880,W,000.1,029.0,210210,018.1,E*6D

# ---- ROUTINE HASH VARIABLES --------
@VARS = ('xlat','ylat','xlon','ylon','xcog','ycog','sog','var');

# CLEAR ACCUMULATOR ARRAYS
ClearAccumulatorArrays();		# Prepare for averaging first record

# WAIT FOR THE FIRST RECORD -- the process is in hold until the first good record come in.
while ( ReadNextRecord() == NO ) {}
AccumulateStats();

##=================
## SAMPLE TIME MARKS
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
		while ( ReadNextRecord() == NO )	{}
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
	$Nsamp++;
	SaveStats();
	
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
#$GPRMC,141159,A,4736.2171,N,12217.2163,W,000.0,188.0,190812,018.1,E*65
#$GPRMC,141204,A,4736.2171,N,12217.2162,W,000.0,188.0,190812,018.1,E*6F
#$GPRMC,141209,A,4736.2170,N,12217.2162,W,000.1,188.0,190812,018.1,E*62
#$GPRMC,141209,A,47r6.2170,N,12217.2162,W,000.1,188.0,190812,018.1,E*62 -- contains an error
sub ReadNextRecord
{
	my ($str, $cmd ,$dtrec, $Nfields, $ftmp);
	my @dat;
	my $flag = 0;
	my @dt;	

	## WAIT FOR INPUT
	print"GPS--\r\n";
	chomp($str=<STDIN>);
	
	## COMMANDS
	if ( $str =~ /quit/i ) {print"QUIT GPS avg program\n"; exit 0 }
	
	#========================
	# DATA INPUT
	#@VARS = ('xlat','ylat','xlon','ylon','xcog','ycog','sog','var');
	#$GPRMC,190824,A,4736.2032,N,12217.2883,W,000.1,209.1,210210,018.1,E*62

	if($str =~ /\$GPRMC/ )	{					# identifies a data string
		$str =~ s/^.*\$/\$/;				# remove leading stuff
		
		# DECODE THE STRING AND RETURN VARIABLES
 		($dtgps, $lat, $lon, $sog, $cog, $var) = gprmc($str,$missing);
 		print "lat, lon, sog, cog, var = $lat, $lon, $sog, $cog, $var\n";
		
		my($xc,$yc) = VecP2V(1,$lat, $missing);
		#print"xc=$xc, yc=$yc\n";
		my($xp,$yp) = VecP2V(1,$lon, $missing);
		#print"xp=$xp, yp=$yp\n";
		my($xr,$yr) = VecP2V(1,$cog, $missing);
		#print"xr=$xr, yr=$yr\n";
		if ( $dtgps > 0 ) {          	# = $missing if the gps record is bad
			%record = (
				dt => now(),			# the actual record time is the DAQ time
				xlat => $xc,
				ylat => $yc,
				xlon => $xp,
				ylon => $yp,
				xcog => $xr,
				ycog => $yr,
				sog =>  $sog,
				var => $var
			);
						
			## RAW RT LINE
			# GPS RAW: 20061213-221214, 47.60003, -122.34567, 27.34,  28.4, 23.2, 20061213-221214, 47.60003
			$str = sprintf"GPSRW %s   %.5f %.5f   %.2f %.1f   %4.1f   %s",
				dtstr($record{dt},'ssv'), $lat, $lon, $sog, $cog, $var, dtstr($dtgps,'short');
			printf "<<%s>>\r\n",$str;
			return( YES );  # means we like the data here.
		}
	}
	return ( NO );
}


#*************************************************************/
sub ClearAccumulatorArrays
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
{
	my ($x, @a) = @_;
	my %r = @a;
	#printf("Accum : %.5f\n", $x);
	if ( $x > $missing )
	{
		$r{sum} += $x;
		$r{sumsq} += $x * $x;
		$r{n}++;
		$r{min} = minvalue($r{min}, $x);
		$r{max} = maxvalue($r{max}, $x);
		@a = %r;
	}
	return( @a );
}

#*************************************************************/
sub ComputeStats
{
	my $i;
	my ($mean, $stdev, $n, $x, $xsq);
	
	#====================
	# SCALARS
	# sub (mn, stdpcnt, n, min, max) = stats1(sum, sumsq, N, min, max, Nsamp_min);
	#=====================
	foreach ( @VARS ) {
		my $zz = sprintf( "( \$samp_\%s{mn}, \$samp_\%s{std}, \$samp_\%s{n}, \$samp_\%s{min}, \$samp_\%s{max}) =
			stats1 ( \$sum_\%s{sum},  \$sum_\%s{sumsq},  \$sum_\%s{n},  \$sum_\%s{min},  
			\$sum_\%s{max}, \$Nsamp_min,\$missing );",
			$_,$_,$_,$_,$_,$_,$_,$_,$_,$_);
		eval $zz ;
	}
}
	


#*************************************************************/
sub SaveStats
{
	my $timestr = dtstr($dt_samp,'ssv');
		
	my ($xf, $lat, $lon, $cog);	
	($xf,$lat) = VecV2P($samp_xlat{mn}, $samp_ylat{mn}, $missing);
	if($lat > 180){$lat -= 360 }
	
	($xf,$lon) = VecV2P($samp_xlon{mn}, $samp_ylon{mn}, $missing);
	if($lon > 180){$lon -= 360 }
	($xf,$cog) = VecV2P($samp_xcog{mn}, $samp_ycog{mn}, $missing);
	
	## WRITE DATA TO OUTPUT FILE
	my $str = sprintf "%d %s  %8.5f  %9.5f  %5.2f  %5.1f  %4.1f",
		$Nsamp, $timestr, $lat, $lon, $samp_sog{mn}, $cog, $samp_var{mn};

	## WRITE DATA TO OUTPUT FILE
	open(F, ">>$fnavg") or die("Can't open out file\n");  # v03 
	printf F  "$str\n";
	close(F);
	
	# ARM AVG FILE
	my @w = datevec($dt_samp);
	my $fnarm = "$armpath/gps_avg_".sprintf("%4d%02d%02d%02d",$w[0],$w[1],$w[2],$w[3]).".txt";
	if ( ! -f $fnarm ) {
		open(FA, ">$fnarm") or die;
		print FA "nsamp yyyy MM dd hh mm ss lat lon sog cog var\n";
	} else {
		open(FA, ">>$fnarm") or die;
	}
	printf FA "%s\n", $str;
	close(FA);
	
	## PRINT OUTPUT LINE IN EXPECT FORMAT
	print "<<GPSAV,$str>>\n";
}

