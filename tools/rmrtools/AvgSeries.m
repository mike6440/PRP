function [dtav, xav,xavstd] = AvgSeries(dt,x,deltin,avgsecs,dt1,dt2);
% function [dtav, xav,xavstd] = AvgSeries(dt,x,deltin,avgsecs,dt1,dt2);
% AVERAGE A TIME SERIES USING TIME CENTERED TIME BLOCKS
%
%input
%  dt = datenum in
%  x = input series
%  deltin = input sample spacing, secs
%  avgsecs = output sample spacing, secs
% dt1=first sample time. (Center of the sample block)
% dt2=sample time AFTER the last sample.
%  example avgsecs=1 sec, dt1=datenum(2012,2,18,0,0,0)   dt2=dt1+1; yields 86400 points
%   from 2012-2-18-0-0-0 to 2012-2-18-23-59-59 
%output
%  (dtav,xav) = averaged series
%  xavstd = sample standard deviation
%
%The output time is selected to be even time blocks over a day. 
% e.g. for avgsecs=600 secs, times are at 0, 10, 20, ... minutes
% and the sample periods are centered over the time marks.

% Find the nearest start time centered on an averaging period
% === STARTT TIME
dta=(round(rem(dt1,1)*86400/avgsecs)*avgsecs)/86400 + fix(dt1);
dtb=(round(rem(dt2,1)*86400/avgsecs)*avgsecs)/86400 + fix(dt2);

%fprintf('Start at %s,   End at %s\n', dtstr(dta), dtstr(dtb));

dtaa=dta-avgsecs/2/86400;  dtbb=dtb+(avgsecs+.5)/2/86400;


% make a full time series between dta and dtb
[dtf, xf] = FillTimeSeries1sec(dt, x, deltin, dtaa,dtbb);
Nx = length(xf); % the full length of all points.

% NUMBER OF AVERAGES TO EMERGE
Nav = round((dtb - dta)*86400/avgsecs);


% INDEXES OF THE DIFFERENT AVERAGING BLOCKS
iav = [1:Nav]';
ix1 = fix((iav - 1) * Nx / Nav)+1;
ix2 = fix(iav * Nx / Nav);

dtav = dta + (iav-1) * avgsecs/86400;
xav = []; xavstd = [];

for i = 1:Nav
    xav = [xav; meanseries(xf(ix1(i):ix2(i)))];
    xavstd = [xavstd; Stdev(xf(ix1(i):ix2(i)))];
end

return

