% TEST VEC STICK PLOT
clear;

t1=datenum(2009,1,1,0,0,0);
t2=datenum(2009,1,2,0,0,0);

fg=figure;
ax = axes;
set(gca,'units','normalized','position',[.1, .1, .8, .4]);

dt=[t1:1/36:t2]';
vscale=10;
ws = vscale/2*ones(size(dt));
ix = [0:length(dt)-1]';

wd = 360 .* ix ./ ix(end);

set(gca,'xlim',[t1,t2],'ylim',[-vscale,vscale]);
str='test plot';
[ttk, htk] = MakeHourTicks(t1, t2);
VecStickPlot(dt,ws,wd,str,0.3,vscale,'r',gca);
hold on
VecStickPlot(dt,ws,wd,str,0.5,vscale,'b',gca);

set(gca,'xtick',ttk,'xticklabel',htk);

