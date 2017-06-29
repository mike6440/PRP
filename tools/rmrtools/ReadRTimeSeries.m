% THIS IS NOT A FUNCTION-- BUT A SCRIPT TO EXTRACT TIME SERIES
% VARIABLES AND TIME, dt, FROM RMR TIME SERIES FORMAT.
%
% BEFORE CALLING enter
%    filename = 'path/filename';
% OPTION ENTER 
%   nskip if there are more than one header lines before the variable record.
%   arrayname = the name of the output array, 
%
%	ReadRTimeSeries
%
% First line = var list of nvar variables AND includes yyyy MM dd hh mm ss
% nrec next lines are nvar columns of nrec data points.
%input
%  file name
%output
%  nvars = the number of variables in the header line
%  array.var = each variable as a n x 1 vector;
%  array.dt = dt = datenum(yyyy,MM,dd,hh,mm,ss);

%clear
%filename = 'avg_raw_2therm.txt';

if ~ exist(filename,'file'), fprintf('FILE %s DOES NOT EXIST. STOP.\n',filename); return; end

%We search for the first line that has no alphabetic characters
F=fopen(filename);

for nskip=-1:20,
	s=fgetl(F);  disp(s);
	if any( (s >= 'a' & s <= 'z') | (s >= 'A' & s <= 'Z') )	 hdr=s; else break; end 
end
fprintf('nskip = %d\n',nskip);
if nskip >= 20, disp('HEADER FAILURE, no numeric only records.'); return; end

fclose(F);

c = ReadRText(filename, nskip);


%====================================
% SEPARATE OUT EACH VARIABLE
%====================================
nvars = length(c{1});
if exist('arrayname','var'), 
	eval(sprintf('%s.vars='''';',arrayname));
else
	vars='';
end

%===========================
% CLEAN EACH FIELD, NAME VARIABLES
%===========================
		% ARRAY HAS HEADER BUT NO DATA RECORDS
if length(c{2}(1,:)) == 1 & isnan( c{2}(1) ),
	a2.nrec=0;
	 return
else
		% ARRAYNAME OUT
	a=c{2}(:,1);
	if exist('arrayname','var'), 
		% CONVERT 'MISSING' TO NAN
		cmd=sprintf('%s.%s = CleanSeries(a,[-998,inf]);',arrayname,c{1}{1});
		disp(cmd); 
		eval(cmd);
		% BEGIN VAR ARRAY
		cmd=sprintf('%s.vars=''%s'';',arrayname,c{1}{1});
		disp(cmd);
		eval(cmd);
	else 
			% NO ARRAYNAME
		cmd=sprintf('%s = CleanSeries(a,[-998,inf]);',c{1}{1});
		eval(cmd);
		vars=c{1}{1};
	end

	for i=2:nvars,
		cmd = sprintf('a = c{2}(:,%d);', i);
		eval(cmd);
		% CONVERT 'MISSING' TO NAN
		if exist('arrayname','var'), 
			cmd=sprintf('%s.%s = CleanSeries(a,[-998,inf]);',arrayname,c{1}{i});
			eval(cmd)
			cmd=sprintf('%s.vars=str2mat(%s.vars,''%s'');',arrayname,arrayname,c{1}{i});
			eval(cmd)
		else 
			cmd=sprintf('%s = CleanSeries(a,[-998,inf]);',c{1}{i});
			eval(cmd);
			vars=str2mat(vars,c{1}{i});
		end
	end
	
	if exist('arrayname','var'), 
		eval(sprintf('if %s.yyyy < 1900, %s.yyyy = %s.yyyy + 2000; end',arrayname,arrayname,arrayname));
		cmd=sprintf('%s.dt = datenum(%s.yyyy,%s.MM,%s.dd,%s.hh,%s.mm,%s.ss);',arrayname,arrayname,arrayname,arrayname,arrayname,arrayname,arrayname);
		eval(cmd);
		%fprintf('ARRAY NAME = %s\n',arrayname);
		eval(sprintf('itjumps=tsdefine(%s.dt);',arrayname));
	else
		if yyyy < 1900, yyyy = yyyy + 2000; end
		dt = datenum(yyyy,MM,dd,hh,mm,ss);
		disp('arrayname is not defined');
		itjumps=tsdefine(dt);
	end	
end
return;

