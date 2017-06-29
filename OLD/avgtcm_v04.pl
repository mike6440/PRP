#!/usr/bin/perl -w
my $PROGRAMNAME = 'avgtcm.pl';
my $VERSION = '04';  
my $EDITDATE = '130524';
#v04 use Scalar::Util qw(looks_like_number);

#====================
# PRE-DECLARE SUBROUTINES
#====================
use lib $ENV{DAQLIB};
use perltools::MRtime;
use perltools::MRstatistics;
use perltools::MRutilities;
use POSIX;
use Scalar::Util qw(looks_like_number);

#v0 => looks_like_number($w[0]) && $w[0]>=0 && $w[0]<=5 ? $w[0]*$slope0 + $offset0 : -999,


my $setupfile = shift();
print "SETUPFILE = $setupfile ";
if ( -f $setupfile ) {print"EXISTS.\n"}
else { 
	print"DOES NOT EXIST. STOP.\n";
	exit 1;
}


# DEFINE OUT PATH
my $outpath =  FindInfo($setupfile,'RT OUT PATH', ': ');
if ( ! -d $outpath ) { print"!! RT OUT PATH - ERROR, $outpath\n"; die }
print"RT OUT PATH = $outpath\n";
# ARM OUT PATH
my $armpath =  $ENV{DAQFOLDER}."/ARM";
if ( ! -d $armpath ) { print"!! ARM RT OUT PATH - ERROR, $armpath\n"; die }
print "ARM RT OUT PATH = $armpath\n";

my $pgmstart = now();

#========================
# OPEN THE HEADER FILE
#========================
$str = dtstr($pgmstart,'iso');
my $fnhdr = "$outpath/tcm_hdr.txt";
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
NSAMP = sample counter
yyyy MM dd hh mm ss -- sample time, UTC
FGAZ = FLUX GATE COMPASS AZIMUTH, DEGM
PITCH = PITCH, + NOSE UP, DEG
PSTD = STANDARD DEV OF PITCH, DEG
ROLL = ROLL, + PORT UP, DEG
RSTD = STANDARD DEV OF ROLL, DEG
XMAG = MAGNETIC FIELD IN X DIR
YMAG = MAGNETIC FIELD IN Y DIR
ZMAG = MAGNETIC FIELD IN Z DIR
TTCM = SENSOR TEMPERATURE, DEG C
======
nsamp yyyy MM dd hh mm ss fgaz pitch pstd roll rstd xmag ymag zmag ttcm\n";

close HDR;
system "cp $fnhdr $armpath";

#===========================
# OUTPUT DATA FILE
#===========================
$fnavg = $outpath . '/' . "tcm_avg_".$str.".txt";
print"TCM AVERAGE OUTPUT FILE: $fnavg\n";
open(AVG, ">$fnavg") or die"OPEN AVG DATA FILE FAILS";	
print AVG "nsamp yyyy MM dd hh mm ss fgaz pitch pstd roll rstd xmag ymag zmag ttcm\n";
close AVG;

# ============ DATA PROCESSING PARAMETERS ===========
$SampleFlag = 0;		# 0=standard   1=start at first sample time.

#====================
# OTHER GLOBAL VARIABLES
#====================
use constant YES => 1;
use constant NO => 0;

# $HCHDM,310.0,MP5.4R0.1X7.75Y15.11Z51.87T25.6*2D

# ---- ROUTINE HASH VARIABLES --------
@VARS = ('az','pitch','roll','xmag','ymag','zmag','ttcm');

# CLEAR ACCUMULATOR ARRAYS
ClearAccumulatorArrays();		# Prepare for averaging first record

# WAIT FOR THE FIRST RECORD -- the process is in hold until the first good record come in.
while ( ReadNextRecord() == NO ) {}
AccumulateStats();

##=================
## SAMPLE TIME MARKS
##==============
($dt_samp, $dt1, $dt2) = ComputeSampleEndPoints ( now(), $avgsecs, $SampleFlag);
#printf"NEXT SAMPLE: dt_samp=%s, dt1=%s, dt2=%s\r\n", dtstr($dt_samp,'short'), dtstr($dt1,'short'), dtstr($dt2,'short');


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
	
	#=======================
	# WRITE OUTPUT AVG DATA RECORD
	#=======================
	## WRITE DATA TO OUTPUT FILE
	$str = sprintf "%d %s %.1f %.1f %.1f %.1f %.1f %.3f %.3f %.3f %.1f",
		$Nsamp, dtstr($dt_samp,'ssv'), $samp_az{mn}, $samp_pitch{mn}, $samp_pitch{std},
		$samp_roll{mn}, $samp_roll{std}, $samp_xmag{mn}, $samp_ymag{mn}, $samp_zmag{mn},
		$samp_ttcm{mn};
	# AVG FILE
	open(F, ">>$fnavg") or die("Can't open out file\n");  # v03 
	print F "$str\n";
	close(F);
	# ARM AVG FILE
	my @w = datevec($dt_samp);
	my $fnarm = "$armpath/tcm_avg_".sprintf("%4d%02d%02d%02d",$w[0],$w[1],$w[2],$w[3]).".txt";
	if ( ! -f $fnarm ) {
		open(FA, ">$fnarm") or die;
		print FA "nsamp yyyy MM dd hh mm ss fgaz pitch pstd roll rstd xmag ymag zmag ttcm\n";
	} else {
		open(FA, ">>$fnarm") or die;
	}
	print FA "$str\n";
	close(FA);
	
	## PRINT OUTPUT LINE IN EXPECT FORMAT
	print "<<TCMAV $str>>\n";
	
	ClearAccumulatorArrays();		# Prepare for averaging first record
	($dt_samp, $dt1, $dt2) = ComputeSampleEndPoints( $record{dt}, $avgsecs, 0);	#increment $dt1 and $dt2 
	#v4 printf"NEXT SAMPLE: dt_samp=%s, dt1=%s, dt2=%s\r\n", dtstr($dt_samp,'short'), dtstr($dt1,'short'), dtstr($dt2,'short');
	AccumulateStats(); 			# deals with the current record
}
exit(0);
#*************************************************************/
#$C122.3P0.2R-1.5X-8.72Y-14.76Z47.53T20.5*42
#$C122.9P0.2R-1.7X-8.73Y-14.77Z47.51T20.5*48
#$C122.4P0.2R-1.5X-8.73Y-14.75Z47.54T20.5*40
#$C122.4P0.2xR-1.5X-8.73Y-14.75Z47.54T20.5*40 -- error
sub ReadNextRecord
{
	my ($str, $cmd ,$dtrec, $Nfields, $ftmp);
	my @dat;
	my $flag = 0;
	my @dt;	

	## WAIT FOR INPUT
	print"TCM--\r\n";
	chomp($str=<STDIN>);
	
	#print"str = $str\n";
	## COMMANDS
	if ( $str =~ /quit/i ) {print"QUIT TCM avg program\n"; exit 0 }
	
	#========================
	# DATA INPUT
	#@VARS = ('az','pitch','roll','xmag','ymag','zmag','ttcm');
	#$HCHDM,310.0,MP5.4R0.1X7.75Y15.11Z51.87T25.6*2D
	if($str =~ /^\$C/ )	{				# identifies a data string
		$str =~ s/\$C//;				# remove leading stuff
		# DECODE THE STRING AND RETURN VARIABLES
		@w=split(/[\$C,MPRXYZT*]+/,$str);
		#foreach (@w){print "$_\n"}
		if ( $#w == 7 ) {          	# = $missing if the gps record is bad
			%record = (
				dt => now(),			# the actual record time is the DAQ time
				az => looks_like_number($w[0]) ? $w[0] : $missing,
				pitch => looks_like_number($w[1]) ? $w[1] : $missing,
				roll => looks_like_number($w[2]) ? $w[2] : $missing,
				xmag => looks_like_number($w[3]) ? $w[3] : $missing,
				ymag => looks_like_number($w[4]) ? $w[4] : $missing,
				zmag => looks_like_number($w[5]) ? $w[5] : $missing,
				ttcm => looks_like_number($w[6]) ? $w[6] : $missing,
			);
						
			## RAW RT LINE
			# TCMRW,
			$str = sprintf"TCMRW %s   %.1f  %.1f %.1f   %.2f %.2f %.2f   %.1f",
				dtstr($record{dt},'ssv'),$record{az},$record{pitch},$record{roll}
				,$record{xmag},$record{ymag},$record{zmag},$record{ttcm};
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
			stats1 ( \$sum_\%s{sum},  \$sum_\%s{sumsq},  \$sum_\%s{n},  \$sum_\%s{min},  \$sum_\%s{max}, \$Nsamp_min,\$missing );",
			$_,$_,$_,$_,$_,$_,$_,$_,$_,$_);
		eval $zz ;
	}
}


