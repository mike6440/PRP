function [x,ix] = Stdev(y,xlimin),
% function [x,ix] = Stdev(y,ylim),
% Scrubs bad and NaN data then computes the standard deviation.
%
%input
%  y = scalar vector
%  ylim (optional) [min,max], accept if min >= y <= max
%
% 061027 rmr
%
if nargin == 1,
    xlim = [-inf,inf];
else
    xlim = xlimin;
end

[x1,ix] = ScrubSeries(y,xlim);
x = std(x1);
return

