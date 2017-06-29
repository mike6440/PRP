#!/usr/bin/perl -w
my $PROGRAMNAME = 'avgadc.pl (PRP)';
my $VERSION = '02';  
my $EDITDATE = '130524';
#v02 add Scalar::Util 


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

#my $x = '34.5c';
#my $y = looks_like_number($x) ? $x*2 : -999;
#print"y = $y\n";
#exit 0;

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
print "RT OUT PATH = $datapath\n";
# ARM OUT PATH
my $armpath = $ENV{DAQFOLDER}."/ARM";
if ( ! -d $armpath ) { print"!! ARM RT OUT PATH - ERROR, $armpath\n"; die }
print "ARM RT OUT PATH = $armpath\n";

my $pgmstart = now();

#========================
# OPEN THE HEADER FILE
#========================
$str = dtstr($pgmstart,'iso');
my $fnhdr = "$datapath/adc_hdr.txt";
print"OUTPUT HEADER FILE: $fnhdr\n";
open HDR,">$fnhdr" or die"OPEN HEADERFILE FAILS";
print HDR "===============================================================================\n";

print HDR "PROGRAM: $PROGRAMNAME (Version $VERSION, Editdate $EDITDATE)\n";
print HDR "RUN TIME: ". dtstr($pgmstart) . " utc\n";							# v04

my $avgsecs = FindInfo($setupfile,'ADC AVERAGING TIME', ': ');   # v04
print HDR "ADC AVERAGING TIME (secs): $avgsecs\n";
print HDR "TIME MARK IS CENTERED ON AVERAGING INTERVAL\n";

$Nsamp_min = 3;
print HDR "MINIMUM NO. SAMPLES FOR AN AVERAGE: $Nsamp_min\n";

$missing = FindInfo($setupfile,'MISSING VALUE', ': ');
print HDR "MISSING NUMBER: $missing\n";

@strings = FindLines($setupfile, 'ADC COMMENTS:', 100 );
print HDR "ADC COMMENTS:\n";
if ( $#strings > 0 ){
	for($i=1; $i<=$#strings; $i++) { 
		if ( $strings[$i] =~ /^END/i ) {last}
		else { print HDR "$strings[$i]\n";}
	}
}

$name0 = FindInfo($setupfile,'CHAN0');
$slope0 = FindInfo($setupfile,'CHAN0 SLOPE');
$offset0 = FindInfo($setupfile,'CHAN0 OFFSET');
print HDR "CHAN0: $name0   SLOPE:$slope0,   OFFSET:$offset0\n";

$name1 = FindInfo($setupfile,'CHAN1');
$slope1 = FindInfo($setupfile,'CHAN1 SLOPE');
$offset1 = FindInfo($setupfile,'CHAN1 OFFSET');
print HDR "CHAN1: $name1   SLOPE:$slope1,   OFFSET:$offset1\n";

$name2 = FindInfo($setupfile,'CHAN2');
$slope2 = FindInfo($setupfile,'CHAN2 SLOPE');
$offset2 = FindInfo($setupfile,'CHAN2 OFFSET');
print HDR "CHAN2: $name2   SLOPE:$slope2,   OFFSET:$offset2\n";

$name3 = FindInfo($setupfile,'CHAN3');
$slope3 = FindInfo($setupfile,'CHAN3 SLOPE');
$offset3 = FindInfo($setupfile,'CHAN3 OFFSET');
print HDR "CHAN3: $name3   SLOPE:$slope3,   OFFSET:$offset3\n";

$name4 = FindInfo($setupfile,'CHAN4');
$slope4 = FindInfo($setupfile,'CHAN4 SLOPE');
$offset4 = FindInfo($setupfile,'CHAN4 OFFSET');
print HDR "CHAN4: $name4   SLOPE:$slope4,   OFFSET:$offset4\n";

$name5 = FindInfo($setupfile,'CHAN5');
$slope5 = FindInfo($setupfile,'CHAN5 SLOPE');
$offset5 = FindInfo($setupfile,'CHAN5 OFFSET');
print HDR "CHAN5: $name5   SLOPE:$slope5,   OFFSET:$offset5\n";

$name6 = FindInfo($setupfile,'CHAN6');
$slope6 = FindInfo($setupfile,'CHAN6 SLOPE');
$offset6 = FindInfo($setupfile,'CHAN6 OFFSET');
print HDR "CHAN6: $name6   SLOPE:$slope6,   OFFSET:$offset6\n";

$name7 = FindInfo($setupfile,'CHAN7');
$slope7 = FindInfo($setupfile,'CHAN7 SLOPE');
$offset7 = FindInfo($setupfile,'CHAN7 OFFSET');
print HDR "CHAN7: $name7   SLOPE:$slope7,   OFFSET:$offset7\n";

print HDR "VARIABLES
======
nrec - record counter
yyyy - sample time gmt year
MM - month
dd - day
hh - hour
mm - minute
ss - second
$name0 - total irradiance (W/m^2)
$name1 - diffuse irradiance (W/m^2)
$name2 - voltage (volts)
$name3 - voltage (volts)
$name4 - voltage (volts)
$name5 - voltage (volts)
$name6 - voltage (volts)
$name6 - voltage (volts)
======
\n";
close HDR;
system "cp $fnhdr $armpath";

#===========================
# OUTPUT DATA FILE
#===========================
$fnavg = $datapath . '/' . "adc_avg_".$str.".txt";
print"OUTPUT ADC AVG FILE: $fnavg\n";
open(AVG, ">$fnavg") or die"OPEN AVG DATA FILE FAILS";	
print AVG "nrec yyyy MM dd hh mm ss total stdtotal diffuse stddiffuse \n";
close AVG;

# ============ DATA PROCESSING PARAMETERS ===========
$SampleFlag = 0;		# 0=standard   1=start at first sample time.

#====================
# OTHER GLOBAL VARIABLES
#====================
use constant YES => 1;
use constant NO => 0;

# ---- ROUTINE HASH VARIABLES --------
@VARS = ('v0','v1','v2','v3','v4','v5','v6','v7');

# CLEAR ACCUMULATOR ARRAYS
ClearAccumulatorArrays();		# Prepare for averaging first record

# WAIT FOR THE FIRST RECORD -- the process is in hold until the first good record come in.
$nrec=0;
while ( ReadNextRecord() == NO )	{}
AccumulateStats();

##=================
## SAMPLE TIME MARKS
##==============
($dt_samp, $dt1, $dt2) = ComputeSampleEndPoints ( now(), $avgsecs, $SampleFlag);
printf"NEXT SAMPLE: dt_samp=%s, dt1=%s, dt2=%s\r\n", dtstr($dt_samp,'short'), dtstr($dt1,'short'), dtstr($dt2,'short');

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
	printf"NEXT SAMPLE: dt_samp=%s, dt1=%s, dt2=%s\r\n", dtstr($dt_samp,'short'), dtstr($dt1,'short'), dtstr($dt2,'short');
	AccumulateStats(); 			# deals with the current record
	#=======================
	# END OF THE LOOP
	#=======================
}
exit(0);





#*************************************************************/
# for testing
#ADCRAW +1.4068 +0.2239 +0.6365 +0.5895 +0.8417 +0.7794 +0.7221 +0.6691
#  ADC  +1.4068 +0.2239 +0.6366 +0.5898 +0.7420 +0.6796 +0.5222 +0.6711
#  ADC  +1.4068 g0.2239 +0.6366 +0.5898 +0.7420 +0.6796 +0.5222 +0.6711  -- contains an error
#  ADC  +12.4068 g0.2239 +0.6366 +0.5898 -0.7420 +0.6796 +0.5222 +0.6711  -- contains an error
sub ReadNextRecord
{
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
	print"ADC--\r\n";
	chomp($str=<STDIN>);
	## COMMANDS
	if ( $str =~ /quit/i ) {print"QUIT ADC avg program\n"; exit 0 }
	
	if($str =~ /ADC/ )	{					# identifies a data string
		# DECODE THE STRING AND RETURN VARIABLES
		#
		$str = substr($str,6);
		$str =~ s/\s+$//;
		$str =~ s/[+-]/ /g;
		$str =~ s/^\s+//;
		print"$str\n";
		@w=split(/[ ]/,$str);
		#foreach(@w){print"$_\n"}
		#@VARS = ('v0','v1','v2','v3','v4','v5','v6','v7');

		%record = (
			dt => now(),			# the actual record time is the DAQ time
			v0 => looks_like_number($w[0]) && $w[0]>=0 && $w[0]<=5 ? $w[0]*$slope0 + $offset0 : -999,
			v1 => looks_like_number($w[1]) && $w[1]>=0 && $w[1]<=5 ? $w[1]*$slope1 + $offset1 : -999,
			v2 => looks_like_number($w[2]) && $w[2]>=0 && $w[2]<=5 ? $w[2]*$slope2 + $offset2 : -999,
			v3 => looks_like_number($w[3]) && $w[3]>=0 && $w[3]<=5 ? $w[3]*$slope3 + $offset3 : -999,
			v4 => looks_like_number($w[4]) && $w[4]>=0 && $w[4]<=5 ? $w[4]*$slope4 + $offset4 : -999,
			v5 => looks_like_number($w[5]) && $w[5]>=0 && $w[5]<=5 ? $w[5]*$slope5 + $offset5 : -999,
			v6 => looks_like_number($w[6]) && $w[6]>=0 && $w[6]<=5 ? $w[6]*$slope6 + $offset6 : -999,
			v7 => looks_like_number($w[7]) && $w[7]>=0 && $w[7]<=5 ? $w[7]*$slope7 + $offset7 : -999,
		);
		
		# RAW: 233 2011 04 12 23 12 56 12.3 046 23.4 13.5 078 15.6 26.67 67.4
		$str = sprintf"ADCRW %d %s  %.1f  %.1f   %.4f %.4f %.4f %.4f %.1f %.4f",
			$nrec, dtstr($record{dt},'ssv'),$record{v0},$record{v1},$record{v2},$record{v3},$record{v4},$record{v5},$record{v6},$record{v7};
		printf "<<%s>>\r\n",$str;
		$nrec++;
		return( YES );  # means we like the data here.
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
	#=====================
	foreach ( @VARS ) {
		my $zz = sprintf( "( \$samp_\%s{mn}, \$samp_\%s{std}, \$samp_\%s{n}, \$samp_\%s{min}, \$samp_\%s{max}) =
			stats1 ( \$sum_\%s{sum},  \$sum_\%s{sumsq},  \$sum_\%s{n},  \$sum_\%s{min},  \$sum_\%s{max}, \$Nsamp_min,\$missing );",
			$_,$_,$_,$_,$_,$_,$_,$_,$_,$_);
		eval $zz ;
	}
}
	


#*************************************************************/
#@VARS = ('v0','v1','v2','v3','v4','v5','v6','v7');
sub SaveStats
{
	my $timestr = dtstr($dt_samp,'ssv');
	
	## DATA RECORD
	my $str = sprintf "%d %s  %.1f %.1f     %.1f %.1f", $Nsamp, $timestr, $samp_v0{mn}, $samp_v0{std},  $samp_v1{mn}, $samp_v1{std};
	
	## AVG DATA FILE
	open(F, ">>$fnavg") or die("Can't open out file\n");  # v03 
	printf F "%s\n", $str;
	close(F);
	
	# ARM AVG FILE
	my @w = datevec($dt_samp);
	my $fnarm = "$armpath/adc_avg_".sprintf("%4d%02d%02d%02d",$w[0],$w[1],$w[2],$w[3]).".txt";
	if ( ! -f $fnarm ) {
		open(FA, ">$fnarm") or die;
		print FA "nrec yyyy MM dd hh mm ss total stdtotal diffuse stddiffuse \n";
	} else {
		open(FA, ">>$fnarm") or die;
	}
	printf FA "%s\n", $str;
	close(FA);
	
	## PRINT OUTPUT LINE IN EXPECT FORMAT
	printf "<<ADCAV %s>>\n", $str;
}



