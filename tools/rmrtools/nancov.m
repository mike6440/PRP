function COV = nancov(Y)
% function M = nanvar(Y)
[n,m] = size(Y);
for j = 1:m
    for k = j:m
       i = find(~isnan(Y(:,j)) & ~isnan(Y(:,k)));
       if (~isempty(i) & length(i)>2)
           %C = cov(Y(i,j),Y(i,k));
           %COV(j,k) = C(1,2); 
           COV(j,k) = sum((Y(i,j)-mean(Y(i,j))).*(Y(i,k)-mean(Y(i,k))))/length(i);
       else
           COV(j,k) = nan;
       end
       COV(k,j) = COV(j,k);
   end
end
