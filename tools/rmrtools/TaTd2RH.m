function [RH] = TaTd2RH(Ta, Td, Pbaro),% TaTd2RH		convert temperature and dew point to RH% [RH] = TaTd2RH(Ta, Td, Pbaro),% input: Ta, Td in degC or degK,   Pbaro in mbar% Reynolds, 970205% TEST%Ta = 28.6;%Td = [24.9, 24.95, 25]';%Pbaro = 1005;Pvs = esatwat(Ta);Pva = esatwat(Td);wa = mixratio(Pva,Pbaro);ws = mixratio(Pvs,Pbaro);rh = 100 .* wa ./ ws;% fprintf('Td = %.2f, RH = %.1f\n',[Td rh]');return;