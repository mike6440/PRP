function [d] = TripDistance(lon,lat,sog),
%
%function [d] = TripDistance(lon,lat,sog),
%==============
% COMPUTE TOTAL TRIP DISTANCE TRAVELED FROM LON AND LAT
%
%INPUT
% lon, lat = vectors of position in deg.
% sog = SOG in m/s from GPS.
%
%1. Remove all NaNs
%2. Remove all fixes where SOG < 0.1 m/s.
%3. Compute distance for each sequential pair.
%4. Add segments together.
%
%
clear;
load('/Users/rmr/data/ata/level2/all_2min.mat')
lat = lat_gps;
lon = lon_gps;
sog = sog_gps;

ix = find(isnan(lon));
iy = find(isnan(lat));
iz = union(ix,iy);

lon(iz)=[];
lat(iz)=[];
dt(iz)=[];
sog(iz)=[];

iz = find(sog < 0.01);
lon(iz)=[];
lat(iz)=[];
dt(iz)=[];
sog(iz)=[];


%difference in nm
dx = diff(lon) .* cos(lat(1:end-1) * pi / 180) * 60;
dy = diff(lat) * 60;
dd = sqrt(dx .* dx + dy .* dy);
d = sum(dd);
fprintf('Trip Distance = %d nm\n', fix(d));

return
