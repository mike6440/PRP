function rx = CatRTimeSeries(r1,r2),
% function rx = CatRTimeSeries(r1,r2),
%
% 140429 first code
%
%input
%  r1 = name of the primary time series
%  r2 = name of the time series to add onto r1.
%output
%  rx is a cat structure [r1; r2]
%

iv=length(r1.vars(:,1));
rx=r1;

for i=1:iv,
	v = deblank(rx.vars(i,:));
	
	cmd=sprintf('rx.%s = [r1.%s; r2.%s];',v,v,v);
	%disp(cmd);
	eval(cmd);
end

rx.dt=datenum(rx.yyyy,rx.MM,rx.dd,rx.hh,rx.mm,rx.ss);
return


