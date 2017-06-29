function itjumps=tsdefine(dt),
%
% function tsdefine(dt)
%=============================
%DEFINE THE TIME BASE OF A TIME SERIES
%input
%  dt = vector datenum for the series
%output
%itjumps = array of non-monotonic jumps.

disp('TIME BASE DEFINE');
fprintf('Number points = %d\n', length(dt));
fprintf('From %s to %s\n', dtstr(dt(1)), dtstr(dt(end)));

x = 1000*median(diff(dt)*86400); % msecs
fprintf('Approx time step = %d millisecs\n', round(x));

n = round((dt(end)-dt(1))*86400*1000/x)+1;
fprintf('Full vector points = %d, No. missing = %d, (%.2f %%)\n', n, n-length(dt), 100*(n-length(dt))/n);

itjumps=find( diff(dt) <= 0 );
if length(itjumps)==0,
	fprintf('Time base is monotonic\n');
	itjumps=0;
else
	fprintf('Found %d non-monotonic time steps.\n',length(itjumps));
end
return
