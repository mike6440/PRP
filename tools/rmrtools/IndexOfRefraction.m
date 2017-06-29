function [n] = IndexOfRefraction(w,co2ppm)
%function [n] = IndexOfRefraction(w,co2ppm)
%====================================================
% COMPUTE ATMOSPHERIC INDEX OF REFRACTION ON THE EARTH
%
% Taken from Bodhaine et. al, "ON Rayleigh Depth Calculations"
% JTEC, 16, 1854-1861.
%
%input
%  w = wavelength in nanometers
%  co2 = co2 concentration in parts per million by volumn
%  lat = latitude if f.p. degrees
%output
%  g = gravity in m/s^2
%
% reynolds 010726
%======================================================

% test clear, w = 500;  co2ppm = 360;

wu = w / 1000;  % convert from nm to microns
co2 = co2ppm / 1e6;  %  (e.g. 360 ppm => 0.00036)

%========================
% INDEX FOR DRY AIR AT 300 PPM CO2
%========================
n1300 = 8060.51 + 2480990 ./ (132.274 - wu^-2) + 17455.7 ./ (39.32957 - wu^-2); 

%========================
% Scale for desired co2
%========================
r = 1 + 0.54 * (co2 - 0.0003);
n1 = n1300 .* r;

n = n1 ./ 1e8 + 1;

return;
