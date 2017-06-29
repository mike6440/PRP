% heatindex.m
% Heat Index Calculation -- from NOAA URL: 
% http://www.hpc.ncep.noaa.gov/heat_index/hi_equation.html
% The computation used for the heat index is a refinement of 
% a result obtained by multiple regression analysis carried 
% out by Lans P. Rothfusz and described in a 1990 National 
% Weather Service (NWS) Technical Attachment (SR 90-23).  
% The regression equation of Rothfusz is
% 
%   
% HI = -42.379 + 2.04901523*T + 10.14333127*RH - .22475541*T*RH - .00683783*T*T 
%    - .05481717*RH*RH +  .00122874*T*T*RH +  .00085282*T*RH*RH - .00000199*T*T*RH*RH
% 
% where T is temperature in degrees F and RH is relative 
% humidity in percent.  HI is the heat index expressed as 
% an apparent temperature in degrees F.  If the RH is less 
% than 13% and the temperature is between 80 and 112 
% degrees F, then the following adjustment is subtracted from HI:
% 
% ADJUSTMENT = [(13-RH)/4]*SQRT{[17-ABS(T-95.)]/17}
% 
% where ABS and SQRT are the absolute value and square 
% root functions, respectively.  On the other hand, if 
% the RH is greater than 85% and the temperature is 
% between 80 and 87 degrees F, then the following adjustment 
% is added to HI:
% 
% 	ADJUSTMENT = [(RH-85)/10] * [(87-T)/5]
% 
% The equation for HI above with the appropriate adjustment 
% is used to compute a maximum heat index using the HPC forecast 
% maximum temperature and a derived 00 UTC dew point temperature 
% at each forecast point location for each forecast projection day.  
% Similarly, a minimum heat index is computed using the HPC forecast 
% minimum temperature along with a derived 12 UTC dew point temperature.  
% The forecast daily mean heat index for the projection day is the 
% average of these two values, the maximum heat index and the minimum 
% heat index. Dew point temperatures are derived using the method 
% described in the documentation of the HPC 5-km resolution 
% grid data products.
% ===================================================================
