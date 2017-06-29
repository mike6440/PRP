function Map_Pacific(lons,lats,resolution),
%-----------------
% FUNCTION Map_Pacific(lats,lons,'resolution'),
%
% crusty mercator map in the Pacific
%
%input
% lats, lons = [min,max]
% resolution = 'L','M','H','c' for low, medium, high, coastline
%
%-----------------

addpath('/Users/rmr/swmain/matlab/crusty/m_map');
% DRAW A WORLD MAP

if nargin==3
	if strncmpi(resolution,'l',1), coastline =  'm_gshhs_l';
	elseif strncmpi(resolution,'m',1), coastline = ' m_gshhs_i';
	elseif strncmpi(resolution,'h',1), coastline = ' m_gshhs_h';
	elseif strncmpi(resolution,'c',1), coastline = ' m_coast';
	else error('ERROR in resolution input');
	end
end


% projection
m_proj('mercator','longitudes',lons,'latitudes',lats);
%m_proj('ortho','lat',mean(lats),'long',mean(lons));

% draw the coast line
eval([coastline,'(''patch'',[.8 .8 .8]);']);

% grid
m_grid('fontname','helvetica','fontsize',12,'box','fancy',...
	'linewidth',.5, 'linespec','-');

set(gcf,'color','w');

figure(gcf);


