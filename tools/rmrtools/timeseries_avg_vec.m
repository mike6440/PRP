function [dt, spd, dir, stdspd, sigtheta] = timeseries_avg_vec(dtx,spdx,dirx,delt, dt1, dt2),
%function [dt, spd, dir, stdspd, sigtheta] = timeseries_avg_vec(dtx,spdx,dirx,delt, dt1, dt2),
% Average a vector time series (in polar coordinates) with a time interval of delt.
% The output time is the center of the averaging interval.
%INPUT
%  dtx = time base
%  spdx = speed, equivalent to vector magnitude
%  dirx = direction (compass based)
%  delt = averaging interval, seconds
%  dt1,dt2 (optional) the beginning and end times for the series.
%OUTPUT
%  dt = new time base, centered on the averaging interval
%  spd = mean vector magnitude
%  dir = vector mean direction
%  stdspd = standard deviation of the vector magnitude
%  sigtheta = directional standard deviation (Yamartino)
%
%ORIGINATED: reynolds 060718

% TEST
% display('START TEST OF PROGRAM timeseries_avg_vec.m');
% clear
% load ~/data/urban/mid/level1/bnlmet/bnlmet_06040_06074.mat
% dtx = dt;
% spdx = ws2;
% dirx = wd2;
% delt = 900;
% dt1 = datenum(2006,2,10,12,0,0);
% dt2 = datenum(2006,3,15,0,0,0);


%fprintf('VECTOR TIME SERIES AVERAGE FROM %s TO %s\n',dtstr(dt1,'short'), dtstr(dt2,'short'));


%=====================
% STEP ONE -- DEFINE THE AVG BLOCK TIMES
%   AND GET THE AVG BLOCK INDEXES
%=====================
deltd = delt/86400;						% avg interval in day units
N = fix( (dt2 - dt1) / deltd ) + 1;		% number of avg data points
dtav = (dt1 - deltd/2) + [0:N-1]' .* deltd; % start times of each avg block
[ia,ib] = MakeTimeBlocks(dtx,dtav);		% define indexes of each block

%=====================
% STEP TWO -- AVERAG EACH BLOCK
%=====================
spd = nan * ones(N-1,1);  dir = spd;		% avg arrays pre set to NaN
stdspd = spd;  sigtheta = spd;
for i=1:N-1								 % for each 2-min time period
	if rem(i,1000)==0, fprintf('%d ',i); end % diagnostic print out
	if ~isnan(ia(i)) & ~isnan(ib(i)),	% skip bad indexes
		[spd(i), dir(i), stdspd(i), sigtheta(i)] = VecMean( spdx([ia(i):ib(i)]), dirx([ia(i):ib(i)]) );
	end
end
dt = dtav(1:N-1)+deltd/2;						% output time series

return
