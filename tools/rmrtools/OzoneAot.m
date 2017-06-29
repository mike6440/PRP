function [tau, dob]=OzoneAot(dt, lat, det)
%==========================================================================
%function [tau, dob]=OzoneAot(dt, lat, det)
%This function computes the climatological ozone concentration in dobson 
%units for a specified latitude on a specified julian day.  
%The climatological ozone concentrations is included in this function.
%
%input
% dt = datenum nx1 vector
% lat = latitude nx1 vector
% det = [1,...,7] is the channel number for the frsr
% 
%output
% tau = optical thickness for ozone
% dob = dobson units for this time and latitude
%=========================================================================

% test clear, lat = 0;   dt = datenum(2001,1,1); det = 1;
tau = nan * ones(length(dt),1);  dob = tau;

%=======================
% CLIMATOLOGICAL OZONE
% organized by 10 deg latitude bands and month
%=======================
oz = [...
315,330,338,330,315,290,264,245,240,240,249,265,284,305,325,346,352,348,340
360,376,380,372,350,316,278,252,240,240,242,257,276,291,307,316,318,315,307
420,428,422,405,380,340,295,260,242,240,240,252,268,285,296,302,300,300,300
440,440,440,423,394,347,304,272,253,240,242,252,262,280,290,293,300,300,300
430,430,428,415,380,342,305,275,255,240,244,252,260,279,288,292,300,300,300
400,395,390,377,353,330,295,272,255,240,246,254,265,286,296,295,300,300,300
350,350,350,340,330,310,281,265,252,240,248,258,273,295,307,305,300,300,300
315,315,317,314,310,290,273,258,244,240,250,262,280,307,316,314,304,300,300
287,292,294,297,293,278,263,250,240,240,252,268,291,318,327,324,313,300,300
280,280,288,291,284,270,257,244,240,240,256,276,300,327,335,335,322,308,300
285,290,294,293,284,268,255,240,240,240,259,278,300,331,344,352,338,323,312
295,300,310,308,295,275,256,240,240,240,256,272,292,320,340,360,360,360,355
315,330,338,330,315,290,264,245,240,240,249,265,284,305,325,346,352,348,340
360,376,380,372,350,316,278,252,240,240,242,257,276,291,307,316,318,315,307];

% coefficients to convert dobson units to optical depth
% for different bands.
% Note broadband channel is set to zero for now
ozcoef=[0,0,0,0.0328,0.1221,0.04976,0.0036]';

ii = find(~isnan(lat));
if length(ii) > 0
	%  THE MONTH DETERMINES THE ROW
	[y,m,d] = datevec(dt(ii));
	
	% THE LATITUDE BAND DETERMINES THE COLUMN
	ix = fix(( lat(ii) + 90 ) / 10) + 1;

	% READ DOBSON FROM THE ARRAY
	for i = 1:length(m)
        dob(ii) = oz(m(i),ix(i));
	end
	
	% COMPUTE THE OPTICAL DEPTH USING COEFFICIENTS
	tau(ii) = dob(ii) .* ozcoef(det) ./ 1000;
end
return