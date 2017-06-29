function [dtav, sav, vsav, vdav, sstd, dstd] = AvgVecSeries(dt,s,d,deltin,avgsecs,dt1,dt2);
% function [dtav, sav, vsav, vdav, sstd, dstd] = AvgSeries(dt,s,d,deltin,avgsecs,dt1,dt2);
% AVERAGE A TIME SERIES USING TIME CENTERED TIME BLOCKS
%
%input
%  dt = datenum in
%  s = input speed series
%  d = input direction series
%  deltin = input sample spacing, secs
%  avgsecs = output sample spacing, secs
% dt1=first sample time. (Center of the sample block)
% dt2=sample time AFTER the last sample.
%output
%  (dtav,sav, dav) = averaged series
%  sstd = speed standard deviation
%  dstd = direction stdev (Yamartino)
%
%The output time is selected to be even time blocks over a day. 
% e.g. for avgsecs=600 secs, times are at 0, 10, 20, ... minutes
% and the sample periods are centered over the time marks.

		% === START END TIME
dta=(round(rem(dt1,1)*86400/avgsecs)*avgsecs)/86400 + fix(dt1);
dtb=(round(rem(dt2,1)*86400/avgsecs)*avgsecs)/86400 + fix(dt2);
dtaa=dta-avgsecs/2/86400;  dtbb=dtb+(avgsecs+.5)/2/86400;
		% VECTOR COMPONENTS
[x,y] = VecP2V(s,d);
		% FILL SERIES		
[dtf, sf] = FillTimeSeries1sec(dt, s, deltin, dtaa,dtbb);
[dtf, df] = FillTimeSeries1sec_interp(dt, d, deltin, dtaa,dtbb);  %[dt,xout] = FillTimeSeries1sec_interp(t, x_in, delt, ta, tb)
[dtf, xf] = FillTimeSeries1sec(dt, x, deltin, dtaa,dtbb);
[dtf, yf] = FillTimeSeries1sec(dt, y, deltin, dtaa,dtbb);
Nx = length(xf); % the full length of all points.
		% FINAL SIZE
Nav = round((dtb - dta)*86400/avgsecs)+1;
		% INDEXES OF THE DIFFERENT AVERAGING BLOCKS
iav = [1:Nav]';
ix1 = fix((iav - 1) * Nx / Nav)+1;
ix2 = fix(iav * Nx / Nav);
		% FINAL TIME BASE
dtav = dta + (iav-1) * avgsecs/86400;
xav = []; yav=[]; dstd = []; sstd = [];  
sav=[];

for i = 1:Nav
	sav = [sav; meanseries(sf(ix1(i):ix2(i)))];
	dstd = [dstd; Yamartino(df(ix1(i):ix2(i)))];
    xav = [xav; meanseries(xf(ix1(i):ix2(i)))];
    yav = [yav; meanseries(yf(ix1(i):ix2(i)))];
    sstd = [sstd; Stdev(sf(ix1(i):ix2(i)))];
end

[vsav,vdav] = VecV2P(xav,yav);

return

