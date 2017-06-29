#!/usr/bin/perl -w
my $PROGRAMNAME = 'AOD.pl';
my $VERSION = '05a';  
my $EDITDATE = '100322';
#v5 -- remove rad from this program. Restructure and make more robust against missing data files.
#v5a 100430 -- program AOD.pl has been delivered to 
#to do--
#check times of input for old data



# SAMPLE TIME - decide what to use
# Time check, reject repeats.
# 
#v02 - R type output files, 

my $setupfile = shift();
print "setup file = $setupfile\n";

my $datainfile = shift();
print "data in file = $datainfile\n";


#====================
# PRE-DECLARE SUBROUTINES
#====================
use Time::Local;
use Time::localtime;
use Time::gmtime;
use POSIX;
use Math::MatrixReal;

use constant PI => 3.14159265358979;
use constant TWOPI => 2 * PI;
use constant D2R => 0.017453292;
use constant R2D => 57.2957795;
use constant MISSING => -999;

sub EstimateEdge;
sub EstimateShadow;
sub EstimateGlobal;
sub HorizIrradiance;
sub DiffuseIrradiance;
#sub NormalIrradiance;
sub ZeError;  #new
sub AtmMass;  #new
sub SunDistanceRatio;  #new
sub RelativeSolarVector;  #mod
sub RotationTransform;  #mod
sub FindLines;  #mod
sub FindInfo;  #mod
sub now;
sub dtstr;
sub dtstr2dt;
sub datesec;
sub datevec;
sub jdf2dt;
sub min;  #new

my($i, $j, $str, $pgmstart, $avgsecs, $fnout, $fnrawout, $outfile, $outpath);
my ($y, $M, $d, $h, $m, $s);
my $dt1 = 0;
my ($dtnow, $dtrsr, $dttcm, $dtgps);
my @dat;
my ($gpsok,$rsrok,$tcmok);
my ($rsrline, $rsrfile, $shadowratio, $ichan);
my ($saz, $sze, $szrel, $sazrel, $Amass, $Dratio, $Dratio_ref, $Dcorrection, $dt_IO);
my @rsr1;  my @datrsr; my @g1; my @g2; my @global;
my @edge; my @shadow; my @horiz; my @diffuse; my @normal;
my @Kze;


print"\n======================== START PROCESSING $PROGRAMNAME =======================\n";

$pgmstart = now();

#----------------- HEADER ----------------
$header = "PROGRAM: $PROGRAMNAME (Version $VERSION, Editdate $EDITDATE)
RUN TIME: " . dtstr($pgmstart) . "utc
POINT OF CONTACT: Michael Reynolds, michael\@rmrco.com\n";

my $expname = FindInfo($setupfile,'EXPERIMENT NAME', ': ');
$header = $header."EXPERIMENT NAME: $expname\n";

my $location = FindInfo($setupfile,'GEOGRAPHIC LOCATION', ': ');
$header = $header."GEOGRAPHIC LOCATION: $location\n";

my $platform = FindInfo($setupfile,'PLATFORM NAME', ': ');
$header = $header."PLATFORM NAME: $platform\n";

my $side_location = FindInfo($setupfile,'LOCATION ON PLATFORM', ': ');
$header = $header."LOCATION ON PLATFORM: $side_location\n";

my $ht_above_sealevel = FindInfo($setupfile,'HEIGHT ABOVE SEA LEVEL', ': ');
$header = $header."HEIGHT ABOVE SEA LEVEL: $ht_above_sealevel\n";

my $rsrhub = FindInfo($setupfile,"RSR HUB COM NUMBER",":");
$header=$header."RSR COM HUB NUMBER: $rsrhub\n";

my $prpsn = FindInfo($setupfile,'PRP SERIAL NUMBER', ': ');
$header = $header."PRP SERIAL NUMBER: $prpsn\n";

my $rsrsn = FindInfo($setupfile,'FRSR SERIAL NUMBER', ': ');
$header = $header."FRSR SERIAL NUMBER: $rsrsn\n";

my $headsn = FindInfo($setupfile,'HEAD SERIAL NUMBER', ': ');
$header = $header."MFR HEAD SERIAL NUMBER: $headsn\n";

my $hub_base_number = FindInfo($setupfile,"SERIAL HUB OFFSET",":");
$header=$header."SERIAL HUB OFFSET: $hub_base_number\n";

my $rsravgsecs = FindInfo($setupfile,'RSR AVERAGING TIME', ': ');
$header = $header."RSR AVERAGING TIME (secs): $rsravgsecs\n";

my $tcmhub = FindInfo($setupfile,"TCM HUB COM NUMBER",":");
$header=$header."TCM COM HUB NUMBER: $tcmhub\n";

my $tcmsn = FindInfo($setupfile,'TCM SERIAL NUMBER', ': ');
$header = $header."TCM SERIAL NUMBER: $tcmsn\n";

my $tcmavgsecs = FindInfo($setupfile,'TCM AVERAGING TIME', ': ');
$header = $header."TCM AVERAGING TIME (secs): $tcmavgsecs\n";

if( $tcmhub == 0 ) {
	$header=$header."---TCM FIXED LOCATION---\n";
	$pitch = FindInfo($setupfile,"TCM FIXED PITCH",":");
	$header=$header."TCM FIXED PITCH: $pitch\n";
	$roll = FindInfo($setupfile,"TCM FIXED ROLL",":");
	$header=$header."TCM FIXED ROLL: $roll\n";
}

my $hdgsource = FindInfo($setupfile,"HEADING SOURCE",":");
$header=$header."HEADING SOURCE: $hdgsource\n";
if( $hdgsource =~ /fixed/i ) {
	$hdgfixed = FindInfo($setupfile,"FIXED HEADING",":");
	$header=$header."FIXED HEADING: $hdgfixed\n";
}
my $gpsvar;
my $gpshub = FindInfo($setupfile,"GPS HUB COM NUMBER",":");
if( $gpshub == 0 ) {
	$header=$header."---GPS FIXED LOCATION---\n";
	$lat = FindInfo($setupfile,"GPS FIXED LATITUDE",":");
	$header=$header."GPS FIXED LATITUDE: $lat\n";
	$lon = FindInfo($setupfile,"GPS FIXED LONGITUDE",":");
	$header=$header."GPS FIXED LONGITUDE: $lon\n";
	$gpsvar = FindInfo($setupfile,"GPS FIXED VARIATION",":");
	$header=$header."GPS FIXED VARIATION: $gpsvar\n";
} else { $lat = $lon = $gpsvar = 0 }

my $gpssn = FindInfo($setupfile,'GPS SERIAL NUMBER', ': ');
$header = $header."GPS SERIAL NUMBER: $gpssn\n";

my $gpsavgsecs = FindInfo($setupfile,'GPS AVERAGING TIME', ': ');
$header = $header."GPS AVERAGING TIME (secs): $gpsavgsecs\n";

my $aodsecs = FindInfo($setupfile, "AOD COMPUTE TIME SECS",':');
$header = $header."AOD COMPUTE TIME SECS: $aodsecs\n";

my $shadowthreshold = FindInfo($setupfile,"AOD SHADOWRATIO THRESHOLD",':');
$header = $header."AOD SHADOWRATIO THRESHOLD: $shadowthreshold\n";

my $edge1 = FindInfo($setupfile,"AOD EDGE INDEX 1",":");
$header = $header."AOD EDGE INDEX 1: $edge1\n";

my $edge2 = FindInfo($setupfile,"AOD EDGE INDEX 2",":");
$header = $header."AOD EDGE INDEX 2: $edge2\n";

my $ishadow = FindInfo($setupfile,"AOD SHADOW INDEX",":");
$header = $header."AOD SHADOW INDEX: $ishadow\n";

my $fheadze =  FindInfo($setupfile,"HEAD ZE CAL FILE",":");
$header=$header."HEAD ZE CAL FILE: $fheadze\n";

## CALIBRATION COEFFICIENTS @cal
my @strlines;
my @cal; # c00,c01, c10, c11, c20, c21, ...
$header=$header."HEAD CALIBRATION COEFS\n";
@strlines = FindLines($setupfile, 'HEAD CALIBRATION CONSTANTS', 8);
for ($i=1; $i<=7; $i++) {
	$strlines[$i] =~ s/^[ ]+//;
	@dat = split(/[ ]+/, $strlines[$i]);
	push(@cal,$dat[0]); push(@cal,$dat[1]);
	$header = $header." $cal[2*($i-1)], $cal[2*($i-1)+1]\n";
}

@strlines = FindLines($setupfile, 'DETECTOR BAND CENTER WAVELENGTHS', 2);
my @bands = split(/,/,$strlines[1]);
$header=$header."DETECTOR BAND CENTER WAVELENGTHS\n";
$header=$header."@bands\n";

# BANDPASS AND TOA IRRADIANCES
my @bandpass;  # (min mid max) for channels 1-6 (zero is broadband)
my @toa; # (min mean max) spread in TOA over the bandpass 
@strlines = FindLines($setupfile, 'PASS BAND AND TOA IRRADIANCE', 9);
for($i=3; $i<9; $i++){
	#print"$i, $strlines[$i]\n";
	@dat = split(/,/,$strlines[$i]);
	for ($j=0; $j<6; $j++) { $dat[$j] =~ s/^[ ]+// }
	push(@bandpass, ($dat[0],$dat[1],$dat[2]));
	push(@toa, ($dat[3],$dat[4],$dat[5]));
}

$header=$header."BANDPASS CENTER WAVELENGTH (nm):\n";
for($i=0; $i<6; $i++){
	$header=$header."$bandpass[3*$i], $bandpass[3*$i+1], $bandpass[3*$i+2]\n";
}
$header=$header."TOP OF THE ATMOSPHERE RADIANCE FOR EACH BAND:\n";
for($i=0; $i<6; $i++){
	$header=$header."$toa[3*$i], $toa[3*$i+1], $toa[3*$i+2]\n";
}

## RAYLEIGH 
my @rayleigh;
for($i=0; $i<7; $i++) {
	push(@rayleigh, aod_rayleigh($i));
}
$header=$header."RAYLEIGH COEFS: @rayleigh\n";

my $missing = FindInfo($setupfile,'MISSING VALUE', ': ');
$header = $header."MISSING NUMBER: $missing\n";

# v01a Conversion was 273.15.
$Tabs = 273.15;  # absolute temperature at 0degC
$header = $header."KELVIN CONVERSION: $Tabs\n";

@strings = FindLines($setupfile, 'PRP COMMENTS:', 100 );
$header = $header."COMMENTS:\n";
if ( $#strings > 0 ){
	for($i=1; $i<=$#strings; $i++) { 
		if ( $strings[$i] =~ /^END/i ) {last}
		else { $header = $header."$strings[$i]\n";}
	}
}

my $kverbal = FindInfo($setupfile,'AOD VERBAL', ': ');
$header = $header."AOD VERBAL: $kverbal\n";


my $MainDirectory;
chomp($MainDirectory = `pwd`);
$header = $header."PRESENT WORKING DIRECTORY: $MainDirectory\n";

## PRINT OUT THE HEADER
print"
------------- HEADER ----------------
$header
------------ END HEADER ---------------------\n";

my $hd1="yyyy MM dd hh mm ss      lat       lon    shd   sog  cog    hdg   pitch sigp   roll  sigr  saz   sze  sazr szer amass ";
my $hd2=" band   kze    Dcorr    global    edge    shadow   diffuse  horiz    normal    toa    aod    oz     ray    aodf";

## OUTPUT FILES FOR EACH CHANNEL
# DEFINE OUT PATH
$outpath =  FindInfo($setupfile,'DATA OUTPUT PATH', ': ');
if ( ! -d $outpath ) { print"!! DATA OUTPUT PATH - ERROR, $outpath\n"; die }

while(1){
	@rsr1=();  @dat=();  @datrsr=(); @g1=(); @g2=(); @global=();
	@edge=(); @shadow=(); @horiz=(); @diffuse=(); @normal=();
	@Kze=();
	$dtnow = now();
	# FOR TIME DELAY BEFORE PROCESSING
	if( $dtnow >= $dt1 ) {
		# DOES THE RSR FILE EXIST?
		$rsrok = 0;
		chomp($rsrfile = `find $datainfile -maxdepth 1 -name "rsr*.dat" -mtime 0 > tmp; tail -n 1 tmp`);
		if( ! -f $rsrfile ) { $rsrok=0; print "NO RSR DATA  FILE\n"}
		else {
			# READ THE LAST 10 LINES OF THE RSR FILE
			print "RSR DATA FILE: $rsrfile\n";
			chomp($rsrline = `tail -n 10 $rsrfile`);
			print"RSR last 10 lines: $rsrline\n";
			# READ RSR AND SEE IF WE ARE IN H OR LOW MODE
			@rsr1 = split(/\n/,$rsrline);
			if( $rsr1[$#rsr1] =~ /\<\</ ) {
				printf"LAST RSR LINE:\n%s\n", $rsr1[$#rsr1];
				print"Low Mode, no AOD calculation\n";
				$rsrok=0;
			} else {
				print"RSR HIGH MODE\n";
				@datrsr = split(/[ ,]+/,$rsr1[0]);
				#foreach $d (@datrsr) {print"DAT: $d\n"};
				# RSR TIME
				$dtrsr = datesec($datrsr[1],$datrsr[2],$datrsr[3],$datrsr[4],$datrsr[5],$datrsr[6]);
				printf"rsr time: %s\n", dtstr($dtrsr); 
				$rsrok=1;
			}
		}
		## NOW CHECK TCM DATA -- FIXED TCM DATA FROM SETUP
		$tcmok=0;
		if( $tcmhub == 0 ) {
			$dttcm = $dtnow;
			$sigpitch = $sigroll = $az = $sigc = 0;
			$tcmok=1;
		} else {
			# CHECK FOR TCM FILE
			chomp($tcmfile = `find  $datainfile -maxdepth 1 -name "tcm*.dat" -mtime 0   > tmp; tail -n 1 tmp`);
			if( ! -f $tcmfile ) { $tcmok=0; print"NO TCM DATA FILE\n" }
			else { 
				## READ TCM DATA AND CHECK VALIDITY
				print "TCM DATA FILE: $tcmfile\n";
				chomp($tcmline = `tail -n 1 $tcmfile`);
				print"TCM last line: $tcmline\n";
				@dat=split(/[ ]+/,$tcmline);
				if( $dat[0] =~ /20/ ) {
					$dttcm = datesec($dat[0],$dat[1],$dat[2],$dat[3],$dat[4],$dat[5]);
					$pitch=$dat[6]; $roll=$dat[8]; $sigpitch=$dat[7]; $sigroll=$dat[9]; 
					$az=$dat[10]; $sigc = $dat[11];
					$tcmok=1;
				} else { $tcmok = 0 }
			}
		}
		## FIXED POSITION OR GPS
		if( $gpshub == 0 ) {
			$dtgps = $dtnow;
			$sog = $cog = 0; # lat, lon, and var are set in setup
			$gpsok =1 ;
		} else {
			## CHECK GPS DATA
			chomp($gpsfile = `find $datainfile  -maxdepth 1 -name "gps*.dat" -mtime 0  > tmp; tail -n 1 tmp`);
			if ( ! -f $gpsfile ) { print"NO GPS DATA FILE\n" }
			else { 
				print "GPS DATA FILE: $gpsfile\n";
	 			chomp($gpsline = `tail -n 1 $gpsfile`);
				print"GPS last line: $gpsline\n";
				@dat = split(/[ ]+/,$gpsline);
				if( $dat[0] =~ /20/ ) {
					$dtgps = datesec($dat[0],$dat[1],$dat[2],$dat[3],$dat[4],$dat[5]);
					$lat = $dat[6];  $lon=$dat[7], $sog=$dat[8]; $cog=$dat[9]; $gpsvar=$dat[10];
					$gpsok = 1;
				} else { $gpsok = 0 }
			}
		}
		
		## CONTINUE OF ALL OK
		if( !$gpsok || !$tcmok || !$rsrok ) {
			print"Waiting for good data.\n";
		} else {
			print"tcm, gps, and rsr data are ok. Continue processing.\n";
			## HEADING -- USE TCM OR A FIXED VALUE
			my $hdg;
			if( $hdgsource =~ /fixed/i ) { $hdg = $hdgfixed }
			else {$hdg = $az + $gpsvar}
			
			## CHECK RSR 
			$shadowratio = $datrsr[10];
			print"Shadow ratio = $shadowratio,  threshold = $shadowthreshold\n";
			
			
			## CHECK SHADOW THRESHOLD TO CONTINUE
			if($shadowratio < $shadowthreshold) { print"Low shadow ratio, no AOD calculation.\n"}
			else {
				## FOR EACH CHANNEL PROCEED WITH COMPUTATIONS OF AOD
				## RETRIEVE GLOBALS
				$rsr1[1] =~ s/^[ ]+//;
				@g1 = split(/[ ]+/,$rsr1[1]);
				$rsr1[2] =~ s/^[ ]+//;
				@g2 = split(/[ ]+/,$rsr1[2]);
				for($ichan=0; $ichan<7; $ichan++) {
					push @global, ($g1[$ichan] + $g2[$ichan])/2;
				}
				if($kverbal){print"global = @global\n"} #test
				
				## EPHEMERIS FOR SOLAR AZ AND ZE
				($saz, $sze) = Ephem( $lat, $lon, $dtgps);
				if ( $sze > 88 ) { printf"ze=%.1f. It is below the horizon. Do not compute.\n",$sze }
				else {
					## ATMOSPHERIC MASS
					$Amass = AtmMass( $sze ); 
					if($kverbal){printf"ATMMASS(%.1f) = %.6f\n", $sze, $Amass}
					
					## SOLAR DISTANCE RATIO -- CORRECT THULLIER FOR TODAY'S DISTANCE RATIO
					($Dratio) = SunDistanceRatio( $dtgps );
					if($kverbal){printf"SOLAR DISTANCE=%.6f\n", $Dratio}
					($dt_I0) = datesec(2001,10,5,0,0,0);  # Thiullier
					($Dratio_ref) = SunDistanceRatio( $dt_I0 );
					if($kverbal){printf"SOLAR DISTANCE (Thullier) = %.6f\n", $Dratio_ref}
					$Dcorrection = ( $Dratio_ref * $Dratio_ref ) / ( $Dratio * $Dratio );
					if($kverbal){printf"Dcorrection = %.6f\n", $Dcorrection}
					
					## CORRECT NORMAL FOR ZE AND AZ
					## test $hdg=0; $xaz=180; $sze=45; $pitch=5; $roll=5;
					($szrel,$sazrel) = RelativeSolarVector ( $sze, $saz, $hdg, $pitch, $roll);
					if($kverbal){printf"Current attitude: saz=%.2f, sze=%.3f, hdg=%.1f, pitch=%.1f, roll=%.1f\n",
						$saz, $sze, $hdg, $pitch, $roll}
					if($kverbal){printf"Relative Solar Vector: az=%.1f, ze=%.1f\n", $sazrel, $szrel}
						
					## FOR EACH CHANNEL IDENTIFY EDGE AND SHADOW VALUES
					for($ichan=0; $ichan<7; $ichan++) {
						my ($e,$s) = EdgeAndShadow($edge1, $edge2, $ishadow, $rsr1[3+$ichan]);
						push(@edge, $e);
						push(@shadow, $s);
						# HORIZONTAL IRRADIANCE
						push(@horiz, $e-$s);
						# DIFFUSE IRRAIANCE
						push(@diffuse, $global[$ichan] - $horiz[$ichan]);
						
						# CORRECT FOR THE HEAD ZE CALIBRATION
						my $kze = ZeError( $fheadze, $szrel, $sazrel, $ichan );
						push(@Kze, $kze );
						
						## COMPUTE THE NORMAL WITH ZE CORRECTION
						my $norm;
						if ( $horiz[$ichan] > MISSING ) {
							$norm = ($horiz[$ichan] / cos( $sze * D2R )) / $kze;
						} else {$norm=MISSING}
						push(@normal, $norm);
					}
					if($kverbal){
						print "SHADOW: @shadow\n";
						print "EDGE: @edge\n";
						print"HORIZ: @horiz\n";
						print"DIFFUSE: @diffuse\n";
						print"NORMAL: @normal\n";
						print"Kze: @Kze\n";
					}
					
					## APPLY CALIBRATION COEFFICIENTS FOR ABSOLUTE IRRADIANCE W/M^2
					for($ichan=0; $ichan<7; $ichan++) {
						my $c1=$cal[$ichan*2];
						my $c0=$cal[$ichan*2+1];
						if($kverbal){print"chan $ichan  c1=$c1; c0=$c0\n"}
						$global[$ichan] = max(0, $global[$ichan]*$c1 + $c0);
						$shadow[$ichan] = max(0,$shadow[$ichan]*$c1 + $c0);
						$edge[$ichan] = max(0, $edge[$ichan]*$c1 + $c0);
						$horiz[$ichan] = max(0, $horiz[$ichan]*$c1 + $c0);
						$diffuse[$ichan] = max($diffuse[$ichan]*$c1 + $c0, 0);
						$normal[$ichan] = max(0, $normal[$ichan]*$c1 + $c0);
						if($kverbal){printf"chan %d, S=%.5f, E=%.5f, H=%.5f, D=%.5f, N=%.5f\n",
							$ichan, $shadow[$ichan],$edge[$ichan],$horiz[$ichan],$diffuse[$ichan],$normal[$ichan]}
					}
					
					## COMPUTE AOD FOR CHANNELS 1-6
					print"==== AOD COMPUTATION RESULTS ====\n";
					my $str1 = sprintf "%s %10.5f %10.5f %5.1f %4.1f %5.1f %5.1f %5.1f %5.1f %5.1f %5.1f %5.1f %4.1f %5.1f %4.1f %5.3f",
						dtstr($dtgps,'ssv'), $lat, $lon, $shadowratio, $sog, $cog, $hdg, $pitch, $sigpitch, $roll, $sigroll,$saz, $sze, $sazrel, $szrel, $Amass; 
					print"$hd1\n";
					print"$str1\n";
					print"\n$hd2\n";

					$str = dtstr($dtgps,'prp');
					# WRITE THE HEADER FILE if this is a new 
					$fnhdr = $outpath."/aod".$str.".hdr";
					if( ! -f $fnhdr ) {
						#printf"Open %s\n", $fnhdr;
						open(F,">>$fnhdr") or die;
						printf F "%s\n", $header;
						close F;
					}
					
					## ========================
					## COMPUTE AOD FOR EACH CHANNEL
					## =========================
					my ($TOA, $I0, $aod, $AOD, $oz);
					for($ichan=1; $ichan<7; $ichan++) {
						
						## TOP OF ATMOSPHERE RADIANCE, THULLIER
						$I0 = $toa[($ichan-1)*3+1];
						$TOA = $I0 * $Dcorrection; 
						
						($oz) = aod_ozone($dtgps, $lat, $ichan);
						if( $normal[$ichan] <= 0 ) { 
							$aod = 0;
							$AOD=0;
						} else {
							$aod = (log($TOA) - log($normal[$ichan]) ) / $Amass;
							$AOD = $aod - $rayleigh[$ichan] - $oz;
						}
						
						## AOD STRING
						$str2 = sprintf "%6.1f  %5.3f  %6.4f  %6.5f  %6.5f  %6.5f  %6.5f  %6.5f  %6.5f  %6.5f  %5.3f  %5.3f  %5.3f  %5.3f",
							$bandpass[($ichan-1)*3+1], $Kze[$ichan], $Dcorrection, $global[$ichan], $edge[$ichan], $shadow[$ichan], $diffuse[$ichan],$horiz[$ichan],$normal[$ichan],$TOA,$aod,$oz,$rayleigh[$ichan],$AOD;
						print"$str2\n";
						
						
						## OUTPUT FILE example: aod100318.da3
						$fn= $outpath."/aod".$str.".da".$ichan;
						# WRITE HEADER FOR NEW FILES
						if( ! -f $fn ) {
							open(F,">>$fn") or die;
							print F $hd1.$hd2."\n";
							close F;
						}
						open(F,">>$fn") or die;
						print F $str1." ".$str2."\n";
						close F;
					}
				}
			}
		}
		
		## COMPUTE NEXT SAMPLE TIME
		($y, $M, $d, $h, $m, $s) = datevec( $dtnow );
		$dt0 = datesec($y, $M, $d, 0, 0, 0);  # epoch secs at midnight
		$dt1 = $dt0 + $aodsecs * (1 + int( ($dtnow - $dt0) / $aodsecs)) + 80;	# prior sample block dtsec
		printf "Next calculation at %s\n", dtstr($dt1);
	}
}	


die;
exit(0);


#**************************************************************/
#	AOD TOOL BOX
#**************************************************************/

#=======================================================
sub SunDistanceRatio
# function  [r, d,  dmean] = SunDistance(dt)
# %SUNDISTANCE - compute the sun earth distance ratio
# %	[r, d, dmean] = SunDistance(dt)
# %====================================================
# % The sun-earth distance ratio is used to correct the solar
# %constant.
# %
# % Taken from Schwindling et al.,1998, JGR, 103(C11),24919-24935.
# % who  attribute this to Paltridge and Platt, 1977, Radiative
# %Processes in Meteorology and Climatology, in "Developments
# %in Atmos. Science 5," Elsevier Sci., New york.
# %
# % ALTERNATIVE FROM JOE MICHALSKY, EMAIL 02030`
# % calculates r2 = (1/r)^2
# % g = (2 * pi * (jdf-1)) / 365;
# % r2 = 1.00011 + 0.034221 * cos(g) + 0.00128 * sin(g) + ...
# %   0.000719 * cos(2 * g) + 7.7e-5 * sin(2 * g);
# %input:
# % dt = datenum
# %output:
# % r = the ratio of the distance to the sun.
# % d = actual distance (km)
# % dmean = the mean distance, a constant. (km)
# %
# %reynolds 020311
# %==========================================================
# 
# %TEST
# FOR 060805 --
# D = 151,825,492 km see http://www.galaxies.com/calendars.aspx
# gives r = 1.0148907.
# Schwindling method gives 1.01444.
# Michalsky method is way off.
## v101 060805 rmr -- PERL adapted from Matlab
{
# 	use constant PI => 3.14159265358979;

	my $dmean = 149597870.691;  # km ;  see http://neo.jpl.nasa.gov/glossary/au.html
	
	# =====================
	# COMPUTE THE JULIAN DAY
	# =====================
	my ( $y, $jdf) = dt2jdf( $_[0] );
	##Schwindling
	
	# ======================
	# SUN-EARTH DISTANCE IN AU
	# ======================
	my $r = 1 - 0.01673 * cos(0.017201 * ( $jdf - 4));  ## Schmindling eq 9 method
	## Michalsky method (computes (1/r)^2)
	my $g = (2 * PI * ( $jdf - 1)) / 365;
	my $r2 = 1.00011 + 0.034221 * cos($g) + 0.00128 * sin($g) + 
	  0.000719 * cos(2 * $g) + 7.7e-5 * sin(2 * $g);  ## Michalsky method
	
	#printf"SOLAR DISTANCE: %.5f, %.1f, %.1f\n",$r, $dmean*$r, $dmean;
	return ($r, $dmean * $r, $dmean);
}


#==============================================================
sub aod_ozone
# (tau, dob) = aod_ozone( dt, lat, det)
# ==========================================================================
# This function computes the climatological ozone concentration in dobson 
# units for a specified latitude on a specified julian day.  
# The climatological ozone concentrations is included in this function.
# 
# input
#  dt = datesec
#  lat = latitude nx1 vector
#  det = [1,...,7] is the channel number for the frsr
#  
# output
#  tau = optical thickness for ozone
#  dob = dobson units for this time and latitude
# =========================================================================
{
	my ($dt, $lat, $det) = @_;
	
	if ( $det < 1 || $det > 6 ) { return ( MISSING, MISSING ) }
	
	#=======================
	# CLIMATOLOGICAL OZONE
	# organized by 10 deg latitude bands and month
	#=======================
	my @oz = (
	315,330,338,330,315,290,264,245,240,240,249,265,284,305,325,346,352,348,340,
	360,376,380,372,350,316,278,252,240,240,242,257,276,291,307,316,318,315,307,
	420,428,422,405,380,340,295,260,242,240,240,252,268,285,296,302,300,300,300,
	440,440,440,423,394,347,304,272,253,240,242,252,262,280,290,293,300,300,300,
	430,430,428,415,380,342,305,275,255,240,244,252,260,279,288,292,300,300,300,
	400,395,390,377,353,330,295,272,255,240,246,254,265,286,296,295,300,300,300,
	350,350,350,340,330,310,281,265,252,240,248,258,273,295,307,305,300,300,300,
	315,315,317,314,310,290,273,258,244,240,250,262,280,307,316,314,304,300,300,
	287,292,294,297,293,278,263,250,240,240,252,268,291,318,327,324,313,300,300,
	280,280,288,291,284,270,257,244,240,240,256,276,300,327,335,335,322,308,300,
	285,290,294,293,284,268,255,240,240,240,259,278,300,331,344,352,338,323,312,
	295,300,310,308,295,275,256,240,240,240,256,272,292,320,340,360,360,360,355,
	315,330,338,330,315,290,264,245,240,240,249,265,284,305,325,346,352,348,340,
	360,376,380,372,350,316,278,252,240,240,242,257,276,291,307,316,318,315,307);
	
	# coefficients to convert dobson units to optical depth
	# for different bands.
	# Note broadband channel is set to zero for now
	my @ozcoef = (0, 0, 0, 0.0328, 0.1221, 0.04976, 0.0036);
	
	if ( $lat < -90 ) { return (MISSING, MISSING) }
	
	#  THE MONTH DETERMINES THE ROW
	my ( $y, $m, $d );
	($y,$m,$d) = datevec( $dt );
	#print"month = $m\n";
	
	# THE LATITUDE BAND DETERMINES THE COLUMN
	my $ix = ($m-1)*19 + int( ( $lat + 90 ) / 10);
	#print"INDEX = $ix\n";
	
	# READ DOBSON FROM THE ARRAY
	my $dob = $oz[$ix];
	
	# COMPUTE THE OPTICAL DEPTH USING COEFFICIENTS
	my $aod = $dob * $ozcoef[$det] / 1000;
	
	#printf"ozone aod=%.6f, dob=%.0f\n", $aod, $dob;
	return ($aod, $dob);
}



#=====================================================
sub aod_rayleigh
#CALLING:
#  ($ar) = aod_rayleigh ( $chan );
#INPUT
#  $chan = 1-6.  If chan=0, return 0
#
#  Computes the Rayleigh Optical Thickness for 
#  any frsr detector number
#  Based on the paper "bodhaine99"
# v101 060808 rmr -- from soarmatlab getrayleigh()
{
	my $det=shift;
	
	# RAYLEIGH AOD FOR CHANNELS 2-7
	my @a = (0, 0.309, 0.14336, 0.061586, 0.040963, 0.001513, 0.001108);
	if ( $det < 0 || $det > 6 ) { return MISSING }
	
	return $a[$det];
}


#======================================================
sub AtmMass
# function m = AtmMass(z)
# %ATMMASS - compute atmospheric mass for zenith angle
# %=========================================================
# %	m = AtmMass(z)
# %
# % From Schwindling et al. (1998) JGR, 103, 24919-24935
# %and
# %Kasten and Young (1989), Appl Optics, 28, 4735-4738
# %
# %input: z = zenith angle
# %output: m = atmospheric mass
# %
# %reynolds 981105
# %=========================================================
## v101 060805 rmr -- adapted from Matlab
{
# 	use constant D2R => 0.017453292;
# 	use constant MISSING => -999;
	
	my $a = 0.50572;
	my $b = 6.07995;
	my $c = -1.6364;
	my $z = shift();
	my $m = MISSING;
	
	if ( $z > 89 || $z < 0 ) { return MISSING }
	else {
		$m = cos( $z * D2R ) + $a * ( $z + $b)**$c;
# 		printf"%.6f, %.6f, %.6f\n",cos( $z * D2R ),( $z + $b)**$c,$a * ( $z + $b)**$c;
	}
	return 1/$m;
}



#======================================================
sub ZeError
# ZEERROR - compute the zenith error calibration based on az and ze angle
#          corr = ZeError(fcal, sz, az, ichan)
# =======================================================================
# 
# input: 
#	fcal = full filename to the MFR head ze calibration file (e.g. 469.SOL)
#   ze = solar zenith angle -- RELATIVE TO THE PLATFORM NORMAL
#   az = solar azimuth -- RELATIVE TO THE PLATFORM NORTH MARK
#	ichan = the channel number (0-6). The detector numbers are (1-7) and
#     detector number 1 is the unfiltered detector, channel 0.
# 
# output:
#  corr = the calibration value from the MFRSR head calibration.
# 
# The calibration SOL file is read.
# This function reads this file and uses the input information to compute
# the calibration value.  
# 	The 'north' mark of the head corresponds to the 
# bracket direction (also the direction the arm points to on an normal
# MFRSR.  Hence, normally the motor points to the equator (S).
# 	The correction array is listed in two columns.  There are 181 rows 
# in the matrix corresponding to angles from 0 to 180.  
# 	Column 1 is correction for zenith angles from 0 (south horizon) to 
# 180 (north horizon).  Column 2 corresponds to angles from 0 (west horizon)
# to 180 (east horizon);
# 
# 
# reynolds 980126
#  modified by MJB 2/24/99
# v200 2/13/2001 uses new path and info file
# v201 3/01/2001 "
# v020 4/26/2002 added global drive_matlab
## MODIFIED FROM THE MATLAB ROUTINE V020
## v 101 060807 rmr -- modified for a04_MaleParams.pl
## v102 061019 rmr -- if ze > 90, return missing
# v103 100316 rmr -- tidied up for AOD.pl program
# 
# ========================================================================
{
	my ($fcal, $ze, $az, $ichan) = @_;
	my ($corr, $quad, $iz1, $iz2);
	my ($sn1, $sn2, $we1, $we2);
	my @isn1 = (1,1); # row, col
	my @isn2 = (1,1); # row, col
	my @iwe1 = (1,1); # row, col
	my @iwe2 = (1,1); # row, col
	my @linesn;
	my @linewe;
	my $delaz;
	my @wds;
	# DETECTOR NUMBER (1-7)
	$det = $ichan + 1;
	
# use constant MISSING => -999;
	
	if ( $ze < 1 || $ze>89) { return MISSING }
	if ( $az > 360 ) { return MISSING }
	if ( $az < 0 ) { $az += 360 }
	if ( $az == 360 ) { $az = 0 }
	
	## OPEN THE ZE CAL FILE
	@linesn = FindLines( $fcal, "SN$det", 19); # read the next 19 lines after the SNx line
	@linewe = FindLines( $fcal, "WE$det", 19);
	
	## CHECK FOR EACH QUADRANT
	$corr = MISSING;
	$quad = int($az/90) + 1;
	# line number of first interpolation point
	$iz1 = int($ze);  
	($iz2) = min ( $iz1+1, 90);  # # 1,2,...,90
	#print"quad=$quad,  iz1=$iz1, iz2=$iz2\n";

	## QUADRANT 1
	# arc a spans lower zeang from n to e
	# arc b spans ize + 1 deg
	if ( $quad == 1 ) {
		if ( $iz1 == 0 ) { 
			@isn1 = (10,0);  @isn2 = (11,0);
			@iwe1 = (10,0);  @iwe2 = (11,0);
		} else {
			@isn1 = ( 11 + int(($iz1-1)/10), ($iz1-1)%10 ); 
			@iwe1 = ( 11 + int(($iz1-1)/10), ($iz1-1)%10 );
			@isn2 = ( 11 + int(($iz2-1)/10), ($iz2-1)%10 );
			@iwe2 = ( 11 + int(($iz2-1)/10), ($iz2-1)%10 );
		}
		## ARC 1
		@wds = split( / /, $linesn[$isn1[0]] );
		$a1 = $wds[ $isn1[1] ];
		@wds = split( / /, $linewe[$iwe1[0]] );
		$a2 = $wds[ $iwe1[1] ];
		## ARC 2
		@wds = split( / /, $linesn[ $isn2[0] ] );
		$b1 = $wds[ $isn2[1] ];
		@wds = split( / /, $linewe[ $iwe2[0] ] );
		$b2 = $wds[ $iwe2[1] ];
		$delaz = $az;
	}
	elsif ($quad == 2) {
		if ( $iz1 == 0 ) { 
			@iwe1 = (10,0);  @iwe2 = (11,0);
			@isn1 = (10,0);  @isn2 = (9,9);
		} else {
			@isn1 = ( 9 - int(($iz1-1)/10), 9-($iz1-1)%10 ); 
			@iwe1 = ( 11 + int(($iz1-1)/10), ($iz1-1)%10 );
			@isn2 = ( 9 - int(($iz2-1)/10), 9-($iz2-1)%10 );
			@iwe2 = ( 11 + int(($iz2-1)/10), ($iz2-1)%10 );
		}
		@wds = split( / /, $linewe[$iwe1[0]] );
		$a1 = $wds[ $iwe1[1] ];
		@wds = split( / /, $linesn[$isn1[0]] );
		$a2 = $wds[ $isn1[1] ];
		## ARC 2
		@wds = split( / /, $linewe[ $iwe2[0] ] );
		$b1 = $wds[ $iwe2[1] ];
		@wds = split( / /, $linesn[ $isn2[0] ] );
		$b2 = $wds[ $isn2[1] ];
		$delaz = $az - 90;
	}
	elsif ($quad == 3 ) {
		if ( $iz1 == 0 ) { 
			@isn1 = @iwe1 = ( 10, 0 );
			@isn2 = @iwe2 = (9,9);
		} else {
			@isn1 = ( 9 - int(($iz1-1)/10), 9-($iz1-1)%10 ); 
			@iwe1 = ( 9 - int(($iz1-1)/10), 9-($iz1-1)%10 );
			@isn2 = ( 9 - int(($iz2-1)/10), 9-($iz2-1)%10 );
			@iwe2 = ( 9 - int(($iz2-1)/10), 9-($iz2-1)%10 );
		}
		#print"isn=(@isn1,@isn2), iwe=(@iwe1,@iwe2)\n";
		## ARC 1
		@wds = split( / /, $linesn[$isn1[0]] );
		$a1 = $wds[ $isn1[1] ];
		@wds = split( / /, $linewe[$iwe1[0]] );
		$a2 = $wds[ $iwe1[1] ];
		#print"a1=$a1, a2=$a2\n";
		
		@wds = split( / /, $linesn[ $isn2[0] ] );
		$b1 = $wds[ $isn2[1] ];
		@wds = split( / /, $linewe[ $iwe2[0] ] );
		$b2 = $wds[ $iwe2[1] ];
		#print"b1=$b1, b2=$b2\n";
		$delaz = $az - 180;
	}
	else {  #quad == 4
		if ( $iz1 == 0 ) { 
			@isn1 = @iwe1 = ( 10, 0 );
			@isn2 = @iwe2 = (9,0);
		} else {
			@isn1 = ( 11 + int(($iz1-1)/10), ($iz1-1)%10 ); 
			@iwe1 = ( 9 - int(($iz1-1)/10), 9-($iz1-1)%10 );
			@isn2 = ( 11 + int(($iz2-1)/10), ($iz2-1)%10 );
			@iwe2 = ( 9 - int(($iz2-1)/10), 9-($iz2-1)%10 );
		}
		## ARC 1
		@wds = split( / /, $linewe[$iwe1[0]] );
		$a1 = $wds[ $iwe1[1] ];
		@wds = split( / /, $linesn[$isn1[0]] );
		$a2 = $wds[ $isn1[1] ];
		
		@wds = split( / /, $linewe[ $iwe2[0] ] );
		$b1 = $wds[ $iwe2[1] ];
		@wds = split( / /, $linesn[ $isn2[0] ] );
		$b2 = $wds[ $isn2[1] ];
		$delaz = $az - 270;
	}
	
	
	## INTERPOLATE AROUND THE ANNULUS OVER THE SEGMENT LIMITS.
	my $k1 = $a1 + ($a2-$a1) * $delaz / 90;
	my $k2 = $b1 + ($b2-$b1) * $delaz / 90;
	#printf"k1=%.5f, k2=%.5f\n", $k1, $k2;
	$corr = $k1 + ($k2 - $k1) * ($ze - $iz1);
	
	return $corr;
}



#======================================================
sub RelativeSolarVector
# CALLING:
# (sz_rel, saz_rel) = RelativeSolarVector( saz, sz, az, pitch, roll)
#  
#   calculates the angle between the solar ray and sensor normal
# INPUT
#    sz  solar zenith angle, deg
#    saz solar azimuth angle, deg
#    az  ship heading (compass), deg
#    pitch ship pitch (positive bow up), deg
#    roll  ship roll  (positive port up), deg
#OUTPUT (references (pointers))
# sz_rel = solar zenith angle relative to the sensor normal, deg
# saz_rel = solar azimuth relative to the sensor reference mark.
# HISTORY
#  copied from Matlab: reynolds 990710
# v101 060729 rmr -- converted to PERL. 
#  ======================================================================
# USE MODULE:  Math-MatrixReal-2.01 > Math::MatrixReal
# This can be down loaded from CPAN and installed in the usual way.
# The matrix transpose is used to determine the relative solar
# azimuth and zenith angle from the ship pitch-roll-heading.
# See MATLAB routine.
# use Math::MatrixReal
# use constant PI => 3.14159265358979;
# use constant D2R => PI / 180;
# use constant R2D => 180 / PI;
# use constant TWOPI => 2 * PI;
# use constant MISSING => -999;
{
	my $sz = shift();
	my $saz = shift();
	my $az = shift();
	my $p = shift();
	my $r = shift();
	#test printf "RelativeSolarVector: %.1f, %.1f, %.1f, %.1f, %.1f\n",$saz, $sz, $az, $p, $r;
	if ( $saz == MISSING || $sz == MISSING || $az == MISSING || $p == MISSING || $r == MISSING ) {
		return (MISSING, MISSING);
	}
	else {
		# ==== SOLAR UNIT VECTOR IN TRUE EARTH COORDINATES ============
		my ($Ssz, $Csz, $Ssaz, $Csaz, $a1, $a2, $a3, $amag, $SolarVector);
		$Ssz = sin ( $sz * D2R);
		$Ssaz = sin ( $saz * D2R);
		$Csz = cos ( $sz * D2R);
		$Csaz = cos ( $saz * D2R);
		$a1 = $Ssz * $Ssaz;
		$a2 = $Ssz * $Csaz;
		$a3 = $Csz;
		$amag = sqrt ($a1*$a1 + $a2*$a2 + $a3*$a3 );
		$SolarVector = Math::MatrixReal->new_from_cols( [ [$a1, $a2, $a3] ] );
		#test printf "Direct Normal Unit Vector: (%.3f,%.3f,%.3f) = %.3f\n",$a1,$a2,$a3,$amag;
		#test print"Solar Unit Vector:\n";
		#test print $SolarVector;
		
		# ==== TRANSFORMATION MATRIX ==============
		$upvec = Math::MatrixReal->new_from_cols([ [0,0,1] ] );
		my ($x_r, $T);
		($x_r, $T) = RotationTransform( $upvec, $p, $r, $az );
		#test print "TRANSFER MATRIX: \n";
		#test print $T;
		#test print "x_r,  UNIT VECTOR RELATIVE TO INSTRUMENT:\n";
		#test print $x_r;
		
		# ===== INVERSE TRANSFORM TO GET THE SOLAR BEAM RELATIVE TO THE INSTRUMENT ========
		my $Tinverse = $T->inverse;
		my $aplat = $Tinverse * $SolarVector;
		#test print"Solar Vec Rel to Instrument:\n";
		#test print $aplat;
		
		# ===== FINALLY THE RELATIVE VECTOR COMPONENTS ===========
		
		my $sz_rel = acos ( $aplat->element(3,1) ) * R2D;
		my $saz_rel = atan2 ( $aplat->element(1,1), $aplat->element(2,1) ) * R2D;
		if($saz_rel < 0 ) {$saz_rel += 360}
		
		return($sz_rel, $saz_rel);
	}
}


#======================================================
sub RotationTransform
#  ROTATION TRANSFORM
# CALLING:
# ($xtrue, $T) = RotationTransform($xrel, $pitch, $roll, $az);
#  
#  Computes the components of a vector in earth coordinates for any given
#  input
#   xrel is a 3x1 vector
#   pitch roll and azimuth are scalars
#  output
#   x = [3x1] vector
#  T = the rotation matrix to convert a vector in the platform frame
#     to a vector in the earth fram of reference.
#   x = Ta .* Tr .* Tp .* xrel = T .* xrel
#  
#  angles in degrees.
#   pitch positive for bow up
#  roll positive for port up
#  azimuth in standard copass coordinates
#  ===================================================================
# Matlab routine: reynolds 990710
# PERL version: 
# v101 060726 rmr -- adapt from MATLAB

# USE MODULE:  Math-MatrixReal-2.01 > Math::MatrixReal
# This can be down loaded from CPAN and installed in the usual way.
# The matrix transpose is used to determine the relative solar
# azimuth and zenith angle from the ship pitch-roll-heading.
# See MATLAB routine.
# use Math::MatrixReal
# use constant PI => 3.14159265358979;
# use constant D2R => PI / 180;
# use constant R2D => 180 / PI;
# use constant TWOPI => 2 * PI;
{
	my $xrel = shift();  #reference
	my $p = shift();
	my $r = shift();
	my $a = shift();
	my $x = shift();  #reference
	my $T = shift();  #reference
	#test printf"RotationTransform: pitch = %.2f, roll = %.2f, az = %.2f\n", $p, $r, $a;
  	
  	#test print"XREL:\n";
	#test print $xrel;
	
	my ($Cp, $Cr, $Ca, $Sp, $Sr, $Sa);
	my ($Tp, $Tr, $Ta);
	
	$Cp = cos($p * D2R);   $Sp = sin($p * D2R);
	$Cr = cos($r * D2R);   $Sr = sin($r * D2R);
	$Ca = cos($a * D2R);   $Sa = sin($a * D2R);
	
	$Tp = Math::MatrixReal->new_from_rows([ [1,0,0], [0, $Cp, -$Sp], [0, $Sp, $Cp] ]);
	$Tr = Math::MatrixReal->new_from_rows([ [$Cr, 0, $Sr], [0,1,0], [-$Sr, 0, $Cr] ]);
	$Ta = Math::MatrixReal->new_from_rows([ [$Ca, $Sa, 0], [-$Sa, $Ca, 0], [0,0,1] ]);
	#test print "Tp\n";
	#test print $Tp;
	#test print "Tr\n";
	#test print $Tr;
	#test print "Ta\n";
	#test print $Ta;
	
	$T = $Ta * $Tr * $Tp;
	#test print "T:\n";
	#test print $T;
	
	$x = $T * $xrel;
  	#test print"X:\n";
	#test print $x;
	return ($x, $T);
}


# ================================================
sub Ephem
# CALL: (az, ze, ze0) = Ephem(lat, lon, dt); 
# function [az, ze, ze0] = Ephem(lat, lon, dt);
# pro sunae1,year,day,hour,lat,long,az,el
#       implicit real(a-z)
# Purpose:
# Calculates azimuth and elevation of sun
# 
# References:
# (a) Michalsky, J. J., 1988, The Astronomical Almanac's algorithm for
# approximate solar position (1950-2050), Solar Energy, 227---235, 1988
# 
# (b) Spencer, J. W., 1989, Comments on The Astronomical
# Almanac's algorithm for approximate solar position (1950-2050)
# Solar Energy, 42, 353
# 
# Input:
# year - the year number (e.g. 1977)
# day  - the day number of the year starting with 1 for
#        January 1
# time - decimal time. E.g. 22.89 (8.30am eastern daylight time is
#        equal to 8.5+5(hours west of Greenwich) -1 (for daylight savings
#        time correction
# lat -  local latitude in degrees (north is positive)
# lon -  local longitude (east of Greenwich is positive.
#                         i.e. Honolulu is 15.3, -157.8)
# Output:
# az - azimuth angle of the sun (measured east from north 0 to 360)
# el - elevation of the sun not currently returned
# ze - zenith angle at Earth's surface
# ze0 - zenith angle at top of atmosphere
# Spencer correction introduced and 3 lines of Michalsky code
# commented out (after calculation of az)
# 
# Based on codes of Michalsky and Spencer, converted to IDL by P. J.  Flatau

# 2001 rmr conversion from IDL to Matlab.
#  Reynolds 010318 -- remove singularity at line 142.
# 060629 rmr -- Converted from IDL to Matlab years before and today
#  converted from matlab to PERL.  This perl version was checked against
#  the matlab function and exactly matches.
#Test Ephem LAT: -11, LON: 130, DATE: 2006-02-01 (032) 03:00:00
#                 AZ=24.143,  ZE=13.227, ZE0=13.239

# REQUIRED PERL SUBROUTINES:
#  datevec() --

#v101 060629 rmr -- convert from matlab to perl
#================================================
{
# 	use constant PI => 3.14159265358979;
# 	use constant D2R => PI / 180;
# 	use constant R2D => 180 / PI;
# 	use constant TWOPI => 2 * PI;
	my $lat = shift();  my $lon = shift();  my $dt = shift();
	#printf "BEGIN SUBROUTINE Ephem( %.5f, %.5f, %s )\n", $lat, $lon, dtstr($dt,'short');
	
	my ($yy, $MM, $dd, $hh, $mm, $ss);
	my ($hour, $jd, $jdf);
	
	($yy, $MM, $dd, $hh, $mm, $ss, $jdf) = datevec($dt); # day components
	$hour=$hh + $mm/60 + $ss/3600;
# 	printf "YEAR: %d, MONTH: %d, DAY: %d, HOUR: %d, MIN: %d, SEC: %s, JD: %d\n",
# 	 $yy, $MM, $dd, $hour, $mm, $ss, $dd;

	# get the current Julian date
	my $delta = $yy - 1949.;
	my $leap = int( $delta / 4 );
	$jd = 32916.5 + $delta * 365 + $leap + int($jdf) + $hour / 24;
# 	printf "YY: $yy, DAY: $dd, DELTA: $delta, LEAP: $leap, JDAY: %.6f\n", $jd;
	
	# calculate ecliptic coordinates
	my $time = $jd - 51545.0;
# 	printf"TIME: %.6f\n", $time;
	
	# force mean longitude between 0 and 360 degs
	my $mnlong = 280.460 + 0.9856474 * $time;
	#printf"MNLONG = %.6f\n", $mnlong;
	$mnlong -= 360 * int($mnlong/360);
	if ( $mnlong < 0 ) { $mnlong += 360 }
	if ( $mnlong > 360 ) { $mnlong -= 360 }
# 	printf"MNLONG = %.6f\n", $mnlong;
	
	# mean anomaly in radians between 0, 2*pi
	my $mnanom = 357.528 + 0.9856003 * $time;
	#$mnanom = $mnanom%360;
	$mnanom -= 360 * int($mnanom/360);
	if ( $mnanom < 0 ) { $mnanom += 360 }
	$mnanom *= D2R;
# 	printf"MNANOM = %.6f\n", $mnanom;
	
	# compute ecliptic longitude and obliquity of ecliptic
	#eclong=mnlong+1.915*(mnanom)+0.20*sin(2.*mnanom);
	my $eclong = $mnlong + 1.915 * sin($mnanom) + 0.020 * sin(2 * $mnanom);
	$eclong -= 360 * int($eclong/360);
	if ( $eclong < 0 ) { $eclong += 360 }
	$eclong *= D2R;
# 	printf"ECLONG: %.6f\n", $eclong;
	
	my $oblqec = 23.429 - 0.0000004 * $time;
	$oblqec *= D2R;
# 	printf"OBLQEC: %.6f\n", $oblqec;
	
	# calculate right ascention and declination
	my $num = cos($oblqec) * sin($eclong);
	my $den = cos($eclong);
	my $ra = atan($num / $den);
# 	print"NUM: $num, DEN: $den,  RA: $ra\n";
	
	# force ra between 0 and 2*pi
	if ( $den < 0 ) { $ra += PI }
	elsif ( $den >= 0 ) { $ra += TWOPI }
	
	# dec in radians
	my $dec = asin( sin($oblqec) * sin($eclong) );
# 	printf"RIGHT ASCENSION: %.6f, DECLINATION: %.6f\n",$ra, $dec;
	
	# calculate Greenwich mean sidereal time in hours
	my $gmst = 6.697375 + 0.0657098242 * $time + $hour;
	#print"GMST: $gmst\n";
	
	# hour not changed to sidereal sine "time" includes the fractional day
	$gmst -= 24 * int($gmst/24);
	#printf"GMST: %.6f\n", $gmst;
	if ( $gmst < 0 ) { $gmst += 24 }
# 	printf"GMST: %.6f\n", $gmst;
	
	# calculate local mean sidereal time in radians
	my $lmst = $gmst + $lon / 15;
	$lmst -= 24 * int($lmst/24);
	if ( $lmst < 0 ) { $lmst -= 24}
	$lmst = $lmst * 15 * D2R;
# 	printf"LMST: %.6f\n", $lmst;
	
	# calculate hour angle in radians between -pi, pi
	my $ha = $lmst - $ra;
	if ( $ha < -(PI) ) { $ha += 2*PI }
	if ( $ha > PI ) { $ha -= TWOPI }
# 	printf"HA: %.6f\n", $ha;
	
	# calculate azimuth and elevation
	$lat *= D2R;
	my $el = asin( sin($dec) * sin($lat) + cos($dec) * cos($lat) * cos($ha) );
	my $az = asin( -cos($dec) * sin($ha) / cos($el) );
	
	#========================
	# add J. W. Spencer code
	#========================
	if ( $lat == 0 ) { $lat += 1e-5 } # move awat from a singularity	
	my $elc = asin( sin($dec) / sin($lat) );
	if ( $el >= $elc ) { $az = PI - $az }
	if ( $el <= $elc && $ha > 0 ) { $az = 2*PI + $az }
# 	printf"EL: %.6f, AZ: %.6f\n", $el, $az;
	
	#=================
	# REFRACTION
	#=================
	my $refrac;
	# this puts azimuth between 0 and 2*pi radians
	# calculate refraction correction for US stand. atm.
	$el *= R2D;
	if ( $el > -0.56 ) {
		$refrac = 3.51561 * (0.1594 + 0.0196 * $el + 0.00002 * $el*$el) /
	     (1 + 0.505 * $el + 0.0845 * $el*$el)
	} else { $refrac = 0.56 }
# 	printf"REFRAC: %.6f\n", $refrac;
	#$refrac = 0.56;
	
	my $ze0 = 90 - $el;
	my $ze = 90 - ($el + $refrac);
	$az *= R2D;
	if ( $az < 0 ) { $az += 360 }
	#printf"ZE0: %.6f,  ZE: %.6f, AZ: %.6f\n", $ze0, $ze, $az;
	return($az, $ze, $ze0);
}


#*************************************************************/
# sub NormalIrradiance
# {
# 	$normerr = $horizerr / cos( $ze * D2R );
# 	$normerr = $horizerr + $horizerr;
# 	return;
# }

#*************************************************************/
sub EdgeAndShadow
# This routine uses the 2-min sweep stats to estimate the two 
# edge values and to determine the best edge value to use.  It also estimtes
# the error in the final edge value.
# CALL: ($edge,$shadow) = EstimateEdge($index1, $index2, $index0, $sweep); 
#  Where $sweep is the complete string for the channel
# Consider bins index1 and index2 are the correct bins.
{
	my ($i);
	my $i1 = shift();  my $i2 = shift(); my $i0 = shift();
	my $str = shift();
	$str =~ s/^[ ]+//;  # remove leading spaces
	my @d = split(/[ ]+/,$str);
	#print"i1=$i1, i2=$i2, d = @d\n";
	my $e1 = $d[$i1];
	my $e2 = $d[$i2];
	my $sh = $d[$i0];
	#print"edge1 = $e1,   edge2 = $e2\n";

	return (($e1+$e2)/2, $sh);	
}


#*************************************************************/
#   TIME TOOLBOX
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
{
	my ($tm, $fmt);					# time hash
	my ($str, $n);					# out string
	# use Time::localtime;		# use Time module
	
	$n = $#_;
	$tm = localtime(shift);		# convert incoming epoch secs to hash
	# ==== DETERMINE THE FORMAT TYPE =============
	$fmt = 'long';	
	if ( $n >= 1 ) {  $fmt = shift() }
	
	if ( $fmt =~ /long/i ) {
		$str = sprintf("%04d-%02d-%02d (%03d) %02d:%02d:%02d" ,
			$tm->year+1900, $tm->mon+1, $tm->mday, $tm->yday+1,$tm->hour, $tm->min, $tm->sec);
	}
	elsif ( $fmt =~ /short/i ) {
		$str = sprintf("%04d%02d%02d,%02d%02d%02d" ,
			($tm->year+1900), $tm->mon+1, $tm->mday, $tm->hour, $tm->min, $tm->sec);
	}
	elsif ( $fmt =~ /jday/i ) {
		$str = sprintf("%02d-%03d" , $tm->year-100, $tm->yday+1);
	}
	elsif ( $fmt =~ /prp/i ) {
		$str = sprintf("%02d%02d%02d" , $tm->year-100, $tm->mon+1, $tm->mday);
	}
	elsif ( $fmt =~ /csv/i ) {
		$str = sprintf("%04d,%02d,%02d,%02d,%02d,%02d" ,
			($tm->year+1900), $tm->mon+1, $tm->mday, $tm->hour, $tm->min, $tm->sec);
	}
	# SPACE SEPARATED VARIABLES
	elsif ( $fmt =~ /ssv/i ) {
		$str = sprintf("%04d %02d %02d %02d %02d %02d" ,
			($tm->year+1900), $tm->mon+1, $tm->mday, $tm->hour, $tm->min, $tm->sec);
	}
	elsif ( $fmt =~ /scs/i ) {
		$str = sprintf ( "%02d/%02d/%04d,%02d:%02d:%02d", 
			$tm->mon+1, $tm->mday, ($tm->year+1900), $tm->hour, $tm->min, $tm->sec);
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
# ver 2 rmr 100314 -- add jdf to output string
{
	my $tm = localtime(shift);
	($tm->year+1900, $tm->mon+1, $tm->mday, $tm->hour, $tm->min, $tm->sec,
		$tm->yday+1 + $tm->hour/24 + $tm->min/1440 + $tm->sec/86400);
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

# ****************************************************************
sub dt2jdf
{
 # call with ($yyyy,$jdf) = dt2jdf($dtsecs)
 # from PERL ref $tm = localtime($TIME);     # or gmtime($TIME)
 # input
 #   $dtsecs = epoch seconds as from the timegmt()
 # output array
 #  0  yyyy = year as four digit number
 #  1  year day integer
 #  2  f.p. year day
 # 2006-3-13
 #v101 060629 rmr -- start config control
 #v102 060629 rmr -- add use 
	use Time::localtime;		# v102 use Time module
	my ($tm);
	$tm = localtime($_[0]);
	return (
	    $tm->year+1900, 
	    $tm->yday+1 + $tm->hour/24 + $tm->min/1440 + $tm->sec/86400);
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
sub polyval
# y = polyval (a, x);
#   y = ((( a_n * x + a_(n-1) ) * x + a_(n-2) )... * x + a0 ) ...
#example: a = (1,2,3)
#  y = 1 + 2 * x + 3 * x^2;
{
	my $i;
	my ($x, $y);
	my @a = @_;
	$x = pop(@a);
	$y = $a[$#a];  # start with the nth term
	$i = $#a-1;
	while ( $i >= 0 )
	{ 
		$y = $y * $x + $a[$i];
		$i--;
	}
	return ( $y );
}


#// NOTES -- UTILITY TOOL BOX
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
# ver 1.4 rmr 100313 -- increase search limit to 500 lines.
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
		if ( $rec >= 500 || eof(Finfo) ) { 
			$strout = 'STRING NOT FOUND';
			print"STRING \"$strin\" NOT FOUND\n";
			die;
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
#=======================================================
sub WaitSec {
	
	my $waitsec = shift();
	my ($then, $now);
	$then = $now = now();
	while ( $now - $then < $waitsec ) {
		$now = now();
	}
	return;
}
