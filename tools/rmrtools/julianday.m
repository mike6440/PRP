function jul = julian(yyyy,MM,dd)
%julian			compute julian day from yyyy,MM,dd
%			jul = julian(yyyy,MM,dd)
%Input:
%	yyyy = year in 4-digit form
%	MM = month number, 1--12
% 	dd = day of the month
%
%  see Recepies in C page 10.
%  number of days since 1 AD.
% to get the day of the year subtract 
%        julian(yyyy,MM,dd)-julian(yyyy,1,1) + 1
% 
% Astronomical JD.
%  Reynolds, 970204

igreg = (15 + 31 .* (10 + 12 .* 1582));

if yyyy < 0
  yyyy = yyyy + 1;
end

if MM > 2 
  jy = yyyy;
  jm = MM +1;
else
  jy = yyyy -1;
  jm = MM + 13;
end;

jul = (floor(365.25 .* jy) + floor(30.6001 .* jm)...
    + dd + 1720995);
if(dd + 31 .* (MM + 12 .* yyyy)) >= igreg
  ja = fix(0.01 .* jy);
  jul = jul + 2 - ja + fix(0.25 .* ja);
end
