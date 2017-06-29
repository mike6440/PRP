%THIS IS NOT A FUNCTION
% Before calling: 
% 1. define the R data array. As produced by the ReadRTimeSeries script.
%    use 'arrayname=...' to put the R array into a structure array.
% 2. Are there non-monotonic time poiints? Use tsdefine(arrayname.dt)
% 3. If so then call: [tg,ib]=TimeBaseJump(arrayname.dt);
% 		where
% 		arrayname = the name of the array currently in memory.
%		tg = datenum array that is now monotonic.
%		ibad = the array of points to remove.
% 4. Then call this routine:
%	MakeRMonotonic
%Make the structure array 'arrayname' time monotonic. Return a new array
%named 'aname'.
%INPUT
%  arrayname
%OUTPUT
%  same array with jumps removed.

%==========
% FIRST TWO TIMES ARE MONOTONIC
%==========
cmd=sprintf('if %s.dt(1)==%s.dt(2), disp(''Scrub first point.''); %s=ScrubRTimeSeries(%s,1); end',...
	arrayname,arrayname,arrayname,arrayname);
disp(cmd); eval(cmd);

cmd=sprintf('[ibad] = TimeBaseJump(%s.dt);',arrayname);
disp(cmd); eval(cmd);
fprintf('MakeRMonotonic: remove %d points\n', length(ibad));

if length(ibad) > 0,	
	eval(['vars=',arrayname,'.vars;']);
	nv=length(vars);
	for i=1:nv,
		v=deblank(vars(i,:));
		cmd=sprintf('%s.%s(ibad)=[];',arrayname,v);
		%disp(cmd);
		eval(cmd);
	end
	cmd=sprintf('%s.dt(ibad)=[];',arrayname);
	%disp(cmd);
	eval(cmd);
end

return
