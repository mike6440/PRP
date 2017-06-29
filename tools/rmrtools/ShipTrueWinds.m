function [wspd_true, wdir_true] = ShipTrueWinds(wspd_app, wdir_app, sog, cog, hdg),
%function [wspd_true, wdir_true] = ShipTrueWinds(wspd_app, wdir_app, sog, cog, hdg),
%=======================================
% Compute true wind speed and direction from 
% input:
%  wspd_app = apparent wind speed (kts or m/s)
%  wdir_app = apparent wind direction (rel to bow)
%  sog = speed over ground (same as wspd)
%  cog = ship course over ground (GPS)  0-360 deg
%  hdg = ship heading, gyro,  0--360 deg
% output:
%  wspd_true (same as input units, kts or m/s)
%  wdir_true (deg)
%
% Speed units can vary but they must all be the same, e.g. m/s
% Apparent wind is the wind actually measured by an anemometer.
% Relative winds are the apparent winds in the true north coordinate system
%========================================
% testing
%[wst, wdt] = ShipTrueWinds(40, 10, 7, 65, 65) ==> 25.36 kts at 80.89 deg


% clear;
% wspd_app = 10;
% wdir_app = 45;
% hdg = 270;
% sog = 14;
% cog = 270;


r2d = 180/pi;
d2r = pi/180;

%fprintf('\n\nApparent winds: %.2f at %.1f degA\n', wspd_app, wdir_app);

% ==============
% COMPUTE WINDS IN THE TRUE COORDINATE SYSTEM
% A SIMPLE ROTATION USING HEADING
%===============
% REL WIND VECTOR
wdir_rel = CompassCheck(wdir_app + hdg);
[ur,vr] = MetP2V(wspd_app, wdir_rel);
%fprintf('hdg = %.1f, rel vector = (%.2f, %.2f)\n', hdg, ur, vr);


% SHIP SPEED VECTOR
[us, vs] = MetP2V(sog, cog);
us = -us; vs = -vs;    
%fprintf('sog = %.1f,  cog = %.1f, ship vector = (%.2f, %.2f)\n', sog, cog, us, vs);


% TRUE WIND VECTOR
ut = ur + us;
vt = vr + vs;

% TRUE WIND IN MET POLAR COOR
[wspd_true, wdir_true] = MetV2P(ut, vt);
%fprintf('True winds = (%.2f, %.2f) = %.2f at %.1f degT\n', ut, vt, wspd_true, wdir_true);

return



