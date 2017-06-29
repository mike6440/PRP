function SolarDay(lat,lon,dt1,dt2)%=================================================================% function SolarDay(lat,lon,dt1,dt2)%% performs an analysis of clear sky conditions for% a period of time from dt1 to dt2.% Clear sky insolation uses SolRad and these parameters:%  watvap=3 cm, p=1013 mb,  k1 =0.1,  k2=0.1, ozone=.3% See http://aa.usno.navy.mil/data/docs/RS_OneYear.php% reynolds 121218% ====================================================================		%TEST%clear, %lat = 25.42475; lon= -144.57570;%lat = 0; lon= 0;%dt1=now()-2;%dt1=datenum(2012,3,18);%dt2=dt1+4;		% END TESTndays = fix(dt2-dt1)+1;fprintf('\nPROGRAM SolarDay() -- run time %s\n',datestr(now));fprintf('Lat/lon = %.5f / %.5f.  All times are local daylight time.\n', lat, lon);%         2012-12-18      06:18:36  064      11:35:06  000  49      16:51:59  296fprintf(' yyyy MM dd       RISE     AZ        NOON     AZ  EL        SET      AZ   SW-CLEAR\n');dtx=dt1;for idy = 1:ndays,			% TIMES AT RISE, NOON, SET	[y,M,d] = datevec(dtx); 	[tr,tn,ts,tzone] = apnoon(y,M,d,lat,lon);	% utc times of sunrise, sunset, and noon			% AZIMUTH ANGLES	ar = ephem(lat,lon,tr);  	as = ephem(lat,lon,ts);	[an,zn] = ephem(lat,lon,tn);			% EACH MINUTE OF DAYLIGHT	tx=tr;	sw=0; nsw=0;	while tx <= ts,		% SW AT THAT MINUTE		sw = sw + SolRad(lat,lon, tx, 3, 1013, .1, .1, .3);		nsw=nsw+1;		tx = tx + 1/1440;	end			% AVERAGE INSOLATION	sw = sw / nsw;	fprintf('%s      %s  %03.0f      %s  %03.0f  %2.0f      %s  %03.0f   %6.2f\n', dtstr(dtx+tzone/24,'date'), dtstr(tr+tzone/24,'time'), ar,  dtstr(tn+tzone/24,'time'), an, zn, dtstr(ts+tzone/24,'time'), as, sw);	dtx=dtx+1;endreturn