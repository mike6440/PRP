function [outav] = AvgSeriesArray(ts, deltin, avgsecs,t1,t2)
%-------------------------------------------------------
%function [outav] = AvgSeriesArray(ts, deltin, avgsecs,t1,t2)
% I define a time series array as follows: Let a = arrayname.
% a.dt = the epoch (datenum) times
% a.vars = a str2mat list of the variables in the array.
% a.yyyy, a.MM, a.dd, a.hh, a.mm, a.ss is the utc time corresponding t a.dt.
% Each of the data variables is filled from dta to dtb.
%input
%   tx is the array
%   deltin = input sample spacing, secs
%   avgsecs = output sample spacing, secs
%   t1,t2 = start and end times (dt)
% output
%   outav - has averages and std's.

fprintf('AVERAGE VARIABLES FOR ARRAYS\n');

whos

outav.vars=str2mat('yyyy','MM','dd','hh','mm','ss','dt');

nvars=length(ts.vars(:,1));
fprintf('number of variables = %d\n',nvars);

for i=1:nvars,
	var=deblank(ts.vars(i,:)); 
	disp(var);
	
	if(strcmp(var,'yyyy') | strcmp(var,'MM') | strcmp(var,'dd') | strcmp(var,'hh') | strcmp(var,'mm') | strcmp(var,'ss') | strcmp(var,'nrec') | strcmp(var,'dt') | strcmp(var,'v1')),
	else
		cmd=sprintf('[outav.dt,outav.%s,outav.%sstd]=AvgSeries(ts.dt,ts.%s,deltin,avgsecs,t1,t2);',var,var,var);
		disp(cmd);
		eval(cmd);
		cmd=sprintf('outav.vars=str2mat(outav.vars,''%s'',''%sstd'');',var,var);
		disp(cmd); eval(cmd);
	end
end

[outav.yyyy,outav.MM,outav.dd,outav.hh,outav.mm,outav.ss]=datevec(outav.dt);

return;


