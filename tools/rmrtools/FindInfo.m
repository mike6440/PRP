function [str] = FindInfo(filename,str0, divider),
% [str] = FindInfo(filename,str0),
% Open the file named filename (use the full name with path) and search for
% a line with the string str0.  When the line is found, see if there is a
% colon (:) or an equal (=) in that order, then return all of the remainder
% of the line after the mark.  Remove leading and endng spaces.
%INPUT
% filename = full file path and name
% str0 = the search string
% divider = (optional) the line divider ':' or '=' typically.
%OUTPUT
% str = all the string after the divider with blanks removed
%       or the entire string if there is no divider or the divider cannot
%       be found.
% v01 060814 rmr -- originate
% v02 06113 rmr -- NaN if line does not exist
% v03 061117 rmr -- if missing outp = 'MISSING', key string must be at the
%	start of the line

str = 'MISSING';

if nargin == 2,
    divider=':';
end

%fprintf('Searching for ''%s''\n', str0);

%% OPEN THE DESIGNATED FILE
sx = sprintf('x=exist(''%s'',''file'');', filename);
eval(sx);
if x <= 0,
    str = fprintf('File %s does NOT exist.\n', filename);
    str = 'MISSING';
	return;
end

FIN = fopen(filename,'rt');

%% READ EACH LINE IN THE FILE UNTIL THE DESIRED STRING IS FOUND
while ~feof(FIN),
    str1 = fgetl(FIN);
    if strncmp(str1,str0,length(str0))
        %% EXTRACT THE INFO
        ix = strfind(str1,divider);
        if length(ix) > 0, 
			str = deblank(str1(ix+1:end));
			if length(str) == 0, str=''; 
			else 
				while strncmp(str(1),' ',1), str = str(2:end); end
			end
		end
        break;
    end
end

%% CLOSING
fclose(FIN);
return;
