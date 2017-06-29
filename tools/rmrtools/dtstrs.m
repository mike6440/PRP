function str = dtstr(t,format)%------------------------------------------------------------% function str = dtstr(t,format)% % if format is missing or = 'datetime' == give the full form.%  'time' ==> give the time only hh:mm:ss%  'date' ==> give date only yy:MM:dd%  'short' ==> yyyyMMdd,hhmmss%  'jd' ==> jjj%  'jdf' ==> jjj.jjjjjj%  'csv' ==> yyyy,MM,dd,hh,mm,ss%  'ssv' ==> yyyy MM dd hh mm ss (space separated)%  'datetime' ==> yyyy/MM/dd-hh:mm:ss   used in tsi simulator%% Makes a date time string of the form:%    yyyy-MM-dd (jjj) hh:mm:ss% % reynolds 030530  Added %04d to format specifier% v102 060628 rmr -- added more format options% v103 080703 rmr -- added 'csv' option,  Changed '-' to ',' in 'short option% v104 100612 rmr -- added 'file' option. yyMMddhhmm% --------------------------------------------------------------% TEST%clear, t = [datenum(2001,3,2,6,59,59):.1/86400:datenum(2001,3,2,7,0,1)]';onesec = 0.55 ./ 86400;[y,M,d,h,m,sf] = datevec(t + 1/864000);  % helps in the rounding process to avoid 60.s = round(sf);ix = find(s == 60);if length(ix) > 0	[y(ix),M(ix),d(ix),h(ix),m(ix),sf(ix)] = datevec(t(ix)+ onesec);	s(ix) = round(sf(ix));end[yy,jf] = dt2jdf(t);jd = fix(jf);for i = 1:length(t)	if nargin == 1		if i == 1			str = sprintf('%04d-%02d-%02d (%03d) %02d:%02d:%04.1f',...				y(i), M(i), d(i), jd(i), h(i), m(i), s(i));		else						str = str2mat(str,...				sprintf('%04d-%02d-%02d (%03d) %02d:%02d:%04.1f',...					y(i), M(i), d(i), jd(i), h(i), m(i), s(i)));		end		elseif strcmp(lower(format),'datetime'),		if i == 1			str = sprintf('%04d/%02d/%02d-%02d:%02d:%02d',y(i), M(i), d(i), h(i), m(i), s(i));		else						str = str2mat(str,...				sprintf('%04d/%02d/%02d-%02d:%02d:%02d',y(i), M(i), d(i), h(i), m(i), s(i)));		end		elseif strcmp(lower(format),'csv'),		if i == 1,			str = sprintf('%04d,%02d,%02d,%02d,%02d,%02d',y(i),M(i),d(i),h(i),m(i),s(i));		else			str = str2mat(str,...				sprintf('%04d,%02d,%02d,%02d,%02d,%02d',y(i),M(i),d(i),h(i),m(i),s(i)));		end			elseif strcmp(lower(format),'ssv'),		if i == 1,			str = sprintf('%04d %02d %02d %02d %02d %02d',y(i),M(i),d(i),h(i),m(i),s(i));		else			str = str2mat(str,...				sprintf('%04d %02d %02d %02d %02d %02d',y(i),M(i),d(i),h(i),m(i),s(i)));		end			elseif strcmp(lower(format),'date')			if i == 1			str = sprintf('%04d-%02d-%02d',y(i), M(i), d(i));		else						str = str2mat(str,...				sprintf('%04d-%02d-%02d',y(i), M(i), d(i)));		end	elseif strcmp(lower(format), 'time')		if i == 1			str = sprintf('%02d:%02d:%02d',h(i), m(i), round(s(i)));		else						str = str2mat(str,...				sprintf('%02d:%02d:%02d',h(i), m(i), round(s(i))));		end	elseif strcmp(lower(format), 'short')		if i == 1			str = sprintf('%4d%02d%02d,%02d%02d%02d',y(1),M(1),d(1),h(1), m(1), round(s(1)));		else						str = str2mat(str,...				sprintf('%4d%02d%02d,%02d%02d%02d',y(1),M(1),d(1),h(i), m(i), round(s(i))));		end	elseif strcmp(lower(format), 'file')		if i == 1			str = sprintf('%02d%02d%02d%02d%02d',rem(y(1),100),M(1),d(1),h(1), m(1));		else						str = str2mat(str,...				sprintf('%02d%02d%02d%02d%02d',rem(y(1),100),M(1),d(1),h(i), m(i)));		end	elseif strcmp(lower(format), 'jd')		if i == 1			str = sprintf('%03d',jd(1) );		else						str = str2mat(str,...				sprintf('%03d',jd(i) ));		end	elseif strcmp(lower(format), 'jdf')		j = jd(i) + rem(t(i),1);		if i == 1			str = sprintf('%010.6f', j );		else						str = str2mat(str,...				sprintf('%010.6f',j ));		end	elseif strcmp(lower(format), 'csv')		if i == 1			str = sprintf('%4d,%d,%d,%d,%d,%d',y(1),M(1),d(1),h(1), m(1), round(s(1)));		else						str = str2mat(str,...				sprintf('%4d,%d,%d,%d,%d,%d',y(1),M(1),d(1),h(i), m(i), round(s(i))));		end			endend		