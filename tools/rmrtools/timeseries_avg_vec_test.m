display('START TEST OF PROGRAM timeseries_avg_vec.m');
clear
load ~/data/urban/mid/level1/bnlmet/bnlmet_06040_06074.mat
dtx = dt;
spdx = ws2;
dirx = wd2;
delt = 900;
dt1 = datenum(2006,2,10,12,0,0);
dt2 = datenum(2006,3,15,0,0,0);

[dt,spd,dir,stdsp,sigth] = timeseries_avg_vec(dtx,spdx,dirx,delt,dt1,dt2);

