#!/usr/bin/perl -w
my $PROGRAMNAME = 'avgspn.pl';
my $VERSION = '01';  
my $EDITDATE = '120420';
#v01 -- taken from avgrad.pl v04

#1 2012 04 22 19 11 51 >+1.3694+0.2179+0.5869+0.5478+0.7831+0.7308+0.6825+0.6378
#>+1.3694+0.2179+0.5908+0.5509+0.7880+0.7344+0.6850+0.6391

## CALL --- ./avgspn.pl rundatapath/su_yyyyMMddThhmmssZ.txt

# DATA INPUT
#$WIR07,10/02/19,17:47:30, 175,   57.6, 467.11, 22.14, 21.25,   7.11, 25.8, 11.9

my $setupfile = $ENV{RUNSETUPFILE};
print "SETUPFILE = $setupfile";
if (-f $setupfile) {print" EXISTS.\n"}
else {
	print " DOES NOT EXIST. STOP.\n";
	exit 1;
}


#====================
# PRE-DECLARE SUBROUTINES
#====================
use lib $ENV{MYLIB};
use perltools::MRtime;
use perltools::MRstatistics;
use perltools::MRutilities;
use POSIX;


print"\n======================== START PROCESSING $PROGRAMNAME =======================\n";

# DEFINE OUT PATH
my $outpath =  FindInfo($setupfile,'DATA OUTPUT PATH', ': ');
print"AVGSPN DATA OUT PATH = $outpath"; 
if (-d $outpath ) { print" - EXISTS.\n"}
else {print"-- DOES NOT EXIST. STOP\n"; die }
$Nsamp=0;
my $pgmstart = now();

#----------------- HEADER ----------------
$header = "PROGRAM: $PROGRAMNAME (Version $VERSION, Editdate $EDITDATE)
RUN TIME: " . dtstr(now()) . "utc
POINT OF CONTACT: Michael Reynolds, michael\@rmrco.com\n";

$expname = FindInfo($setupfile,'EXPERIMENT NAME', ': ');
$header = $header."EXPERIMENT NAME: $expname\n";

$isarsn = FindInfo($setupfile,'SPN SERIAL NUMBER', ': ');
$header = $header."SPN SERIAL NUMBER: $isarsn\n";

$header = $header."SPN-RT OUT PATH: $outpath\n";

$location = FindInfo($setupfile,'GEOGRAPHIC LOCATION', ': ');
$header = $header."GEOGRAPHIC LOCATION: $location\n";

$platform = FindInfo($setupfile,'PLATFORM NAME', ': ');
$header = $header."PLATFORM NAME: $platform\n";

$side_location = FindInfo($setupfile,'LOCATION ON PLATFORM', ': ');
$header = $header."LOCATION ON PLATFORM: $side_location\n";

$avgsecs = FindInfo($setupfile,'SPN AVERAGING TIME', ': ');
$header = $header."SPN AVERAGING TIME (secs): $avgsecs\n";
$header = $header."TIME MARK IS CENTERED ON AVERAGING INTERVAL\n";

$Nsamp_min = 3;
$header = $header."MINIMUM NO. SAMPLES FOR AN AVERAGE: $Nsamp_min\n";


$missing = FindInfo($setupfile,'MISSING VALUE', ': ');
$header = $header."MISSING NUMBER: $missing\n";

@strings = FindLines($setupfile, 'SPN COMMENTS:', 100 );
$header = $header."COMMENTS:\n";
if ( $#strings > 0 ){
	for($i=1; $i<=$#strings; $i++) { 
		if ( $strings[$i] =~ /^END/i ) {last}
		else { $header = $header."$strings[$i]\n";}
	}
}

## PRINT OUT THE HEADER
#print"\n-------- HEADER ----------------\n$header\n";


# ============ DATA PROCESSING PARAMETERS ===========
$SampleFlag = 0;		# 0=standard   1=start at first sample time.

#====================
# OTHER GLOBAL VARIABLES
#====================
use constant YES => 1;
use constant NO => 0;
use constant PI => 3.14159265359;

# ---- ROUTINE HASH VARIABLES --------
@VARS = ('v0', 'v1','v2','v3','v4','v5','v6','v7');

ClearAccumulatorArrays();		# Prepare for averaging first record

# OPEN OUTPUT FILE
#===========================
# OUTPUT DATA FILE
#===========================
$fnavg = $outpath . '/' . "spn_avg_".dtstr($pgmstart,'iso').".txt";
print"OUTPUT ZENO AVG FILE: $fnavg\n";
open(AVG, ">$fnavg") or die"OPEN AVG DATA FILE FAILS";	
print AVG "nrec yyyy MM dd hh mm ss v0 v1 v2 v3 v4 v5 v6 v7 stdv0 stdv1 stdv2 stdv3 stdv4 stdv5 stdv6 stdv7\n";
close AVG;




WriteHeaderFile($outpath, $pgmstart, $header);  #v02 v04

##================
## WAIT FOR THE FIRST RECORD
## the record subroutine will return NO
## until the input updates itis time mark.
##==============
# system('rm tmp.dat');		# start fresh
while ( ReadNextRecord($outpath) == NO ) {}

AccumulateStats();

##=================
##FIRST SAMPLE TIME MARKS
##==============
my ($dt_samp,$dt1,$dt2);
($dt_samp, $dt1, $dt2) = ComputeSampleEndPoints ( now(), $avgsecs, $SampleFlag);

#================
# BEGIN THE MAIN SAMPLING LOOP
# ===============
while ( 1 ) {
	#=====================
	# PROCESS ALL RECORDS IN AVG TIME
	#=====================
 	while ( 1 ) {
		#---READ NEXT RECORD (loop)---
		while ( ReadNextRecord($outpath) == NO )	{}
		#---NEW RECORD, CHECK FOR END---
		if ( now() >= $dt2 ) { last; }
		else {
			AccumulateStats();
		}
	}
	#====================
	# COMPUTE SAMPLE STATS
	#====================
	ComputeStats();
	
	
	my $timestr = dtstr($dt_samp,'ssv');
	
	## WRITE DATA TO OUTPUT FILE
	open(F, ">>$fnavg") or die("Can't open out file\n");  # v03 
	printf F "%d %s %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f    %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f\n",
		$Nsamp, $timestr, $samp_v0{mn}, $samp_v1{mn}, $samp_v2{mn}, $samp_v3{mn}, $samp_v4{mn}, $samp_v5{mn}, $samp_v6{mn}, $samp_v7{mn},
		$samp_v0{std}, $samp_v1{std}, $samp_v2{std}, $samp_v3{std}, $samp_v4{std}, $samp_v5{std}, $samp_v6{std}, $samp_v7{std};
	close(F);
	## PRINT OUTPUT LINE IN EXPECT FORMAT
	printf "<<SPNAV %d %s %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f    %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f>>\r\n",
		$Nsamp, $timestr, $samp_v0{mn}, $samp_v1{mn}, $samp_v2{mn}, $samp_v3{mn}, $samp_v4{mn}, $samp_v5{mn}, $samp_v6{mn}, $samp_v7{mn},
		$samp_v0{std}, $samp_v1{std}, $samp_v2{std}, $samp_v3{std}, $samp_v4{std}, $samp_v5{std}, $samp_v6{std}, $samp_v7{std};
	$Nsamp++;
	
	ClearAccumulatorArrays();		# Prepare for averaging first record
	($dt_samp, $dt1, $dt2) = ComputeSampleEndPoints( now(), $avgsecs, 0);	#increment $dt1 and $dt2 
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
	#1 2012 04 22 19 11 51 >+1.3694+0.2179+0.5869+0.5478+0.7831+0.7308+0.6825+0.6378
	
	my ($outpath, $rawout) = @_;
	
	my ($str, $cmd ,$dtrec, $Nfields, $ftmp);
	my @d;
	my $flag = 0;
	my @dt;	
	
	##==================
	## WAIT FOR INPUT
	## Send out a prompt --
	## Loop checking for input, 5 sec
	## send another prompt
	##==================
	print"SPN--\n";
	chomp($str=<STDIN>);
	
	#print"str = $str\n";
	
	## COMMANDS
	if ( $str =~ /quit/i ) {print"QUIT SPN avg program\n"; exit 0 }
	
	#========================
	# DATA INPUT
	#0 2012 04 22 19 11 45 >+1.3694+0.2179+0.5857+0.5467+0.7816+0.7292+0.6812+0.6375
	#>+1.3694+0.2179+0.5864+0.5473+0.7828+0.7305+0.6812+0.6363
	if( ($str =~ />+/ || $str =~ />-/) && length($str) > 56 )	{									# identifies a data string
 		#print "Before: $str\n";
 		$str =~ s/\>//;
		$str =~ s/\+/ \+/g;									# remove leading stuff
		$str =~ s/\-/ \-/g;									# remove leading stuff
		$str =~ s/^\s+//;
		$str =~ s/\s+$//;
		#print "After: $str\n";
 		
		@d = split(/[ ]/, $str);							# parse the data record
 		#$i=0; for (@dat) { printf "%d %s\n",$i++, $_  } #test
		#@VARS = ('v0', 'v1','v2','v3','v4','v5','v6','v7');
		# 0 +1.3694
		# 1 +0.2179
		# 2 +0.5864
		# 3 +0.5473
		# 4 +0.7828
		# 5 +0.7305
		# 6 +0.6812
		# 7 +0.6363

		$Nfields = 7;
		if ( $#d >= $Nfields -1 ) {          # PROCESS DOS OR UNIX
			%record = (
				v0 => $d[0],
				v1 => $d[1],
				v2 => $d[2],
				v3 => $d[3],
				v4 => $d[4],
				v5 => $d[5],
				v6 => $d[6],
				v7 => $d[7]
			);
						
			#======================
			# CHECK ALL VARIABLES FOR BAD VALUES
			#======================
			if ( $record{v0} < -5 || $record{v0} > 5 ) { $record{v0} = $missing; }
			if ( $record{v1} < -5 || $record{v1} > 5 ) { $record{v1} = $missing; }
			if ( $record{v2} < -5 || $record{v2} > 5 ) { $record{v2} = $missing; }
			if ( $record{v3} < -5 || $record{v3} > 5 ) { $record{v3} = $missing; }
			if ( $record{v4} < -5 || $record{v4} > 5 ) { $record{v4} = $missing; }
			if ( $record{v5} < -5 || $record{v5} > 5 ) { $record{v5} = $missing; }
			if ( $record{v6} < -5 || $record{v6} > 5 ) { $record{v6} = $missing; }
			if ( $record{v7} < -5 || $record{v7} > 5 ) { $record{v7} = $missing; }
			
			
			## RAW RT LINE
			# SPNRW 2012 04 12 12 34 23 1.3694 0.2179 0.5864 0.5473 0.7828 -0.7305 -0.6812 0.6363
			$str = sprintf"<<SPNRW %s %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f>>\r\n", dtstr(now(),'ssv'), 
				$record{v0},$record{v1},$record{v2},$record{v3},$record{v4},$record{v5},$record{v6},$record{v7};
			print "$str\n";
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
{
	my ($d1, $d2, $ii);
	my ($x, $y, $s);
	
		#========================
		# SCALARS
		#========================
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
{
	my $i;
	my ($mean, $stdev, $n, $x, $xsq);
	
	#====================
	# SCALARS
	# sub (mn, stdpcnt, n, min, max) = stats(sum, sumsq, N, min, max, Nsamp_min);
	#=====================
	foreach ( @VARS ) {
		my $zz = sprintf( "( \$samp_\%s{mn}, \$samp_\%s{std}, \$samp_\%s{n}, \$samp_\%s{min}, \$samp_\%s{max}) =
			stats1 ( \$sum_\%s{sum},  \$sum_\%s{sumsq},  \$sum_\%s{n},  \$sum_\%s{min},  \$sum_\%s{max}, \$Nsamp_min, $missing);",
			$_,$_,$_,$_,$_,$_,$_,$_,$_,$_);
		eval $zz ;
	}
}
	
#*************************************************************/  v04 rename 
sub WriteHeaderFile
# WRITE A HEADER FILE WITH NAME: gpsyyMMdd.hdr based on $pgmstart time
{
	my ($outpath, $pgmstart, $header) = @_;  # v02  v04
		
	my $str = dtstr($pgmstart,'prp');
	my $fn = "spn".$str.".hdr";
	my $outfile= $outpath . '/' . $fn;
	open(HDR, ">>$outfile") or die;			# v02 v03
	print"header written to $outfile\n";
	print HDR "===============================================================================\n";
	print HDR "$header
========
nrec -- the record count of each average
yyyy MM dd hh mm ss -- sample time, UTC
v0, v1, ... v7 -- eight channels of the 4017 ADC
========
nrec yyyy MM dd hh mm ss v0 v1 v2 v3 v4 v5 v6 v7 stdv0 stdv1 stdv2 stdv3 stdv4 stdv5 stdv6 stdv7\n";

	close HDR;
}

