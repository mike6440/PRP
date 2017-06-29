% Compute Planck Radiation
% 140410  in development
% wallace & hobbs p287
%function B = PlanckLaw(T,lambda),
%  B = c1 lambda^{-5} exp(-c2/(lambda T))
%where
% c1=3.74186e-16;
% c2=.01439;
%Input
%  lambda = wavelength in m
%  T = absolute temp (C+273.15)
%Output
% B in W sr^-1 m^-3  Relative to 25C, 10 micron value
% B0 = 10 micron, 25C value

function [B,B0] = PlanckLaw(T,lambda),

c1=3.74186e-16;
c2=.01439;
B=exp(-c2 ./ lambda ./ T) .* c1 .* lambda .^ -5;
l0=10e-6; t0=273.15+25;
B0 = exp(-c2 ./ l0 ./ t0 ) .* c1 .* l0 .^ -5;
B=B/B0;

return

