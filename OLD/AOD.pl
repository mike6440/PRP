#!/usr/bin/perl -w
my $PROGRAMNAME = 'AOD.pl';
my $VERSION = '06';  
my $EDITDATE = '111207';

# CALL
#    perl AOD.pl
# alias AOD='cd $prppath;  	./AOD.pl $SetUp data'

# AOD_tst.pl is used for reading code and making comments.
# There are NO changes here from the original code.

use lib $ENV{DAQLIB};
use perltools::MRtime;
use perltools::MRutilities;
use perltools::MRsensors;
use perltools::MRstatistics;
use perltools::prp;
use perltools::MRradiation;
use POSIX;

my $setupfile = shift();
print "SETUP FILE = $setupfile. ";
if ( ! -f $setupfile ) {print "SETUP FILE DOES NOT EXIST, QUIT\n"; die}
else {print"   EXISTS.\n"}

# RT PROCESSING
my $datapath = FindInfo($setupfile,"RT OUT PATH", ":");
print "DATAPATH = $datapath\n";

#====================
# PRE-DECLARE SUBROUTINES
#====================

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

my($i, $j, $str, $pgmstart, $avgsecs, $fnout, $fnrawout, $outfile, $datapath);
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

my $prpsn = FindInfo($setupfile,'PRP SERIAL NUMBER', ': ');
$header = $header."PRP SERIAL NUMBER: $prpsn\n";

my $rsrsn = FindInfo($setupfile,'FRSR SERIAL NUMBER', ': ');
$header = $header."FRSR SERIAL NUMBER: $rsrsn\n";

my $headsn = FindInfo($setupfile,'HEAD SERIAL NUMBER', ': ');
$header = $header."MFR HEAD SERIAL NUMBER: $headsn\n";

my $rsravgsecs = FindInfo($setupfile,'RSR AVERAGING TIME', ': ');
$header = $header."RSR AVERAGING TIME (secs): $rsravgsecs\n";

my $tcmhub = FindInfo($setupfile,"TCM HUB COM NUMBER",":");
$header=$header."TCM COM HUB NUMBER: $tcmhub\n";

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
$datapath =  FindInfo($setupfile,'RT OUT PATH', ': ');
if ( ! -d $datapath ) { print"!! RT OUT PATH - ERROR, $datapath\n"; die }

while(1){
	@rsr1=();  @dat=();  @datrsr=(); @g1=(); @g2=(); @global=();
	@edge=(); @shadow=(); @horiz=(); @diffuse=(); @normal=();
	@Kze=();
	$dtnow = now();
	# FOR TIME DELAY BEFORE PROCESSING
	if( $dtnow >= $dt1 ) {
		# DOES THE RSR FILE EXIST?
		$rsrok = 0;
		chomp($rsrfile = `find $datapath -maxdepth 1 -name "rsr_avg*.txt" -mtime 0 > tmprsr; tail -n 1 tmprsr; rm tmprsr`);
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
			chomp($tcmfile = `find  $datapath -maxdepth 1 -name "tcm_avg*.txt" -mtime 0   > tmpxx; tail -n 1 tmpxx; rm tmpxx`);
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
			chomp($gpsfile = `find $datapath  -maxdepth 1 -name "gps_avg*.txt" -mtime 0  > tmpxx; tail -n 1 tmp; rm tmpxx`);
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
		die;
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
					$fnhdr = $datapath."/aod".$str.".hdr";
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
						$fn= $datapath."/aod".$str.".da".$ichan;
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



