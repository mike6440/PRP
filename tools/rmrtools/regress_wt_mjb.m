function [a,b,siga,sigb] = regress_wt_mjb(x,y,err);
% regress_wt_mjb.m
% a= intercept b=slope siga= err in intercept sigb = err slope
% linear regression using the backslash operator with a weighting function
% between two variables x & y.  mdunn
% A(:,1)=intercept A(:,2)=slope
s=err;
S=sum(1./(s.^2));
Sx=sum(x./(s.^2));
Sy=sum(y./(s.^2));
Sxx=sum((x.^2)./(s.^2));
Sxy=sum((x.*y)./(s.^2));
delta=(S.*Sxx)-(Sx.^2);
a=((Sxx.*Sy)-(Sx.*Sxy))./delta;		% intercept
b=((S.*Sxy)-(Sx.*Sy))./delta;			% slope
siga=(Sxx./delta)^0.5;					% err in intercept
sigb=(S./delta)^0.5;						% err in slope