function [x,ix] = meanseries(y,xlimin),
% function [x,ix] = MeanTS(y,ylim),
% Scrubs bad and NaN data then takes an average.
%
%input
%  y = scalar vector
%  ylim (optional) [min,max], accept if min >= y <= max
%output
% x = scrubbed series.
% ix = index in y of all good values.
%
%
if nargin == 1,
    xlim = [-inf,inf];
else
    xlim = xlimin;
end

[x1,ix] = ScrubSeries(y,xlim);
x = mean(x1);
return

