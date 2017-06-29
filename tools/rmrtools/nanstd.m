function S = nanstd(Y)
% function M = nanstd(Y)
[n,m] = size(Y);
for j = 1:m
    i = find(~isnan(Y(:,j)));
    if ~isempty(i)
        S(j) = std(Y(i,j)); 
    else
        S(j) = nan;
    end
end