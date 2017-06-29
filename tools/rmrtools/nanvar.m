function V = nanvar(Y)
% function M = nanvar(Y)
[n,m] = size(Y);
for j = 1:m
    i = find(~isnan(Y(:,j)));
    if ~isempty(i)
        V(j) = var(Y(i,j)); 
    else
        V(j) = nan;
    end
end