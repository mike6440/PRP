% Compute the Output from a radiometer with filtering window
% 140410  in development
% see wallace & hobbs p287
% see PlanckLaw.m
%function Bf = PlanckLaw(T,lambda,wlambda),
%Input
%	T = target abs temperature
%  lambda(i), i=1,2,...N = wavelength array in m
%  w(i) = the window response for lambda(i).
%Output
% B in W sr^-1 m^-2  integrated over the optical band

%function [B] = PlanckFiltered(T,lambda,w),
%if nargin ~= 3, disp('Input argument error'); return; end
B=[];
T=[10:40]'+273.15;
c1=3.74186e-16;
c2=.01439;

%Tue, 06 May 2003 : ISAR sn01 Filter function
%23.1.2002
%    KT15.85   S/N 4832
%      12.SPK        Pyroelektrischer Detektor (LiTaO3)
%     160.SPK        9.6 - 11.5
%    microns           relative response    steps in microns        #steps
%  ## error 9.400000           11.500000 
f = [  9.430000            2.546310
  9.490000            5.793331
  9.550000            9.668717
  9.610000           14.968266
  9.670000           24.493301
  9.730000           34.960308
  9.790000           45.626378
  9.850000           50.791858
  9.910000           54.246059
  9.970000           57.813660
 10.030000           59.618147
 10.090000           59.564821
 10.150000           59.498671
 10.210000           59.664674
 10.270000           60.626505
 10.330000           61.658131
 10.390000           66.522749
 10.450000           67.121249
 10.510000           67.451023
 10.570000           66.894956
 10.630000           66.250330
 10.690000           65.625707
 10.750000           65.522968
 10.810000           65.577193
 10.870000           65.622867
 10.930000           66.302045
 10.990000           67.630746
 11.050000           68.972272
 11.110000           66.407322
 11.170000           50.950737
 11.230000           34.240797
 11.290000           17.971729
 11.350000           10.918391
 11.410000            6.826609
 11.470000            2.828826];
lambda=f(:,1)*1e-6;
w=f(:,2);

for i=1:length(T),
	[b]=PlanckLaw(T(i),lambda);
	bw = b .* w;
	B = [B; sum(bw) ./ sum(w)];
end

return;


