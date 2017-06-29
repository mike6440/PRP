function Map_Globe(lat,lon),
%------------------
% FUNCTION Map_Pacific(lats,lons,resolution),
%
% world globe centered on lat,lon
%
%INPUT
% lat, lon = f.p. degrees
%
%--------------------
addpath('Users/rmr/swmain/TOOLBOX/matlab/crusty/m_map');

m_proj('ortho','lat',lat','long',lon');
m_coast('patch','r');
m_grid('linest','-','xticklabels',[],'yticklabels',[]);
%patch(.55*[-1 1 1 -1],.25*[-1 -1 1 1]-.55,'w');
%text(0,-.55,'M\_Map','fontsize',25,'color','b',...
%   'vertical','middle','horizontal','center');
set(gcf,'units','pixels','position',[10,10,600,600]);
%set(gcf,'paperposition',[3 3 3 3]);

figure(gcf);

return

