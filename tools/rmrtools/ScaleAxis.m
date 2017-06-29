function [ylim,ttk,htk] = ScaleAxis(x,xlim),
% UNDER DEVELOPMENT
%  function [scle,ttk,htk] = ScaleAxis(x),
%
% Autoscale information
%
%input
% x = input variable series
%
%output
%  xlim = 1x1 {min,max] for an axes command
%  ttk = tick vaues, e.g. 
%  htk = str2mat tick labels
%

% disp('============= SCALEAXIS =================');

mn = min(ScrubSeries(x));
mx = max(ScrubSeries(x));

if nargin == 2,
	if xlim(1)> -inf, mn = xlim(1); end
	if xlim(2) < inf, mx = xlim(2); end
end

if mn >= mx, 
	ylim=[mn-1, mn+1];  
	ttk = [-1,0,1]; 
	htk = ['-1'; ' 0'; ' 1']; 
	return;
end
% fprintf('input mn-mx=[%.4e, %.4e]\n',mn,mx);

% ==== SELECT THE BEST DIV ===========
%  we want >3 and <= 5 divisions
dx = mx-mn;
% fprintf('dx=%.2f\n',dx);

Logdx = log10(dx);
iLogdx = floor(Logdx);
D = 10 .^ iLogdx;
s = dx/D;
% fprintf('Logdx=%.2f\n',Logdx);
% fprintf('iLogdx=%.2f\n', iLogdx);
% fprintf('D=%.2f\n',D);
% fprintf('s=%.2f\n',s);

if s > 1 && s < 1.1, s=1; ttk = [0 .5    1];
elseif s>  1 && s <= 1.2, s=1.2; ttk = [0 .4  .8  1.2];
elseif s>1.2 && s <=1.5, s=1.5; ttk = [0 .5 1 1.5];
elseif s>1.5 && s <= 1.6, s=1.6; ttk=[0 .4 .8 1.2 1.6];
else
	s = ceil(s);
	divarray = [...
	0	.5	1	nan		nan
	0	1	2	nan		nan	
	0	1	2	3		nan
	0	1	2	3		4
	0	2.5 5	nan     nan
	0	2	4	6		nan
	0	3.5 7	nan		nan
	0	2	4	6		8
	0   3   6	9		nan
	0   2.5	5	7.5		10];
	ttk = ScrubSeries(divarray(s,:));
end
% fprintf('s=%.2f\n',s);
% AESTHETIC SCALING
div = D*s/(length(ttk)-1);
xmn = floor(mn/div)*div;
ttk = xmn + D*ttk;
xmx = ttk(end);

%% IF WE OVER JUMP THE MAX, RE-SCALE

% fprintf('div=%.1f\n',div);
% fprintf('plot lims mn-mx=[%.1f, %.1f]\n',xmn,xmx);


fmt = '%.0f';
if D == 1, fmt = '%.1f';
elseif D < 1, fmt = sprintf('%%.%df', 1-log10(D))
end

htk = sprintf(fmt,xmn);
% fprintf('%.1f   %s\n',ttk(1), deblank(htk(1,:)));
for i = 2:length(ttk)
	htk = str2mat(htk,sprintf(fmt,ttk(i)));
% 	fprintf('%.1f   %s\n',ttk(i), deblank(htk(i,:)));
end

ylim = [xmn,xmx];
if xmx < mx, ylim = [xmn, mx+0.02*(mx-xmn)];  end
% fprintf('ylim = [%.1f, %.1f]\n',ylim);

% % TEST PLOT
% plot(x);
% set(gca,'ylim',ylim,'ytick',ttk,'yticklabel',htk);
% grid

return

