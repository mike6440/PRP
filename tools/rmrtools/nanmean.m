function M = nanmean(Y)
% function M = nanmean(Y)
[n,m] = size(Y);
for j = 1:m
    i = find(~isnan(Y(:,j)));
    if ~isempty(i)
        M(j) = mean(Y(i,j)); 
    else
        M(j) = nan;
    end
end