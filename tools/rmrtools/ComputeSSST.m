%*************************************************************/
sub ComputeSSST
%
%CALL:
%    $ss = perltools::Isar::ComputeSSST($T1, $T2, $kt1, $kt2, $ktsea, $ktsky,$pointangle, 
%		$pitch, $roll, $e0, $e_bb, $Acorr, $CalOffset, $kv, $missing, $ktfile, $ttr, $rtr);
%where
	% $T1 = black body 1, ambient, temperature, degC
	% $T2 = heated BB temp, degC
	% $kt1, $kt2, $ktsea, $ktsky = kt15 readings for the different pointing angles, adc counts or mV
	% $pointangle = the pointing angle, relative to the isar, for the sea view, deg. Typ 125 or 135 deg.
	% $pitch = nose up tilt angle. (connectors facing the bow).
	% $roll = port side: port up tilt angle.  stbd side: port down tilt angle.
	% $e0 = nominal emissivity value
	% $e_bb = estimated emissivity of the black bodies, usually set to 1.
	% $Acorr = calibration parameter, multiplier of the interpolation slope. Typ = 1 +/- 0.01
	% $CalOffset = final sst adjustment, deg C. Typ +/-0.1.
	% $kv = 0 or 1 for nonverbal or verbal. Set to zero during operation.
	% $missing = value for bad data, usually = -999
	% $ktfile = path/filename for the kt15 calibration file.
	% $ttr = reference to the planck table temperature, from the MakeRadTable_planck() function.
	% $rtr = ditto for radiance.
% example
%		use lib "/Users/rmr/swmain/perl";
%		use perltools::Isar;
%		my $ktfile= "/Users/rmr/swmain/apps/isardaq4/kt15/kt15_filter_15854832.dat";
%		my ($ttr, $rtr) = perltools::Isar::MakeRadTable_planck($ktfile);
% 		@xx1=(8.789, 28.131,530.6, 588.3, 529.6, 323.5,135,0.0,0.5, 0.98667, 1.0, 1.0175, 0.060, $kv, -999, $ktfile, $ttr, $rtr);
% 		$ss = perltools::Isar::ComputeSSST(@xx1);
% gives Tskin=9.508, Tcorr=-0.3312, Tuncorr=9.1770  
%v3 110506 rmr -- moved to perl module Isar.pm
{
	my ($T1, $T2, $kt1, $kt2, $ktsea, $ktsky,$pointangle, $pitch, $roll, $e0, $e_bb, $Acorr, $CalOffset, $kv, $missing, $ktfile, $ttr, $rtr) = @_;
	my ($e_sea, $S_1, $S_2, $S_k, $S_1v, $S_2v, $S_upwelling, $Ad, $S_dv, $Au, $S_uv, $S_skin, $T_uncorr, $T_skin);
	print "test ComputeSSST: @_\n";
	
	@tt = @{$ttr};
	@rt = @{$rtr};
	%$i=0; foreach(@tt){ printf"%4d %.6e  %.6e\n", $i, $tt[$i], $rt[$i]; $i++}

	%=======================
	% COMPUTE ONLY IF WE HAVE ALL THE DATA
	%======================
	if ( $ktsky != $missing && $ktsea != $missing &&
	$kt1 != $missing && $kt2 != $missing &&
	$T1 != $missing && $T2 != $missing )
	{
		% SEA EMISSIVITY BASED ON VIEW ANGLE
		% v4.0 check if we have pitch and roll data.  For this first effort we will use
		% only roll.  A positive roll decreases the isar view angle.  i.e. if the view angle is 
		% 125 deg and the roll is +2 deg then the corrected view angle is 123 deg.  And the nadir
		% angle is 57 deg.
		if ( $pitch == $missing || $roll == $missing ) {
			$e_sea = $e0;
			if ($kv == 1 ) { printf "ROLL MISSING -- e_sea set to e_sea_0 = %.5f\n", $e_sea}
		} else {
			%% CORRECT VIEW ANGLE BY THE ROLL
			$actualviewangle = $pointangle - $roll;
			%% COMPUTE EMISSIVITY FROM THE POINTING ANGLE
			$e_sea = GetEmis( $actualviewangle, $missing );
			if ($kv == 1 ) { print  "e_sea = $e_sea, e_sea_0 = $e0 \n" }
		}
		if ( $e_sea < 0 ) {
			print "<<ROLL ERROR -- e_sea set to e_sea_0>>\n";
			$e_sea = $e0;
			if ($kv == 1 ) { printf "ROLL ERROR -- e_sea set to e_sea_0 = %.5f\n", $e_sea}
		}
		
		%===================
		% BB RADIANCES
		%
		$S_1 = GetRadFromTemp ($ttr, $rtr, $T1);
		if ($kv != 0 ) { printf("<<T1 = %.3f,  S_1 = %.4e>>\n", $T1, $S_1); }
		$S_2 = GetRadFromTemp($ttr, $rtr, $T2);
		if ($kv != 0 ) { printf("<<T2 = %.3f,  S_2 = %.4e>>\n", $T2, $S_2); }
		
		$S_k = $S_1;  % planck radiance from the kt15 lens
		% VIEW IRRADIANCES DEPEND ON THE EMISSIVITIES OF THE BB'S AND SOURCE
		$S_1v = $e_bb * $S_1 - ( 1 - $e_bb ) * $S_k;
		$S_2v = $e_bb * $S_2 - ( 1 - $e_bb) *  $S_k;
		
		my $Ad;
		my $S_upwelling;
		%-------------------------------
		% --- FIELD EXPERIMENT WITH SKY CORRECTION
		%--------------------------------
		% ---DOWN VIEW RADIANCE---
		% Ad = (kd-k1) ./ (k2-k1);
		if ($kv != 0 ) { printf("<<kt sea sky bb1 bb2 =  %.4f, %.4f, %.4f, %.4f>>\n", 
			$ktsea, $ktsky, $kt1, $kt2 );
		}
		$Ad = ( $ktsea - $kt1 ) / ( $kt2 - $kt1 );
		if ($kv != 0 ) { printf("<<Ad = %.4f>>\n", $Ad );}
		
		% Correct for the irt beam spread
		$Ad = $Acorr * $Ad;
		if ($kv != 0 ) { printf("<<Corrected Ad = %.4f>>\n", $Ad); }
		
		% DOWN VIEW INCOMING IRRADIANCE BY INTERPOLATION
		my $S_dv = $S_1v + ($S_2v - $S_1v) * $Ad;
		if ($kv != 0 ) { printf("<<Sea view upwelling, S_dv = %.4f>>\n", $S_dv); }
		
		% --- UP VIEW RADIANCE ---
		% interpolation constant
		my $Au = ( $ktsky - $kt1 ) / ( $kt2 - $kt1 );
		if ($kv != 0 ) { printf "<<Au = %.4f>>\n", $Au }
		$Au = $Acorr * $Au;
		if ($kv != 0 ) { printf "<<Corrected Au = %.4f>>\n", $Au }
		my $S_uv = $S_1v + ( $S_2v - $S_1v) * $Au;
		if ($kv != 0 ) { printf("<<Downwelling from sky view, S_uv = %.4f>>\n", $S_uv); }
		
		%======================
		% UPWELLING SKY IRRADIANCE
		%=======================
		$S_upwelling = $S_uv * ( 1 - $e_sea );
		if ($kv != 0 ) { printf("<<Reflected sky, S_upwelling = %.4f>>\n", $S_upwelling); }
		
		%======================
		% SEA SURFACE RADIANCE
		% view radiance minus the upwelling
		%=====================
		my $S_skin;
		$S_skin = ($S_dv - $S_upwelling) / $e_sea;
		if ($kv != 0 ) { printf("<< Brightness radiance from the sea, S_skin = %.4f>>\n", $S_skin); }
		
		% ===================
		% COMPUTE SSST FROM THE TABLE
		%====================
		printf"Rad2Temp: S_dv=%.3f, e_sea=%.5f\n", $S_dv, $e_sea; % TEST
		$T_uncorr = GetTempFromRad($ttr, $rtr, $S_dv / $e_sea);  % without sky correction
		$T_skin = GetTempFromRad($ttr, $rtr, $S_skin);
		% v05 add calibration correction
		$T_skin += $CalOffset;  % v05
		$T_corr = $T_uncorr - $T_skin;   % the correction for sky reflection
	}
	else {
		$T_uncorr = $T_skin = $T_corr = $missing;
		$e_sea = 0;
	}
	printf"Tskin=%.3f, Tcorr=%.4f, Tuncorr=%.4f\n",$T_skin, $T_corr, $T_uncorr;
	die;
	return ($T_skin, $T_corr, $T_uncorr);
}
