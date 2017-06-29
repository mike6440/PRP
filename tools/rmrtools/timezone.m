function [x]=timezone(lon),
% tz = timezone(lon)
% computes the time zone. 
x= floor( (lon+7.5)/15);

return 