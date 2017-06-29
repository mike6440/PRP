#!/usr/bin/perl -w
#$GPRMC,235952,A,4922.9221,N,12418.9996,W,007.7,294.3,030609,019.2,E*60
#ProcGps.pl receives GPRMC strings from a GPS
#the input variables.
my $PROGRAMNAME = 'ProcGps.pl';
my $VERSION = '01';  
my $EDITDATE = '090927';

my $setupfile = shift();
#my $setupfile = 'setup/test_setup.txt';
if ( ! -f $setupfile ) {
	print"SETUP FILE $setupfile does NOT exist.  STOP.\n";
	exit 1;
}

#====================
# PRE-DECLARE SUBROUTINES
#====================
use Time::Local;
use Time::gmtime;
use POSIX;

@samp_Xcog=();
@samp_Xlon=();
@samp_lon=();
@samp_Ylon=();
@samp_var=();
@samp_Ycog=();


print"\n======================== START PROCESSING $PROGRAMNAME =======================\n";

# DEFINE OUT PATH
my $outpath =  FindInfo($setupfile,'DATA OUTPUT PATH', ': ');
if ( ! -d $outpath ) { print"!! DATA OUTPUT PATH ERROR, $outpath\n"; die }

## DEFINE OUT FILE
my $pgmstart = now();
my $str = dtstr($pgmstart,'date');
my $avgsecs = FindInfo($setupfile,'AVERAGING TIME SECS', ': ');
my $fnavout = "gps\_av$avgsecs\_$str.dat";
my $outfile= $outpath . '/' . $fnavout;

#----------------- HEADER ----------------
$header = "PROGRAM: $PROGRAMNAME (Version $VERSION, Editdate $EDITDATE)
RUN TIME: " . dtstr(now()) . "utc
POINT OF CONTACT: Michael Reynolds, michael\@rmrco.com\n";

$expname = FindInfo($setupfile,'EXPERIMENT NAME', ': ');
$header = $header."EXPERIMENT NAME: $expname\n";

$mn = FindInfo($setupfile,'GPS MODEL NUMBER', ': ');
$header = $header."GPS MODEL NUMBER: $mn\n";

$sn = FindInfo($setupfile,'GPS SERIAL NUMBER', ': ');
$header = $header."GPS SERIAL NUMBER: $sn\n";

$header = $header."DATA OUT PATH: $outpath\n";

$location = FindInfo($setupfile,'GEOGRAPHIC LOCATION', ': ');
$header = $header."GEOGRAPHIC LOCATION: $location\n";

$platform = FindInfo($setupfile,'PLATFORM NAME', ': ');
$header = $header."PLATFORM NAME: $platform\n";

$side_location = FindInfo($setupfile,'LOCATION ON PLATFORM', ': ');
$header = $header."LOCATION ON PLATFORM: $side_location\n";

$ht_above_sealevel = FindInfo($setupfile,'HEIGHT ABOVE SEA LEVEL', ': ');
$header = $header."HEIGHT ABOVE SEA LEVEL: $ht_above_sealevel\n";

# $avgsecs = FindInfo($setupfile,'AVERAGING TIME', ': ');
$header = $header."AVERAGING TIME (secs): $avgsecs\n";
$header = $header."TIME MARK IS CENTERED ON AVERAGING INTERVAL\n";

$missing = FindInfo($setupfile,'MISSING VALUE', ': ');
$header = $header."MISSING VALUE: $missing\n";

$Nsamp_min = FindInfo($setupfile,'GPS MIN SAMPLES FOR AVG', ': ');
$header = $header."GPS MIN SAMPLES FOR AVG: $Nsamp_min\n";

@strings = FindLines($setupfile, 'GPS COMMENTS', 100 );
$header = $header."GPS COMMENTS:\n";
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
#$GPRMC,235952,A,4922.9221,N,12418.9996,W,007.7,294.3,030609,019.2,E*60
@VARS = ('lat', 'lon', 'sog', 'cog', 'var', 'Xcog', 'Ycog', 'Xlon','Ylon');


# WAIT FOR THE FIRST SAMPLE -- to synchronize sample times
#REAL TIME OPERATION 
while ( ReadNextRecord() == NO ) {}

##=================
##FIRST SAMPLE TIME MARKS
##==============
my ($dt_samp,$dt1,$dt2);
($dt_samp, $dt1, $dt2) = ComputeSampleEndPoints ( $record{dt}, $avgsecs, $SampleFlag);
printf"<<GPS NEXT GPS AVG: dt_samp=%s, dt1=%s, dt2=%s>>\r\n", dtstr($dt_samp,'short'), dtstr($dt1,'short'), dtstr($dt2,'short');

#================
# OPEN OUT FILES
#================
OpenOutFile($outpath, $fnavout, $header);

#==================
# LOOP TO FIRST GOOD DATA RECORD
#=================
ClearAccumulatorArrays();	# Prepare for averaging first record
AccumulateStats();			# accumulate the first record
my $Nrecs = 1;				# number of records read in the time block
my $Nsamp=0;				# Nsamps = number of averages produced

#================
# BEGIN THE MAIN SAMPLING LOOP
# ===============
while ( 1 ) {
	#=====================
	# LOOP OVER ALL RECORDS IN AVG TIME
	#=====================
 	while ( 1 ) {
		#---READ NEXT RECORD (loop)---
		while ( ReadNextRecord() == NO )	{}
		#---NEW RECORD, CHECK FOR END---
		if ( $record{dt} >= $dt2) { last; }
		else {
			AccumulateStats();
			$Nrecs++;
		}
	}
	#====================
	# COMPUTE SAMPLE STATS
	#====================
	ComputeStats();
	SaveStats($dt_samp, $outpath, $fnavout);
	## PREPARE FOR THE NEXT AVERAGE
	ClearAccumulatorArrays();		# Prepare for averaging first record
	$Nrecs = 1;
	AccumulateStats(); 			# deals with the current record
	($dt_samp, $dt1, $dt2) = ComputeSampleEndPoints( $record{dt}, $avgsecs, 0);	#increment $dt1 and $dt2 
	printf"NEXT SAMPLE: dt_samp=%s, dt1=%s, dt2=%s\n", dtstr($dt_samp,'short'), dtstr($dt1,'short'), dtstr($dt2,'short');
	
	#=======================
	# END OF THE LOOP
	#=======================
}
exit(0);


#*************************************************************/
sub ReadNextRecord
#$GPRMC,235952,A,5000.0000,N,17900.0000,W,1.943,003,030609,019.2,E*60
#$GPRMC,235952,A,5000.0000,N,17900.0000,E,1.943,357,030609,019.2,E*60
{
	my ($str, $cmd ,$dtrec, $Nfields, $ftmp);
	my @dat;
	my $flag = 0;
	my @dt;
	my ($Xc,$Yc,$Xl,$Yl);
	my ($xlt, $xmn, $xln, $xvr);
		
	##==================
	## WAIT FOR INPUT
	## Send out a prompt --
	## Loop checking for input, 5 sec
	## send another prompt
	##==================
	print"$PROGRAMNAME--\n";
	chomp($str=<STDIN>);
	#print"str = $str\n";
	## COMMANDS
	if ( $str =~ /quit/i ) {print"QUIT $PROGRAMNAME\n"; exit 0 }
	
	#========================
	if($str =~ /^\$GPRMC/ )	{									# identifies a data string
	# print "Before: $str\n";
		$str =~ s/^.*\$/\$/;									# remove leading stuff
		@dat = split(/[,*]/, $str );							# parse the data record
 		#$i=0; for (@dat) { printf "%d %s\n",$i++, $_  } #test
		#==============================
		# 0 $GPRMC
		# 1 235952		hhmmss
		# 2 A			A=good, X=bad
		# 3 4922.9221	lat - ddmm.mmmm
		# 4 N			N/S hemisphere
		# 5 12418.9996	lon - ddmm.mmmm
		# 6 W			W/E hemisphere
		# 7 007.7		SOG kts
		# 8 294.3		COG true
		# 9 030609		ddMMyy
		# 10 019.2		var, deg
		# 11 E			E+, W-
		# 12 60			checksum, ignore
		# ============================
		$Nfields = 12;
		
		if ( $#dat >= $Nfields -1 ) {          # PROCESS DOS OR UNIX
			
			# CONVERT LON AND LAT TO DEGREES
			# VECTOR AVERAGE LON
			$xlt = int($dat[3]/100);  $xmn = ($dat[3] - $xlt*100)/60;
			$xlt = $xlt + $xmn;
			if ( $dat[4] =~ /S/ ) {$xlt = - $xlt}
			#
			$xln = int($dat[5]/100);  $xmn = ($dat[5] - $xln*100)/60;
			$xln = $xln + $xmn;
			if ( $dat[6] =~ /W/ ) {$xln = - $xln}
			
			# SOG/COG VECTOR AVERAGE
			($Xc,$Yc) = VecP2V($dat[7]*0.51444445,$dat[8], $missing);
			($Xl,$Yl) = VecP2V(1,$xln, $missing);

			$xvr = $dat[10];
			if ( $dat[11] =~ /W/ ) { $xvr = -$xvr}
			
		#@VARS = ('lat', 'lon', 'sog', 'cog', 'var', 'Xcog', 'Xcog', 'Xlon','Ylon');
			%record = (
				dt => now(),			# the actual record time is the DAQ time
				lat => $xlt,
				lon => $xln,
				sog => $dat[7] * 0.51444445,  # kts -> m/s
				cog => $dat[8],
				var => $xvr,
				Xcog => $Xc,
				Ycog => $Yc,
				Xlon => $Xl,
				Ylon => $Yl
			);
			
			
			
			#======================
			# CHECK ALL VARIABLES FOR BAD VALUES
			#======================
			if ( $record{lat} < -90 || $record{lat} > 90 ) { $record{lat} = $missing; }
			if ( $record{lon} < -180 || $record{lon} > 360 ) { $record{lon} = $missing; }
			if ( $record{sog} < 0 || $record{sog} > 40 ) { $record{sog} = $missing; }
			if ( $record{cog} < 0 || $record{cog} > 360 ) { $record{cog} = $missing; }
			if ( $record{var} < -50 || $record{var} > 50 ) { $record{var} = $missing; }
			if ( $record{Xcog} < -1 || $record{Xcog} > 1 ) { $record{Xcog} = $missing; }
			if ( $record{Ycog} < -1 || $record{Ycog} > 1 ) { $record{Ycog} = $missing; }
			if ( $record{Xlon} < -1 || $record{Xlon} > 1 ) { $record{Xlon} = $missing; }
			if ( $record{Ylon} < -1 || $record{Ylon} > 1 ) { $record{Ylon} = $missing; }
			
			## RAW RT LINE
			$str = sprintf"<<GPS GPSRAW,%s, %10.6f, %10.6f, %4.1f, %5.1f, %5.1f>>",
			dtstr($record{dt},'csv'), $record{lat}, $record{lon}, $record{sog},
			$record{cog}, $record{var};
			
			print "$str\n";

			return( YES );  # means we like the data here.
		}
	}
	return ( NO );
}

#*************************************************************/
sub OpenOutFile
#   DATE                Q   LAT  LON    SOG  COG  VAR  LONV  COGV
#2009,08,04,20,06,00,    1,   280.7,   4.8,   1.8,  -2.6,  21.7,    51.3,   0.0,   0.0,   0.0,   0.0
{
	my ($outpath, $avout, $header) = @_;

	# ==== AVG OUTPUT FILE ========
	my $outfile = "$outpath/$avout";
	open(OUT, ">$outfile") or die("Can't open out file\n"); 
	print OUT "RAW GPS DATA
$header
======================================================
DATE -- sample time, UTC
N -- average record count
Nsamp -- the number of samples that were used in the averages
LAT -- Mean latitude, +/- = N/S, f.p. degrees
LON -- Mean longitude, vector mean, +/- = E/W, f.p. degrees
SOG -- vector average SOG, m/s
COG - Course Made Good, vector average, degrees true
VAR -- Variation, +/- = E/W
LONAV -- longitude scalar average, fp deg
=============================
   DATE                 N  Nsamp    LAT  LON  SOG  COG  VAR  LONAV \n";
	close(OUT);
}



#*************************************************************/
sub ClearAccumulatorArrays
# CLEAR ACCUMULATOR ARRAYS FOR ALL AVERAGING
{	
	#=================
	#	SET UP THE HASHES
	#=================
	my %xx = ( sum => 0, sumsq => 0, n => 0, min => 1e99, max => -1e99 );
	my %yy = ( mn => $missing, std => $missing, n => 0, min => $missing, max => $missing );
	# ---- INITIALIZE HASHES -------
	foreach ( @VARS ) 
	{
		$str = "%sum_$_ = %xx;   %samp_$_ = %yy;";
		eval $str;
	}
}


#*************************************************************/
sub ComputeSampleEndPoints
# ($dt_samp, $dt1, $dt2) = ComputeSampleEndPoints($dtx, $avgsecs, $SampleFlag);
#
# Computes the time start and stop times for making an average.  Time is 
# expressed in seconds since 1970 by using the dtsecs() function.
#
#INPUT VARIABLES:
#  $dtx (=$record{dt}) is the current record time
#  $avgsecs = averaging time
#  $SampleFlag = 0/1
# 		There are two optons: either divide the day into even sample 
# 		periods of $avgsecs long (e.g. 0, 5, 10, ... min) or begin 
# 		precisely with the input sample.  The sample start parameter
# 		$SampleFlag is set for this option.
# OUTPUT (GLOBAL)
#  $dt_samp = the mid point of the sample interval
#  $dt1, $dt2 = current sample end points
# REQUIRED SUBROUTINES
#	datevec();
#	datesec();
#
# v101 060622 rmr -- begin tracking this subroutine.
# v101 060628 -- begin toolbox_avg
{
	my ($y, $M, $d, $h, $m, $s, $dt0);
	my $dt_samp = shift();
	my $avgsecs = shift();
	my $SampleFlag=shift();
	
	#$dt_samp = $record{dt};				# this is the time of the first sample.
	if ( $SampleFlag == 0 )
	{
		#==================
		# COMPUTE THE dt CURRENT BLOCK
		#==================
		($y, $M, $d, $h, $m, $s) = datevec( $dt_samp );
		$dt0 = datesec($y, $M, $d, 0, 0, 0) - $avgsecs/2;  # epoch secs at midnight
		$dt1 = $dt0 + $avgsecs * int( ($dt_samp - $dt0) / $avgsecs );	# prior sample block dtsec
	} 
	else { $dt1 = $dt_samp; }
	
	$dt2 = $dt1 + $avgsecs;			# next sample block dtsec
	$dt_samp = $dt1 + $avgsecs/2;  # the time of the current avg block
	return ($dt_samp, $dt1, $dt2);
}
#*************************************************************/
sub AccumulateStats
# Add to the sums for statistical averages
# accumulate in @sum_compass, @sum_pitch, ...
{
	#print"ACCUMULATE STATS\n"; #test
	
	my $str;
	
	#========================
	foreach ( @VARS )
	{
		$str = sprintf("\@s = %%sum_%s;  %%sum_%s = Accum (\$record{%s}, \@s);", $_, $_, $_);
		eval $str;
	}
	#print"sumXcog=$sum_Xcog{sum}, sumYcog=$sum_Ycog{sum}\n";
}

#*************************************************************/
sub Accum
# Accum(%hash, $datum);   global: $missing
{
	my ($x, @a) = @_;
	my %r = @a;
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
{
	my $i;
	my ($mean, $stdev, $n, $x, $xsq);
	
	#====================
	# SCALARS
	# sub (mn, stdpcnt, n, min, max) = stats(sum, sumsq, N, min, max, Nsamp_min);
	#=====================
	foreach ( @VARS ) 
	{
		my $zz = sprintf( "( \$samp_\%s{mn}, \$samp_\%s{std}, \$samp_\%s{n}, \$samp_\%s{min}, \$samp_\%s{max}) =
			stats ( \$sum_\%s{sum},  \$sum_\%s{sumsq},  \$sum_\%s{n},  \$sum_\%s{min},  \$sum_\%s{max}, \$Nsamp_min );",
			$_,$_,$_,$_,$_,$_,$_,$_,$_,$_);
		eval $zz ;
	}
}




#*************************************************************/
sub SaveStats
{
	my ($dt_samp, $outpath, $avfile) = @_;
	my $outfile = "$outpath/$avfile";
	#print "<<Outfile: $outfile>>\n";

	my $str;
	my ($i, $ii);
	my ($vec_cog, $vec_sog, $vec_lon, $dum);
	
	# VECTOR AVERAGED POLAR COMPONENTS
	# SOG/COG
	($vec_sog,$vec_cog) = VecV2P( $samp_Xcog{mn}, $samp_Ycog{mn}, $missing );
	if ( $vec_sog < 0.1 ) { $vec_cog = 0;}
	# LONGITUDE
	($dum,$vec_lon) = VecV2P( $samp_Xlon{mn}, $samp_Ylon{mn}, $missing );
	
	$Nsamp++;	
	#printf"Write AVG string: time = %s\n", dtstr($dt_samp,'csv');
	
	open(D,">>$outfile") or die("<<GPS WRITE TO AVG OUT FAILS>>\n");
	## OPERATION OUT
#   DATE                 N  Nsamp    LAT  LON  SOG  COG  VAR  LONV \n";
	$str = sprintf "%s,%5d,%5d,  %10.6f,%10.6f,%6.1f,%6.1f,%6.1f,%10.6f",
	dtstr($dt_samp,"csv"), $Nsamp, $samp_lat{n}, $samp_lat{mn}, $vec_lon, $vec_sog, $vec_sog, $samp_var{mn},
	$samp_lon{mn};
	
	print"<<GPS GPSAV,$str>>\r\n";
	print D "$str\n";
	
	close(D);

}




#*************************************************************/
#   TIME TOOLBOX
#*************************************************************/
#*************************************************************/
sub dtstr
# Convert epoch second to a time string
# CALL
#	$str = dtstr($dtsec, $format)
# INPUT
#	$dtsec = time since 1970 in secs.  Unix time command
#	$format = 	'long'  yyyy-MM-dd (jjj) hh:mm:ss
#				'short' yyMMdd, hhmmss
# v102 060622 rmr start toolbox cfg control
# v103 060627 rmr -- add long and short formats
# v104 061111 rmr -- added SCS format MM/dd/yyyy,hh:mm:ss,
# v05 070116 rmr -- use gmtime to avoid a time shift
# v06 090806 rmr -- add 'date' format, 'yyMMdd'
{
	my ($tm, $fmt);					# time hash
	my ($str, $n);					# out string
	
	$n = $#_;
	$tm = gmtime(shift);		# convert incoming epoch secs to hash
	# ==== DETERMINE THE FORMAT TYPE =============
	$fmt = 'long';	
	if ( $n >= 1 ) {  $fmt = shift() }
	
	if ( $fmt =~ /long/i ) {
		$str = sprintf("%04d-%02d-%02d (%03d) %02d:%02d:%02d" ,
			$tm->year+1900, $tm->mon+1, $tm->mday, $tm->yday+1,$tm->hour, $tm->min, $tm->sec);
	}
	elsif ( $fmt =~ /short/i ) {
		$str = sprintf("%04d%02d%02d-%02d%02d%02d" ,
			($tm->year+1900), $tm->mon+1, $tm->mday, $tm->hour, $tm->min, $tm->sec);
	}
	elsif ( $fmt =~ /csv/i ) {
		$str = sprintf("%04d,%02d,%02d,%02d,%02d,%02d" ,
			($tm->year+1900), $tm->mon+1, $tm->mday, $tm->hour, $tm->min, $tm->sec);
	}
	elsif ( $fmt =~ /scs/i ) {
		$str = sprintf "%02d/%02d/%04d,%02d:%02d:%02d", 
			$tm->mon+1, $tm->mday, ($tm->year+1900), $tm->hour, $tm->min, $tm->sec;
	}
	elsif ( $fmt =~ /date/i ) {
		$str = sprintf("%02d%02d%02d" ,
			$tm->year - 100, $tm->mon+1, $tm->mday);
	}
	
	return ( $str );				# return the desired string
}
#*************************************************************/
sub datesec 
# Convert yyyy,Mm,dd,hh,mm,ss to epoch secs
{
	my $dtsec;
	$dtsec = timelocal($_[5], $_[4], $_[3], $_[2], $_[1]-1, $_[0]-1900);
	return ($dtsec);
}


#*************************************************************/
sub datevec
# ($yy, $MM, $dd, $hh, $mm, $ss) = datevec($dtsec);
# convert dtsec to yyyy,MM,dd,hh,mm,ss integers
{
	my $tm = gmtime(shift);
	($tm->year+1900, $tm->mon+1, $tm->mday, $tm->hour, $tm->min, $tm->sec);
}

#*************************************************************/
sub now
{
	my $tm;
	#use Time::gmtime;
	$tm = gmtime;		# CURRENT DATE
	my $nowsec = datesec($tm->year+1900, $tm->mon+1, $tm->mday, $tm->hour, $tm->min, $tm->sec);
	return ( $nowsec);
}

#*************************************************************/
sub dtstr2dt
# Convert a time string in any of several formats to epoch 
# seconds.
# CALL: $dt = dtstr2dt($dtstr);
# INPUT
#  $strin -- time string
# OUTPUT
#  $dt 	-- epoch secs corresponding to dtstr.
#
# FORMATS
# 'long'	--	yyyy-MM-dd (jjj) hh:mm:ss
# 'short'	--	yyMMdd,hhmmss  or yyyyMMdd,hhmmss
# 'csv'		--	yyyy,MM,dd,hh,mm,ss
#
# v101 060628 rmr -- first coding in a03_da0_avg.pl
# v102 060708 rmr -- return 0 if the time string is bad.
# v103 060708 rmr -- extra check of the time string
# v104 060808 rmr -- added International time: yyyyMMddThhmmssZ
# v105 061030 rmr -- add SCS MM/dd/yyyy,hh:mm:ss
{
	my ($dtstr, $n);
	my $t = 0;
	my @dat;
	my @tm = q(2000 01 01 00 00 00);
	my $dt;
	
	$n = $#_;
	$dtstr = shift();
	
	
	# CHECK FOR A GOOD DATE TIME STRING
	if ( $dtstr =~ /[^0-9(),\/:-]TZ/ ) {  # v104 
		print"dtstr2dt finds bad time string: $dtstr\n";
		return 0;
	}
	
	# ==== SPLIT THE INPUT STRING INTO PARTS ====
	
	@dat = split ( /[,\/ ():-]+/, $dtstr );
	
	if ( $#dat == 6 ) {
		# ==== LONG FORMAT =================
		# yy-MM-dd (jjj) hh:mm:ss or yyyy-MM-dd (jjj) hh:mm:ss
		$dt[0] = $dat[0];
		if ( length($dat[0]) <= 2 ) { $dt[0] += 2000 }
		$dt[1] = $dat[1];
		$dt[2] = $dat[2];
		$dt[3] = $dat[4];
		$dt[4] = $dat[5];
		$dt[5] = $dat[6];		
	} elsif ( $#dat == 5 ) {
		# ==== CSV FORMAT =====================
		# MM/dd/yyyy hh:mm:ss
		if ( length($dat[2]) >= 4 ) {
			$dt[0] = $dat[2];
			$dt[1] = $dat[0];
			$dt[2] = $dat[1];
			$dt[3] = $dat[3];
			$dt[4] = $dat[4];
			$dt[5] = $dat[5];		
		}
		# 2006/MM/dd hh:mm:ss  or 06/MM/dd hh:mm:ss
		# yyyy,MM,dd,hh,mm,ss  or yy,MM,dd,hh,mm,ss
		else {
			$dt[0] = $dat[0];
			if ( length($dat[0]) <= 2 ) { $dt[0] += 2000 }
			$dt[1] = $dat[1];
			$dt[2] = $dat[2];
			$dt[3] = $dat[3];
			$dt[4] = $dat[4];
			$dt[5] = $dat[5];		
		}
	} elsif ( $#dat == 1 ) {
		# === SHORT FORMAT ===================
		if ( length($dat[0]) == 6 ) {
			$dt[0] = substr($dat[0],0,2) + 2000;
		} else { $dt[0] = substr($dat[0],0,4) }
		$dt[1] = substr($dat[0],-4,2);
		$dt[2] = substr($dat[0],-2,2);
		$dt[3] = substr($dat[1],0,2);
		$dt[4] = substr($dat[1],2,2);
		$dt[5] = substr($dat[1],4,2);
	} elsif ($#dat == 0 && substr($dat[0],8,1) eq 'T' ) {
		# ==== ISO STANDARD yyyyMMddThhmmssZ ==================  v104
		#print"TIME WORD = $dat[0]\n";
		$dt[0] = substr($dat[0],0,4);
		$dt[1] = substr($dat[0],4,2);
		$dt[2] = substr($dat[0],6,2);
		$dt[3] = substr($dat[0],9,2);
		$dt[4] = substr($dat[0],11,2);
		$dt[5] = substr($dat[0],13,2);
		#print"@dt\n";
	} else {
		print"dtstr2dt finds unknown time string format: $dtstr.\n";
		return 0;
	}
	$t = datesec( $dt[0], $dt[1], $dt[2], $dt[3], $dt[4], $dt[5] );
	#printf"dtstr2dt, t = %s\n", dtstr($t);
	return $t;
}

#*************************************************************/
#   MATH TOOLBOX
#*************************************************************/
sub max
# max(a,b)
{
	# the input is an array of length $#_.
	if ( $_[0] > $_[1] ) { return ( $_[0] ); }
	else { return ( $_[1] ); }
}

#*************************************************************/
sub min
# min(a,b)
{
	if ( $_[0] < $_[1] ) {return ( $_[0] ); }
	else { return ( $_[1] ) };
}


#*************************************************************/
sub stats
# sub (mn, stdpcnt, n, min, max) = stats(sum, sumsq, N, min, max, Nsamp_min);
# needs a global $missing,  which usually is set to -999
{
	my ($sum, $sumsq, $N, $min0, $max0, $Nsamp_min) = @_;
	my ($mn, $std, $n, $min, $max);

	$mn = $std = $missing;
	$n = $N;  $min = $min0;  $max = $max0;
	
# 	print"Stats in: $sum, $sumsq, $N, $min0, $max0, $Nsamp_min\n";
	
	#=================
	# MUST HAVE >= Nsamp_min data points
	#=================
	if ( $N < $Nsamp_min || $N == $missing)  
	{
		$std = $missing;
		$mn = $min = $max = $missing;
	}
	elsif ( $N == 1 ) {
		$mn = $sum;
		$std = 0;
		$n = 1;
		$min = $max = $sum;
	}		
	else  ## N >= 2
	{
		$mn = $sum / $N ;			
		# -- stdev as a percent of the mean -------------
		# from b->ssig = sqrt((a->ssumsq - a->ssum * a->ssum / a->Ns) / (a->Ns-1));
		$x = ( ($sumsq - $sum * $sum / $N) / ($N - 1) );
		if ( $x > 0 ) { $std = sqrt ( $x ); }
		else { $std = 0; }
	}
# 	print"Stats out: $mn, $std, $n, $min, $max\n";
	
	return ( $mn, $std, $n, $min, $max ); 
}


#*************************************************************/
sub FindLines
#
# @rtn = FindLines( $fullfilename, $strx, $nlines )
#
# SEARCHES FOR A LINE WITH A GIVEN STRING
# $fullfilename = file to search
# $strx = the search string, A RegEx string
# $nlines after the id string
#     If nlines = 0, return only the found line.
#     if nlines = 1, return the found line and the next line.
#  Stop at end of file
#
# ver 1.02 rmr 060612 
# ver 103 060807 rmr -- drops first char of out[0] line.
# v104 060902 rmr -- fixed problems with push
# v105 061017 rmr -- just a simple retrieve of lines.
{
	my $fname = shift();
	my $sx = shift();
	my $nlines = shift();
	my $s;
	my $str2 = '';
	my @strout;
	my $i;
	
	open ( F, "<$fname" ) or die("FindLines(),  $fname FAILS\n");
	
	while ( <F> ) {
		chomp($s = $_);							# read each line
		if ( $s =~ /$sx/ ) {
			@strout= $s;						# v102, found string at [0]
			# then read the next n lines
			if ($nlines > 0 ) {
				for ( $i=0; $i<$nlines; $i++ ) { 
					chomp($str2 = <F>);
					push(@strout, $str2);
					if ( eof(F) ) { last }
				}
			}
		}
	}
	close(F);
	return @strout;						# return the line info and the second line
}
#*************************************************************/
sub FindInfo
# sub FindInfo;
# Search through a file line by line looking for a string
# When the string is found, remove $i characters after the string.
# ==== CALLING ====
# $strout = FindInfo( $file, $string, [$splt],  [$ic] )
# ==== INPUT ===
# $file is the file name with full path
# $string is the search string (NOTE: THIS IS A REGEX STRING,
# $splt (optional) is the regex for the split of the line. (typically :)
# $ic (optional) is the number of characters to extract after the split.
#    If $ic is negative then characters before the string are extracted.
#
# ver1.2 rmr 060718 -- preset $strout to default;
# ver 1.3 rmr 061013 -- remove leading spaces
{
	my @v = @_;
	my @cwds;
	my ($fn, $strin, $splt, $strout, $ic, $str, $rec);
	$fn = shift;  
	$strin = shift; 
	if ( $#v > 1 ) { 
		$splt = shift;
		if ( $#v > 2 ) { $ic = shift } else { $ic = 0 }	
	} else {
		$splt = $strin;
		$ic = 0;
	}
# 	print "FindInfo: fn=$fn, strin=$strin, splt = $splt,  ic=$ic\n";
	$strout = 'String not found';
	# OPEN THE CAL FILE
	open(Finfo, "<$fn") or die("FILEINFO OPEN FILE FAILS, $fn");
	$rec=0;
	while ( <Finfo>) {
		$rec++;
		if ( $rec >= 100 ) { 
			$strout = 'String not found in first 100 records';
			last;
		}
		else {
			# clean the line (a.k.a. record)
			chomp($str=$_);
			#print "$rec: $str\n";
			
			# check to see if this record matches
			if ( $str =~ /$strin/ ) {
				#print "FOUND $strin\n";
				
				# if so, remove all of the string after the split string, usually ': '
				@cwds = split(/$splt/, $str);
# 				foreach(@cwds){print "$_\n"}

				# simple, read the entire string following the match
				if ( $ic == 0 ) { $strout = $cwds[1] }
				# read only the next ic characters after the match
				if ($ic > 0) { $strout = substr($cwds[1],0,$ic) }
				# read the ic characters before the match
				if ( $ic < 0 ) { $strout = substr( $cwds[0],-1,$ic ) }
				
				## remove leading spaces
				$strout =~ s/^\s+//;
				last;
			}
		}
	}
	
	close(Finfo);
	return $strout;
}
#======================================================================
sub VecP2V
# (x,y) = MetP2V(s,d, missing)
# Vectors can be reported in meteorological convention or 
#   oceanographic convention which means the vector points in the direction the wind is coming from,
#  or in the direction the wind is going, respectively.
#  The convention we use here is that the vector is in POLAR coordinates and
# reported as speed and the direction the TOWARD.
# The components of the vector are in the direction the wind is going.  A true vector
# sense.
# INPUT
#  s = speed (magnitude)
#  d = direction, (TOWARD)
# OUTPUT
#  x,y are vector components (to direction)
# 
# adapted from C tools: rmrtools
{
# use constant PI => 3.14159265358979;
# use Math::Trig;
	my $d2r = PI / 180;
	if ( $_[0] == $_[2] || $_[1] == $_[2] ) { return ($_[2], $_[2]) }
	my $x = $_[0] * sin ( $d2r * $_[1]);
	my $y = $_[0] * cos ( $d2r * $_[1]);
	return ($x, $y);
}

#======================================================================
sub VecV2P
# (s,d) = MetP2V(u,v, missing)
# Vectors can be reported in meteorological convention or 
#   oceanographic convention which means the vector points in the direction the wind is coming from,
#  or in the direction the wind is going, respectively.
#  The convention we use here is that vectors in POLAR coordinates are
# reported as speed and the direction the wind is going TOWARD.
# INPUT
#  x,y are vector components (to direction)
# OUTPUT
#  s = speed (magnitude)
#  d = oceanographic direction, (TOWARD)
# 
# adapted from matlab tools: rmrtools
# ---------------------------------------------------------------------------
{
# use constant PI => 3.14159265358979;
# use Math::Trig;
	my $r2d = 180 / PI;
	if ( $_[0] == $_[2] || $_[1] == $_[2] ) { return ($_[2], $_[2]) }
	my $x = $_[0];
	my $y = $_[1];
	my $s = sqrt( $x * $x + $y * $y);
	my $d = atan2($x, $y) * $r2d;
	if ( $d < 0 ) { $d += 360 }
	return ($s, $d);
}

