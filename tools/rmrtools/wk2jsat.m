function j = wk2jsat(yyyy,ww)
% function j = wk2jsat(yyyy,ww)
% ===================================================
% Convert from the week of the year to the julian day of the 
% saturday in that week.
% This is useful for the Explorer of the Seas
% 
% input:
%  yyyy is the year
%  ww is the week number
% output
%  j is the Jul day (1-365) of the Saturday in that week.
% 
% reynolds 020402
% ========================================================

% 2002
j = (fix(ww)-1) * 7 + 5;

return
