% [ustar,thetastar] = fluxprofile
% FLUX PROFILE FOR PSYCHROMETER
% NEXT TO DO:
% The coare algorithm underestimates the tstar and qstar so that the profiles do not match the 
% measurements.  I need to take a few cases and work them through by hand to see why they are 
% failing.




addpath('~/swmain/matlab/coare2');


clear
rho = 1.2;
cp = 1005;
k = 0.41;
cd = .0015;
grav=9.8;
u=7;
zu=27;

ts=24.8;

zh=27;
th=23.8;

ta=(ts+th)/2;
zt=27;

rh=70;
zq=27;

baro=1013;

a = hfbulktc(u, zu, ta, zt, rh, zq, baro, ts);
Hs= -a(:,1);
Hl = -a(:,2);
ustar=a(:,5);
tstar = -a(:,6);
qstar = -a(:,7);
L = a(:,8);
zeta = - a(:,9);
cd = a(:,10);
ct = a(:,11);
cq = a(:,12);
Rl = a(:,13);



gamma=11;
xx=1-gamma .* zh ./ L;
psi2= 2 * log( (1 + xx .* xx)./2);


z=[zeta:zeta:zt]';
zx=zeta;
psi=18;
theta = ts - tstar .* (log( (z-zx) ./ zx) + psi2);

plot(theta,z); 
set(gca,'fontname','arial','fontweight','bold','fontsize',14);
grid;
tx=title('T PROFILE');
set(tx,'fontname','arial','fontweight','bold','fontsize',16);
saveas(gcf,'/Users/rmr/aa/profile_t.png','png');
close all;



q0 = qsat(ts,baro);
q = qsat(th,baro-3.5);
rh0=100;
zx=zeta;
psi=18;
q = q0 - qstar .* (log( (z-zx) ./ zx) + psi2); rh = 100.* q ./ q0;


plot(rh,z); 
set(gca,'fontname','arial','fontweight','bold','fontsize',14);
grid;
tx=title('RH PROFILE');
set(tx,'fontname','arial','fontweight','bold','fontsize',16);
saveas(gcf,'/Users/rmr/aa/profile_rh.png','png');

return

nu = 1.33e-5 * (1 + 6.5e-3 * ta + 8.3e-6 * ta * ta -4.8e-9 * ta*ta*ta);


u10=10;
ustar = sqrt(cd) * u10;

H=10;
thetastar = H /(rho*cp)/(k * ustar);

L = -ustar^3 * rho * cp * ta /(k * grav * H);

logz0m = -1.52 + log10(ustar*ustar/grav);
z0m = 10 ^ logz0m;
Rr = z0m * ustar / nu;

x=exp(0.38 + 2.99 * log10(Rr));
z0h = z0m / x;

y=exp(2.67 + 2.61 * log10(Rr));
z0q = z0m / y;



