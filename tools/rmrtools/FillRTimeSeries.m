% THIS IS NOT A FUNCTION.
% Before running this the R array has been loaded.
%   arrayname is the name of the R array.
%
% 			global DATAPATH MODULES DELTAT DTA DTB
%where
%  DATAPATH is not used. The array is already loaded.
%  MODULES is not used.
%  DELTAT is the time step in seconds
%  DTA is the output start time
%  DTB is the final end time
%
%OUTPUT
% An array called outf. is created. 
% Note, you can call this several times with different arraynames and the variables are appended.
% But it would better to add "myarray=outf" between calls.
%rmr 120903

global DATAPATH MODULES DELTAT DTA DTB

		% OUTPUT ARRAY
outf.vars=str2mat('yyyy','MM','dd','hh','mm','ss');
cmd=sprintf('nvars=length(%s.vars);',arrayname);
eval(cmd);
%nvars
		% FILL EACH VAR
%function [dt,xout] = FillTimeSeries(t, x, delt, ta, tb)
for i=1:nvars,
	eval(sprintf('var=deblank(%s.vars(i,:));',arrayname));
	if(strcmp(var,'yyyy') | strcmp(var,'MM') | strcmp(var,'dd') | strcmp(var,'hh') | strcmp(var,'mm') | strcmp(var,'ss') | strcmp(var,'nrec')),
	else
		cmd=sprintf('[outf.dt,outf.%s]=FillTimeSeries1sec(%s.dt,%s.%s,DELTAT,DTA,DTB);',var,arrayname,arrayname,var);
		eval(cmd);
	end
end
		% ARRAY TIME BASE
[outf.yyyy,outf.MM,outf.dd,outf.hh,outf.mm,outf.ss]=datevec(outf.dt);
eval(sprintf('outf.vars=%s.vars;',arrayname))

return;


