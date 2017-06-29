function [csp,cdir] = Ship2Current(sog,cog,spdinwater,hdg),
% [csp,cdir] = Ship2Current(sog,cog,spdinwater,hdg),
%
%Compute true current from ship information
%
%INPUT
% sog
% cog 
% spdinwater = 
% hdg


% INPUT
%clear
%cog = 118;
%sog= 5.0;
%spdinwater = 6.5;
%hdg = 118;

% MAKE INTO VECTORS
[gx,gy] = VecP2V(sog,cog);
[sx,sy] = VecP2V(spdinwater,hdg);

% TAKE THE DIFFERENCE
cx = gx - sx;  cy = gy - sy;
[csp,cdir] = VecV2P(cx,cy);

return
