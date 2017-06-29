function g = gravity(z, lat)
%function g = gravity(z, lat)
%====================================================
% COMPUTE GRAVITY ON THE EARTH
%
% Taken from Bodhaine et. al, "ON Rayleigh Depth Calculations"
% JTEC, 16, 1854-1861.
% They, in turn, reference List (1968) Smithsonian Meteorological Tables.
%
%input
%  z = altitude in m above s.l.
%  lat = latitude if f.p. degrees
%output
%  g = gravity in cm/s^2
%
% reynolds 010726
%======================================================

% test lat=0;  z = 5000;


d2r = pi/180;
cos2phi = cos(d2r * lat * 2);

% ==============
% GRAVITY AT SEA LEVEL
%===============
g0 = 980.6160 * (1 - 0.0026373 * cos2phi + 0.0000059 * cos2phi^2);

if z == 0,
    g = g0;
else
    zc = (0.73737 * z) + 5517.56;
    g = g0 ...
        -(3.085462e-4 + 2.27e-7 * cos2phi) * zc ...
        +(7.254e-11 + 1e-13 * cos2phi) * zc^2 ...
        - (1.517e-17 + 6e-20 * cos2phi) * zc^3;
end

g = g/100;  % convert to m/s^2

%fprintf('grav = %.6f\n', g);

return
