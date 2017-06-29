%function [csp,cdir] = ShipTrackStats(dt,lat,lon),


D2R = pi / 180;

% DISTANCE BETWEEN POINTS
lt=[];
for i=2:length(lat),
	lt = [lt; (lat(i-1)+lat(i))/2];
end
dx = cos(D2R*lt) .* diff(lon) .* 60;  %minutes
dy = diff(lat)*60;  %minutes
r = sqrt(dx.*dx + dy .* dy);

s = r ./ diff(dt) ./ 24;



return
