function COR = nancorrcoef(Y)
% function M = nancorrcoef(Y)
[n,m] = size(Y);
for j = 1:m
    for k = j:m
       i = find(~isnan(Y(:,j)) & ~isnan(Y(:,k)));
       if (~isempty(i) & length(i)>2)
           %C = corrcoef(Y(i,j),Y(i,k));
           %COR(j,k) = C(1,2); 
           COR(j,k) = sum(Y(i,j).*Y(i,k))/sqrt(sum(Y(i,j).^2)*sum(Y(i,k).^2));
       else
           COR(j,k) = nan;
       end
       COR(k,j) = COR(j,k);
   end
end
