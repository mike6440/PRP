function [dtmx, xmx] = MaxSeries(dt,x,deltin,avgsecs,dt1,dt2);
% function [dtmx, xmx,xavstd] = MaxSeries(dt,x,deltin,avgsecs);
% MAX VALUE IN A TIME SERIES USING TIME CENTERED TIME BLOCKS
%
%input
%  dt = datenum in
%  x = input series
%  deltin = input sample spacing, secs
%  avgsecs = output sample spacing, secs
% dt1, dt2 = final 
%output
%  (dtmx,xmx) = averaged series
%  xavstd = sample standard deviation
%
%The output time is selected to be even time blocks over a day. 
% e.g. for avgsecs=600 secs, times are at 0, 10, 20, ... minutes
% and the sample periods are centered over the time marks.

% clear
% load('/Users/rmr/data/ice/iceprp04/level1/da0_av120.mat')
% nargin = 4;
% avgsecs=600;
% deltin = 120;
% x = sw;

% dt is the input time base
% x is the input series
% dt1, dt2 are the averaging start and stop times
%avgsecs = the averaging period in seconds

% fprintf('AvgSeries: Nx = %d, deltin = %.1f, avgsecs = %d\n',length(dt), deltin, avgsecs);

if nargin <= 4, dt1= dt(1); dt2=dt(end); end
if deltin > avgsecs, fprintf('!! ERROR, DELTIN > AVGSECS\n');  error; end

% Find the nearest start time centered on an averaging period
% === STARTT TIME
[y,jdf] = dt2jdf(dt1);          % f.p. year day
sdy = rem(jdf,1)*86400;         % second of the dat
s1 = fix(sdy/avgsecs)*avgsecs/86400; % nearest second for an even sample
dta = jdf2dt(y, fix(jdf)+s1);     % in datenum format
% ==== END TIME
[y,jdf] = dt2jdf(dt2);
sdy = rem(jdf,1)*86400;
s1 = fix(sdy/avgsecs)*avgsecs/86400;
dtb = jdf2dt(y,fix(jdf) + s1);


% make a full time series between dta and dtb
[dtf, xf] = FillTimeSeries(dt, x, deltin/60, dta - (avgsecs/2 - deltin) /86400, dtb + (avgsecs/2 - deltin) / 86400 / 2);
Nx = length(xf); % the full length of all points.

% NUMBER OF POINTS TO COMPARE
Nav = round((dtb - dta)*86400/avgsecs);

% INDEXES OF THE DIFFERENT BLOCKS
iav = [1:Nav]';
ix1 = fix((iav - 1) * Nx / Nav)+1;
ix2 = fix(iav * Nx / Nav);

dtmx = dta + (iav-1) * avgsecs/86400;
xmx = []; 
for i = 1:Nav
	xmxa = scrubseries( xf(ix1(i):ix2(i)));
	if length(xmxa)==0, xmx=NaN;
	else
		xmx = [xmx; max( xmxa )];
	end
end

return
