function Map_Arctic(lons,lats,resolution),
%------------------
% FUNCTION Map_Arctic(lats,lons,resolution),
%
% crusty Lambert Conformal map in the Arctic
%
%INPUT
% lats, lons = [min,max]
% resolution = 'L','M','H' for low, medium, high
%
%--------------------

%m_proj('lambert','long',[-160 -40],'lat',[30 80]);
%%m_coast('patch',[1 .85 .7]);
%m_elev('contourf',[500:500:6000]);
%m_grid('box','fancy','tickdir','in');
%colormap(flipud(copper));

addpath('/Users/rmr/swmain/matlab/crusty/m_map');
% DRAW A WORLD MAP

coastline = 'm_gshhs_h';

if nargin==3
	if strncmpi(resolution,'l',1), coastline =  'm_gshhs_l';
	elseif strncmpi(resolution,'m',1), coastline = ' m_gshhs_i';
	elseif strncmpi(resolution,'h',1), coastline = ' m_gshhs_h';
	elseif strncmpi(resolution,'c',1), coastline = ' m_coast';
	else error('ERROR in resolution input');
	end
end
	
% projection
m_proj('lambert','longitudes',lons,'latitudes',lats);

% draw the coast line
eval([coastline,'(''patch'',[.8 .8 .8]);']);

% grid
%m_grid('fontname','helvetica','fontsize',12,'box','fancy',...
%	'linewidth',.5, 'linespec','-');
m_grid('box','fancy','tickdir','in');

set(gcf,'color','w');

figure(gcf);


