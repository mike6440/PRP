function 	EditSer(dt, y1, y2),
%-----------------------------------------------------------------------------
%EDITSER -- manual edit one or two series 
%       y3 = EditSer(dt, y1, y2, type);
%
%Narguents = 2/3
%Time series compare and edit.  
% dt = time base for both series.  
%  
%If y2 missing, then single series edit.
%If y2 present, then allows substitution of y2 into y1.
%
% Required globals:
% YYYY, JD = year and jd at start of the series
% MISSING = missing values in the ascii files, typ -999
% EDFILE = string path and name for metadata, e.g. "hd:ftpio:Tedits.txt"
% SAVESTRING = eval string to save data, e.g. 
%  "tair = Y3; save hd:ftpio:test.mat dt tair;"
%
%---------------------------------------------------------------------------
%reynolds 031121
%version changes after 031121:
% v201: Improve graph presentation.
% v202 20061206 rmr -- comment out EDFILE write

% GLOBAL VARIABLES -- input globals
global MISSING EDFILE SAVESTRING TITLE
% output globals
global DT Y3
% Globals used by this function
global	T1  T2  T1old  T2old  NPTS	YYYY JD % first and last points
global	YLIM  TLIM    NSER
global   FG_MAIN  AX_MAIN PL1 PL2 PL3  	% handles to main plot
global	SECONDARY_FLAG  GRID_FLAG
global	FG_LIMITS  HC11 HC12  HC13  HC14 		% relates to start/stop set limits
global	FG_FILTER	FIGCOLOR
global	FG2 HC22  TXHAND	PP_EDIT		% relates to the offset window
global  Y1 Y2 Y3_OLD 		% the time series
global	HC31  HC32  HC33 				% for quadratic entry
global	Q								% (3 x 1) coefs for quadratic eqn
global	HC41 HC42 HC43 HC44 HC45 HC46 HC47 PP11 
global	LAG	CLIP						% clip and filter coefs
global	ZOOMPOS	ZT1  ZT2	ZY1 ZY2	ZOOM_BOX % the position of the zoom rectangle
global	I_ZOOMSELECT  I_ZOOMMISSING I_SELECT ZOOMFLAG DOTFLAG
global XOUT  YOUT 	 VARNAME2 	% used by function EditDay()
global STR   % string to write out to the edit file
global MENU_DATATYPE  DATATYPEFLAG PPHOURSUM

y3 = nan; % the output time series, this is filled with the corrected series
          % 

%-------------------------------------------------------
% INITIALIZE TEST MODE
% test mode, no arguments
%-------------------------------------------------------
if nargin == 0,
	EditSer('test');
	
%-------------------------------------------------------
% NORMAL OPERATION
% normal "calling operation" nargin =2/3
%-------------------------------------------------------

elseif  nargin == 2 | nargin == 3,
	fprintf('EditSer called:\n');
	
	%=======================
	% initialize certain constants, create Y3 series
	%=======================
	%fprintf('\nEDITSER: initialize...\n');
	Q = [0; 1; 0;];	% quadratic equation for Y3
	
	% Plot limits based on input time base
	NPTS = length(dt);
	T1 = dt(1);   T1old = T1; 
	T2 = dt(NPTS);  T2old = T2;
	YLIM = [-inf, inf];				% start with free scaling
	TLIM = [T1, T2];				% start with the full plot
	[YYYY,JD] = dt2jdf(dt(1));
	
    % TITLE INITIALIZE
    if isempty(TITLE)
        TITLE = '';
    end
    
    
	% ZOOM INITIALIZE
	ZT1 = T1;  ZT2 = T2;
	ZY1 = NaN;	ZY2 = NaN;
	
	% for clip edit window
	CLIP = [-1e10; 1e10];
		
	% check the number of input series
	NSER = nargin - 1;
	%fprintf('EditSeries: edit %d series...\n',NSER);
	
	% create the Y3 output series from Y1, DT
	Y1 = y1;  DT = dt;
	if NSER == 2,	Y2 = y2;  end
	EditSer('y3 create'); % ==>> (DT,Y3)=PRIMARY    (DT,Y1) = secondary
	
	% PLOT THE TWO SERIES AGAINST HOUR/MIN OF THE DAY
	%T1 = 0; T2 = 1439;  % initialize the plot time base
	FG_MAIN = figure('position',[50,50,1200,1000]);
	set(gcf,'papersize',[9.5 7], 'paperposition',[.25 .25 9 6.5])
	AX_MAIN = axes;
	DOTFLAG = 1;  % v2c
	I_SELECT = [1:NPTS]';  % we startr with a full series selected
	FIGCOLOR = [.95 1 1];
	
	% SET DATA TYPE TO PRECIP IF NAME BEGINS WITH 'pp'
	DATATYPEFLAG = 0;  % 0=scalar,  1 = direction,  2 = precip
	
	PPHOURSUM = [];	% clear hourly sum array

   %------------------
   % PLOT PRIMARY PLOT - default lines, primary only
   %------------------
	% plot primary -- big dots
   PL3 = plot(DT,Y3,'-b');
   if NSER == 2
	   hold on  
	   PL1 = plot(DT,Y1,'-r');
	   hold off
		%set(PL1,'visible','off');
	end
	grid;  datetick;  GRID_FLAG = 1;
	
	% MAKE AXIS FOR PLOT
% 	str = sprintf('DAY %d/%d: PRIMARY (BLUE),  SECONDARY (RED)',...
% 		JD, YYYY);
	%fprintf('%s\n',str);
	set(AX_MAIN,'xlim',[T1, T2], 'ylim',[-inf,inf]);
	set(AX_MAIN, 'fontweight','bold','fontsize',14);  %v201
	
	% misc initializations
	SECONDARY_FLAG = 1;  % start showing both time series
	if nargin == 2, SECONDARY_FLAG = 0; end
	ZOOMFLAG = 0;
	str=sprintf('From %s to %s',datestr(T1),datestr(T2));
	TXHAND = text(T1,0,str);
	set(TXHAND,'units','normalized',...
		'position',[.05,.95],'fontweight','bold',...
		'fontsize',18);

    %=====================
    % TITLE
    %=====================
	txh = title(TITLE);
    set(txh,'fontweight','bold', 'fontsize',14);
    
	STR = sprintf('EDIT DATE: %s',date);  % series under edit
%	tx=text(T1,0,str); 
	EditSer('write edit string');
	
	
%-------------------------------------------------------
%	GUI MENU 
%-------------------------------------------------------
	% setup first top level menu
	menu1 = uimenu(gcf,'label','EdOptions');
	
	% undo
	menu_grid = uimenu(menu1,'label','Undo',...
		'callback','EditSer(''restore'');');
		
	uimenu(menu1,'label','Redraw',...
		'callback','EditSer(''replot'');');
	
	%----------- Set Data Type -----------------------------------
	MENU_DATATYPE = uimenu(menu1,'label','Data Type (Scalar)');
	
	uimenu(MENU_DATATYPE,'label','Scalar',...
		'callback','EditSer(''scalar data'');');
	
	uimenu(MENU_DATATYPE,'label','Direction',...
		'callback','EditSer(''direction data'');');
		
	uimenu(MENU_DATATYPE,'label','Precip',...
		'callback','EditSer(''precip data'');');
	%----------------------------------------------------------------
	uimenu(menu1,'label','Full Series',...
		'callback','EditSer(''full series'');');
	
	% y3 only
	menu_y3only = uimenu(menu1,'label','Primary Only/Both',...
		'callback','EditSer(''y3 only'');');
	
	menu_y3only = uimenu(menu1,'label','Lines/Dots',...
		'callback','EditSer(''lines/dots'');');
	
	% grid option
	menu_grid = uimenu(menu1,'label','grid toggle',...
		'callback','grid; GRID_FLAG = rem(GRID_FLAG+1,2);');
	
	% filter the series
	menu_y3quad = uimenu(menu1, 'label','Clip, Spike, Smooth',...
		'callback','EditSer(''filter'');');
	%-----------------set start/stop times-------------------------------
	menu_times = uimenu(menu1,'label','Set Axis Scale',...
		'callback','EditSer(''set limits'');');
	%------ ZOOM -------------------------------
	% zoom action menu and sub-menus
	menu_zoom = uimenu(menu1,'label','ZOOM',...
		'callback', 'EditSer(''zoom'');' );	% ==>> 
			
	uimenu(menu1,'label','   blowup rectangle',...
		'callback','EditSer(''zoom expand'');');
	uimenu(menu1, 'label', '   make missing',...
		'callback','EditSer(''zoom delete'');');
	uimenu(menu1, 'label', '   substitute secondary',...
		'callback','EditSer(''zoom substitute secondary'');');
	uimenu(menu1, 'label', '   set to value',...
		'callback','EditSer(''zoom set value'');');
	uimenu(menu1, 'label', '   offset',...
		'callback','EditSer(''zoom offset'');');
	uimenu(menu1, 'label', '    STATS',...
		'callback','EditSer(''zoom stats'');');
		
	%----------------------------------------------
	
	% ----------- MODIFY PLOTTED POINTS ------------------------
	% create a new series called y3 that is 1440 min long
	menu_y3 = uimenu(menu1, 'label','Modify Plotted Points');
	
	uimenu(menu1, 'label', 'Interpolate Fill',...
		'callback','EditSer(''interpolate fill'');');
		
	% offset the series
	menu_y3offset = uimenu(menu_y3, 'label','Offset',...
		'callback','EditSer(''y3 offset'');');
	
	% quadratic equation
	menu_y3quad = uimenu(menu_y3, 'label','Quadraatic',...
		'callback','EditSer(''y3 quad'');');
	
	% substitute
	uimenu(menu_y3, 'label','Replace y3 with y1',...
		'callback','EditSer(''y1-y3 substitute'');');
	% --------------------------------------------------------
	
	
	uimenu(menu1, 'label','Edit PPT hourly sums',...
		'callback','Editser(''ppt hr edit'');');
	
	% -------------- EXIT WITH CURRENT EDITED SERIES ---------------------------
	uimenu(menu1,'label','EXIT SERIES',...
		'callback','EditSer(''exit edit'');');
		
		
	% clean up the window
	menu1_clean = uimenu(menu1,'label','clean',...
		'callback','EditSer(''clean'');');

	
	EditSer('replot');
	
%-------------------------------------------------------
%	BEGIN SWITCH LIST
%-------------------------------------------------------
elseif nargin == 1,
	kmode = dt;
	%fprintf('kmode = %s\n',kmode);
%-------------------------------------------------------
%  'EXIT SERIES'  -- 
%-------------------------------------------------------
	if strcmp(kmode,'exit edit'),
		
		fprintf('EXIT EDITSER -- SAVE DATA\n');
		if length(SAVESTRING) > 0
			disp('SAVESTRING');
			disp(SAVESTRING);
			eval(SAVESTRING);
		end
		y3 = Y3;
		
		return;		
%-------------------------------------------------------
% 'write edit string'
%-------------------------------------------------------
	elseif strcmp( kmode, 'write edit string')
	
		% OPEN THE EDIT FILE AND APPEND START NOTES:
		%cmd = sprintf('fid = fopen(''%s'',''at'');',EDFILE);
		%fprintf('%s\n',cmd);
		%eval(cmd);
		
		% WRITE THE TEXT STRING
		%if fid <= 0, error('EDFILE fails to open'); end
		%fprintf(fid,'%s\n',STR);
		%fprintf('EDIT string: %s\n',STR);
		
		%fclose(fid);
	
%-------------------------------------------------------
% Full series plot -- default 
%-------------------------------------------------------
	elseif strcmp( kmode, 'full series'),

		T1 = DT(1);  T2 = DT(NPTS);
		TLIM = [T1; T2];
		YLIM = [-inf; inf];
		EditSer('replot');
		
%-------------------------------------------------------
% Edit ppt hourly averages
%-------------------------------------------------------
	elseif strcmp( kmode, 'ppt hr edit'),
		%fprintf('ppt hr edit test line\n');
		
		if length(PPHOURSUM ~= 24)
			EditSer('precip data');
		end
		
		step = 25;
		
		% MAKE THE EDIT WINDOW
		PP_EDIT = figure('position',[900,100,100,600],...
			'color',FIGCOLOR,...
			'name','EDIT PPT');
		uicontrol(gcf,'style','text',...
			'position',[2,570,95,20],...
			'string','HRLY PPT',...
			'backgroundcolor',FIGCOLOR);
		
		PP11 = [];
		
		y1 = 550;  xhr = 2;  hrwd = 20;  hrht = 20;
		xppt = 40;
		step = 20;
		for ihr = 0:23,
			uicontrol(gcf,'style','text',...
				'position',[xhr,y1,hrwd,hrht],...
				'string',sprintf('%02d',ihr),...
				'backgroundcolor',FIGCOLOR);
			
			PP11 = [PP11; uicontrol(gcf,'style','edit',...
				'position',[xppt,y1,40,20],...
				'string',sprintf('%04.2f',PPHOURSUM(ihr+1)),...
				'min',0,'max',0,...
				'backgroundcolor',FIGCOLOR)];
				
			y1 = y1 - step;
		end	
		
		% GO BUTTON		
		uicontrol(gcf,'style','pushbutton',...
			'position',[50,5,40,20],...
			'string','GO',...
			'callback','EditSer(''proc precip edit'');');
%-------------------------------------------------------
%	process precip edit
%-------------------------------------------------------
	elseif strcmp(kmode,'proc precip edit'),
	
	
	Y3_OLD = Y3;
	
	for ix = 1:24,
		pp = sscanf(get(PP11(ix),'string'),'%f',1);
		if PPHOURSUM(ix) ~= pp,
			STR = sprintf('Hour %d: old=%.2f,  new=%.2f',ix-1, PPHOURSUM(ix), pp);
			%fprintf('%s\n',STR);
			PPHOURSUM(ix) = pp;
			Y3((ix-1)*60+1 : ix*60) = zeros(60,1);
			Y3((ix-1)*60+30) = pp;
		end 
	end
	
	EditSer('write edit string');
			
	close(PP_EDIT);
	EditSer('replot');
%-------------------------------------------------------
%	'scalar data'
%-------------------------------------------------------
	elseif strcmp(kmode,'scalar data'),
	set(MENU_DATATYPE,'label','Data Type (Scalar)');
	DATATYPEFLAG = 0;
	EditSer('replot');
	
%-------------------------------------------------------
%	'direction data'
%-------------------------------------------------------
	elseif strcmp(kmode,'direction data'),
	set(MENU_DATATYPE,'label','Data Type (Direction)');
	DATATYPEFLAG = 1;
	EditSer('replot');
	
	
%-------------------------------------------------------
%	'precip data'
%-------------------------------------------------------
	elseif strcmp(kmode,'precip data'),
	set(MENU_DATATYPE,'label','Data Type (precip)');
	DATATYPEFLAG = 2;
	
	PPHOURSUM = [];  
	% PRECIP COMPUTE HOURLY SUMS ==>> PPHOURSUM
	ihour = floor(DT/60);	% mark all times for the hour only
	for ihr = 0:23,			% look at each hour of the day
		ix = find(ihour == ihr & ~isnan(Y3) );	% find index for the hour
		if length(ix > 0),
			PPHOURSUM = [PPHOURSUM; sum(Y3(ix))];
		else
			PPHOURSUM = NaN;
		end
	end
	EditSer('replot');
	
%-------------------------------------------------------
% 'y1-y3 substitute' -- swap y1 into y3
%-------------------------------------------------------
	elseif strcmp(kmode,'y1-y3 substitute'),
		Y3_OLD = Y3;
				
		% compute the index in X3 of the DT points
		if length(I_SELECT) > 0,
			im = DT(I_SELECT)+1; 		% selected indices 
			Y3(I_SELECT) = Y1(I_SELECT);	% substitute
		end
		
		STR = sprintf('%4d -- %4d   Exchange use secondary.', ...
			I_SELECT(1), I_SELECT(length(I_SELECT)));
		EditSer('write edit string');
		EditSer('replot');
		
%-------------------------------------------------------
%  dot or line plot primary
%-------------------------------------------------------
	elseif strcmp(kmode,'lines/dots'),
	
		if DOTFLAG == 0
			DOTFLAG = 1;
		else
			DOTFLAG = 0;
		end
		
		EditSer('replot');
	
%-------------------------------------------------------
%  'restore'  -- 
%-------------------------------------------------------
	elseif strcmp(kmode,'restore'),
		y3dum = Y3_OLD;  Y3_OLD = Y3;  Y3 = y3dum;
		
		STR = sprintf('Undo previous edit');
		EditSer('write edit string');
		
		figure(FG_MAIN);  axes(AX_MAIN);
		set(PL3,'visible','off');
		EditSer('replot');
	
%-------------------------------------------------------
%  'zoom'  -- 
%-------------------------------------------------------
	elseif strcmp(kmode,'zoom'),
		figure(FG_MAIN);
		
% 		if ZOOMFLAG
% 			set(ZOOM_BOX,'visible','off');
% 		end
		
		ZOOMFLAG = 1;
		%fprintf('zoom called\n');
		mousesel('clearzoom');
		
		
		mousesel;  % ==>> ZOOMPOS = [x0,y0,xend,yend]
		
%-------------------------------------------------------
%  'zoom acknowledge'  -- 
% output -- 
%  ZT1, ZT2 in minutes
%  ZY1, ZY2 in graph ordinate units
%-------------------------------------------------------
	elseif strcmp(kmode,'zoom acknowledge'),
	
		% SORT THE ZOOM BOX AND DEFINE THE END TIMES AND END VALUES
		t = sort([ ZOOMPOS(1) ZOOMPOS(3) ]);
		ZT1 = t(1);   ZT2 = t(2);		% in datenum units
		
		t = sort([ZOOMPOS(2)  ZOOMPOS(4)]);
		ZY1 = t(1);   ZY2 = t(2);
		
		%fprintf('zoom limits, %s to %s\n',datestr(ZT1), datestr(ZT2));
		
		% SELECT THE POINTS DEFINED BY THE ZOOM
		% MISSING POINTS -- 
		I_ZOOMMISSING = find(DT >= ZT1 & DT <= ZT2 & isnan(Y3));  % indexes time between zoom limits
		
		% good points
		I_ZOOMSELECT = find(DT >= ZT1 & DT <= ZT2 & Y3 >= ZY1 & Y3 <= ZY2 & ~isnan(Y3));
		
		% edit notation
		STR = sprintf('Zoom select, (%s) to (%s),  range = (%g, %g)',...
			dtstr(ZT1,'csv'), dtstr(ZT2,'csv'), ZY1, ZY2);
		fprintf('%s\n',STR); % TEST
		EditSer('write edit string');
		
%-------------------------------------------------------
%  'zoom delete'  -- 
%-------------------------------------------------------
	elseif strcmp(kmode,'zoom delete'),
		
		Y3_OLD = Y3;
		
		%fprintf('Delete, Y3 =[%.1f, %.1f], X3=[%d, %d]\n',ZY1, ZY2, ZT1\60, ZT2\60);
		
		if length( I_ZOOMSELECT ) > 0
			Y3(I_ZOOMSELECT) = NaN * ones(size(I_ZOOMSELECT));
		end
	
		if ZOOMFLAG
			set(ZOOM_BOX,'visible','off');
		end
	
		ZOOMFLAG = 0;
		
		STR = sprintf('Zoom delete points');
		EditSer('write edit string');
		
		EditSer('replot');
%-------------------------------------------------------
%	'zoom set value'
%-------------------------------------------------------
	elseif strcmp(kmode,'zoom set value'),
		
		STR = sprintf('Zoom set to constant value');
		EditSer('write edit string');
			
		FG2 = figure('position',[50,200,150,50],'color',FIGCOLOR,...
			'name','ZOOM SET TO CONSTANT VALUE');		
				
		hc21 = uicontrol(gcf,...
			'style','text',...
				'position',[2,35,130,15],...
				'string','Enter value');
				
		HC22 = uicontrol(gcf,...
			'style','edit',...
			'position',[5,10,140,20],...
			'string', sprintf('CONSTANT:    %.5f',...
				Q(3) ),...
			'min',0,'max',0,...  % allows a return to close
			'callback', 'EditSer(''zoom set constant'');');	
%-------------------------------------------------------
%	'zoom set constant' -- select offset amount for the T1, T2 interval.
% Unlike the quadratic correction or the offset functions, this function
% will set all selected and any missing points to the designated value.
% Thus, we need to find the zoom selected and the missing points in the 
% time interval.
%  I_ZOOMSELECT is all the indexes of selected points.
%  
%-------------------------------------------------------
	elseif strcmp(kmode,'zoom set constant')
		Y3_OLD = Y3;	
		str = get(HC22,'string');
		
		I_SELECT = sort([I_ZOOMSELECT; I_ZOOMMISSING]); % zoomed or missing
		value = sscanf(str([10:length(str)]),'%f',1);
		Y3(I_SELECT) = value * ones(size(I_SELECT));
		STR = sprintf('Zoom set to constant value: %f', value);
		EditSer('write edit string');
		close(FG2);
		
		if ZOOMFLAG
			set(ZOOM_BOX,'visible','off');
		end
		ZOOMFLAG = 0;

		EditSer('replot');		
%-------------------------------------------------------
%	'zoom offset'
%-------------------------------------------------------
	elseif strcmp(kmode,'zoom offset'),
		
		STR = sprintf('Zoom offset');
		EditSer('write edit string');
			
		FG2 = figure('position',[50,200,150,50],'color',FIGCOLOR,...
			'name','ZOOM OFFSET SELECTED POINTS');		
				
		hc21 = uicontrol(gcf,...
			'style','text',...
				'position',[2,35,130,15],...
				'string','Enter value');
				
		HC22 = uicontrol(gcf,...
			'style','edit',...
			'position',[5,10,140,20],...
			'string', sprintf('CONSTANT:    %.5f',...
				Q(3) ),...
			'min',0,'max',0,...  % allows a return to close
			'callback', 'EditSer(''zoom offset do'');');	
%-------------------------------------------------------
%	'zoom offset do' -- apply the offset for the T1, T2 interval
%-------------------------------------------------------
	elseif strcmp(kmode,'zoom offset do')
		Y3_OLD = Y3;	
		str = get(HC22,'string');
		Q(3) = sscanf(str([10:length(str)]),'%f',1);
		Q(1) = 0;  Q(2) = 1;
		%close(HC22);
		
		I_SELECT = I_ZOOMSELECT;	% only work on the zoomed points
		EditSer('y3 quadratic');
		
%-------------------------------------------------------
%  'zoom stats -- compute statistics of zoomed area'  -- 
%-------------------------------------------------------
	elseif strcmp(kmode,'zoom stats'),
		
		Y3_OLD = Y3;	

		y = Y3(I_ZOOMSELECT);
		
		if ZOOMFLAG
			set(ZOOM_BOX,'visible','off');
		end
		ZOOMFLAG = 0;

		STR = sprintf('COMPUTE STATS');
		disp(STR);
		
		STR = sprintf('Stat times: %s to %s', dtstr(ZT1,'short'), dtstr(ZT2,'short'));
		disp(STR);
		
		STR = sprintf('Samp time: %.1f hrs,  Npts = %d',(ZT2-ZT1)*24, length(I_ZOOMSELECT));
		disp(STR);
		
		STR = sprintf('Primary (av, stdev, min,max): %.2f, %.2f, %.2f, %.2f',...
			meanseries(y), Stdev(y), min(ScrubSeries(y)), max(ScrubSeries(y)));
		disp(STR);
		
		if SECONDARY_FLAG == 1,
			z = Y1(I_ZOOMSELECT);
			
			% SECONDARY OVER THE SAME PERIOD
			STR = sprintf('Secondary (av, stdev, min,max): %.2f, %.2f, %.2f, %.2f',...
				meanseries(z), Stdev(z), min(ScrubSeries(z)), max(ScrubSeries(z)));
			disp(STR);
			
			% DIFFERENCE STATISTICS
			disp('DIFFERENCE, TS1 - TS2');
			x = ScrubSeries(y-z);
			STR = sprintf('av,stdev,min,max: %.2f, %.2f, %.2f, %.2f',...
				mean(x), std(x), min(x), max(x));
			disp(STR);
		end
	
		
		
		% EditSer('write edit string');
		
%-------------------------------------------------------
%  'zoom substitute secondary'  -- 
%-------------------------------------------------------
	elseif strcmp(kmode,'zoom substitute secondary'),
		
		Y3_OLD = Y3;	

		ix = union(I_ZOOMMISSING, I_ZOOMSELECT);
		if length( ix ) > 0
			%[Y3(ix)  Y1(ix)]
			Y3(ix) = Y2(ix);
		end
		
		
		if ZOOMFLAG
			set(ZOOM_BOX,'visible','off');
		end
		ZOOMFLAG = 0;

		STR = sprintf('Zoom substitute secondary.');
		EditSer('write edit string');
		
		EditSer('replot');
%-------------------------------------------------------
%  'zoom expand'  -- 
%-------------------------------------------------------
	elseif strcmp(kmode,'zoom expand'),
		
		
		TLIM = [ZT1; ZT2];		% limit in hours
		YLIM = [ZY1; ZY2];				% limit in ordinate units
		
		T1 = ZT1;  T2 = ZT2;
		ZOOMFLAG = 0;
		EditSer('replot');
		
%-------------------------------------------------------
%  'filter'  -- 
%-------------------------------------------------------
	elseif strcmp(kmode,'filter'),
		
		FG_FILTER = figure('position',[5,100,300,150],'color',FIGCOLOR,...
			'name','FILTER');
		%  RANE SETTING FOR PURGE/CLIP
		uicontrol(gcf,'style','text',...
			'position',[2,112,60,20],...
			'string','RANGE',...
			'backgroundcolor',FIGCOLOR);
			
		HC44 = uicontrol(gcf,'style','edit',...
			'position',[50,112,150,20],...
			'string',sprintf('%.4g   %.4g', CLIP),...
			'min',0,'max',0,...
			'backgroundcolor',FIGCOLOR);
			
		HC46 = uicontrol(gcf,'style','radio',...
			'position',[200,118,100,20],...
			'string','Purge',...
			'value',0,...
			'backgroundcolor',FIGCOLOR,...
			'callback','EditSer(''purge on'')');
			
		HC47 = uicontrol(gcf,'style','radio',...
			'position',[200,102,100,20],...
			'string','Clip',...
			'value',1,...
			'backgroundcolor',FIGCOLOR,...
			'callback','EditSer(''clip on'');');
		
		% REMOVE SPIKE OPTION
		HC42 = uicontrol(gcf,'style','checkbox',...
			'position',[5,80,100,20],...
			'string','Remove spikes',...
			'value',0,...
			'backgroundcolor',FIGCOLOR);
			
			
		%  REMOVE MEAN OPTION
		HC41 = uicontrol(gcf,'style','checkbox',...
			'position',[120,80,100,20],...
			'string','Remove mean',...
			'value',0,...
			'backgroundcolor',FIGCOLOR);
			
			
		%  SMOOTHER OPTION
		HC43 = uicontrol(gcf,'style','checkbox',...
			'position',[2,22,70,20],...
			'string','Smooth',...
			'value',0,...
			'backgroundcolor',FIGCOLOR);
			
		uicontrol(gcf,'style','text',...
			'position',[85,22,30,20],...
			'string','Lags=',...
			'backgroundcolor',FIGCOLOR);
			
		HC45 = uicontrol(gcf,'style','edit',...
			'position',[116,22,35,20],...
			'string',' 10',...
			'max',0,'min',0,...
			'backgroundcolor',FIGCOLOR);
		
		uicontrol(gcf,'style','text',...
			'position',[154,22,20,20],...
			'string','mins',...
			'backgroundcolor',FIGCOLOR);
			
		% GO BUTTON		
		uicontrol(gcf,'style','pushbutton',...
			'position',[250,0,50,20],...
			'string','GO',...
			'callback','EditSer(''do filter'');');
			
%-------------------------------------------------------
%  'purge on'
%-------------------------------------------------------
	elseif strcmp(kmode,'purge on'),
	
	set(HC46,'value',1)
	set(HC47,'value',0)
	
	
%-------------------------------------------------------
%  'clip on'
%-------------------------------------------------------
	elseif strcmp(kmode,'clip on'),
	
	set(HC47,'value',1)
	set(HC46,'value',0)
	
%-------------------------------------------------------
%  'do filter'  -- 
%-------------------------------------------------------
	elseif strcmp(kmode,'do filter'),
	Y3_OLD = Y3;
	
	str = get(HC44,'string');
	
	%  clip the series, make out of range = NaN
	clip = sscanf(str,'%f  %f',2);
	CLIP = clip;
	set(HC44,'string', sprintf('%f    %f',clip(1), clip(2)));	
	%fprintf('  clip: from %.5e  to  %.5e\n',clip(1), clip(2));
	if get(HC46,'value') ~= 0,	% 	PURGE
		%fprintf('PURGE out of range points\n');
		Y3 = cleanseries(Y3,clip);
		STR = sprintf('Purge all points outside %f--%f',clip(1), clip(2));
		EditSer('write edit string');
	end
	if get(HC47,'value') ~= 0,	% 	CLIP
		%fprintf('CLIP out of range points\n');
		Y3 = clipseries(Y3,clip);
		STR = sprintf('Clip all points outside %f--%f',clip(1), clip(2));
		EditSer('write edit string');
	end
	
	%  REMOVE SPIKES
	if get(HC42,'value'),
		%fprintf('  Remove spikes\n');
		STR = sprintf('Remove spikes -- not implemented');
		EditSer('write edit string');
	end
	% REMOVE MEAN
	if get(HC41,'value')
		%fprintf('  Remove mean\n');
		Y3 = Y3 - mean(scrubser(Y3,[-inf,inf]));
		STR = sprintf('Remove  mean');
		EditSer('write edit string');
	end
	
	% SMOOTHER -- 
	if get(HC43,'value'),
		% no. lags for window.
		LAG = str2num(get(HC45,'string'));
		%fprintf('  Smooth, lag = %d\n',LAG);
		
		% make a one-sided window for the filter function
		kernal = hanning(2 * LAG - 1);
		kernal = kernal( fix(length(kernal)/2 + 1) : length(kernal));
		% normalize the kernal
		kernal = kernal ./ sum(kernal);
		
		% filter the series
		Y3 = filter(kernal, 1, Y3);  % TEST
		
		STR = sprintf('Smooth, hanning window, lags = %d',LAG);
		EditSer('write edit string');
	end
	close(FG_FILTER);	
	
	EditSer('replot');
	
	
%-------------------------------------------------------
%	REPLOT -- redraw the curves
%-------------------------------------------------------
	elseif strcmp(kmode,'replot'),	
	
		figure(FG_MAIN);  axes(AX_MAIN);
		
		I_SELECT = find(DT >= TLIM(1) & DT <= TLIM(2) & (Y3 >= YLIM(1) & Y3 <= YLIM(2)) | isnan(Y3));
		npts = length(I_SELECT);
		% turn off the current display
		set(PL3,'visible','off');
		%set(PL1,'visible','off');
		
		% PRIMARY SERIES
		if DOTFLAG == 1
			stystr = '.b';
		else
			stystr = '-b';
		end
		
		% PLOT THE PRIMARY SERIES ACCORDING TO TYPE
		%fprintf('Plot primary series...\n');
		if DATATYPEFLAG == 0,
			PL3 = plot(DT,Y3,stystr);
			%set(TXHAND,'string','');
		elseif DATATYPEFLAG == 1,
			PL3 = plot(DT,Y3,stystr);
			%set(TXHAND,'string','Direction plot');
		elseif DATATYPEFLAG == 2
			%fprintf('plot ppt \n');
			for ihr = 0:23
				PL3 = [PL3; plot([ihr; ihr; ihr+1; ihr+1],...
				 [0; PPHOURSUM(ihr+1); PPHOURSUM(ihr+1); 0],'-b')];
			end
			
			% FIND THE SUM OF ALL PRECIP
			totpp = 0;
			ix = find(~isnan(PPHOURSUM));
			if length(ix) > 0,
				totpp = sum(PPHOURSUM(ix));
				set(TXHAND,'string',sprintf('PPT TOTAL: %.2f',totpp));
			else
				totpp = NaN;
			end
		end
	
		if DOTFLAG == 1
			%fprintf('  Set dot size\n');
			% adjust the size of the dots
			if npts <= 200,  
				set(PL3,'markersize',8);
			elseif npts <= 500 & npts > 200, 
				set(PL3,'markersize',8);
			else 
				set(PL3,'markersize',8);
			end
		end
	
		
		
		
		% SECONDARY SCALING
		if SECONDARY_FLAG == 1 
			%fprintf('Plot secondary\n');
			hold on
			PL1 = plot(DT,Y1,'r.');  % TEST020704
			set(PL1,'markersize',8);
			hold off
			set(PL1,'visible','on');
		end
		
		% y-axis scaling
		set(AX_MAIN,'ylim',YLIM, 'xlim',TLIM);
		
		if diff(TLIM) < 10
			tdif = 1;
		else
			tdif = 2;
		end
	
	
		[ttk,htk, sthtk] = MakeHourTicks(T1,T2);
	
		[y,M,d,h,m,s]=datevec(T1); [y,jd]=dt2jdf(T1); jd=fix(jd);
		str1=sprintf('%4d-%02d-%02d (%03d) %02d:%02d',y,M,d,jd,h,m);
		[y,M,d,h,m,s]=datevec(T2); [y,jd]=dt2jdf(T2); jd=fix(jd);
		str2=sprintf('%4d-%02d-%02d (%03d) %02d:%02d',y,M,d,jd,h,m);
		[y,M,d,h,m,s]=datevec(now); str3=sprintf('%4d-%02d-%02d, %02d:%02d',y,M,d,h,m);
		str=sprintf('%s   to   %s',str1,str2);
		TXHAND = text(T1,0,str);
		set(TXHAND,'units','normalized',...
			'position',[.01, .97],'fontweight','bold',...
			'fontsize',12);
		str=sprintf('now = %s',str3);
		TXHAND = text(T1,0,str);
		set(TXHAND,'units','normalized','HorizontalAlignment','right',...
			'position',[.97, .97],'fontweight','normal',...
			'fontsize',12);
		

		% apply ticks on 
		set(gca,'xtick',ttk, 'xticklabel',sthtk,'linewidth',2);
		if GRID_FLAG == 1
			set(gca, 'xgrid','on','ygrid','on');
		else
			set(gca, 'xgrid','off','ygrid','off');
		end
			
        %=========================
        % TITLE
        %=========================
        txh = title(TITLE);
        set(txh,'fontweight','bold', 'fontsize',18);
		
		%set(AX_MAIN, 'fontweight','bold','fontsize',14);
        set(gca, 'fontweight','bold','fontsize',18);
		
%-------------------------------------------------------
%	'y3_only' -- show only the y3 plot
%-------------------------------------------------------
	elseif strcmp(kmode,'y3 only'),		
		
		if SECONDARY_FLAG == 1
				SECONDARY_FLAG = 0;
		else
			SECONDARY_FLAG = 1;
		end
		
		%fprintf('secondary plot flag = %d\n',SECONDARY_FLAG);
		EditSer('replot');
		
%-------------------------------------------------------
%  'set limits' -- 
%  START AND STOP TIMES
%  y scale limits
%-------------------------------------------------------
	elseif strcmp(kmode,'set limits'),
	
		% OPEN AN EDIT WINDOW
		FG_LIMITS = figure('position',[25,25,250,120],'color',FIGCOLOR,...
			'name','SET AXES');
		
		% MAKE THE TIME EDIT BOXES------------------	
		uicontrol(gcf,'style','text',...
			'position',[2,27,140,20],...
			'string','TIME AXIS',...
			'backgroundcolor',FIGCOLOR);
		
		uicontrol(gcf,'style','text',...
			'position',[2,2,20,18],...
			'string','T1:',...
			'backgroundcolor',FIGCOLOR);	
		
		HC11 = uicontrol(gcf,'style','edit',...
			'position',[22,2,50,18],...
			'string', sprintf(' %02d:%02d ',fix(TLIM(1)), fix(60*rem(TLIM(1),1)) ),...
			'min',1,'max',1,...  
			'backgroundcolor',FIGCOLOR);	
			
		uicontrol(gcf,'style','text',...
			'position',[90,2,20,18],...
			'string','T2:',...
			'backgroundcolor',FIGCOLOR);	
		
		HC12 = uicontrol(gcf,'style','edit',...
			'position',[120,2,50,18],...
			'string', sprintf(' %02d:%02d ',fix(TLIM(2)), fix(60*rem(TLIM(2),1)) ),...
			'min',1,'max',1,...  
			'backgroundcolor',FIGCOLOR,...
			'callback','EditSer(''set axis'');');	
			
		% MAKE THE ORDINATE EDIT BOXES -----------------------------
		uicontrol(gcf,'style','text',...
				'position',[2,100,140,20],...
				'string','Y AXIS',...
				'backgroundcolor',FIGCOLOR);
				
		uicontrol(gcf,'style','text',...
			'position',[2,83,25,18],...
			'backgroundcolor',FIGCOLOR,...
			'string','Max');
			
		HC13 = uicontrol(gcf,'style','edit',...
			'position',[28,83,90,18],...
			'string', sprintf('%.3e',YLIM(2)),...
			 'min',1,'max',1,...  % allows a return to close
			'backgroundcolor',FIGCOLOR);	
			
		uicontrol(gcf,'style','text',...
			'position',[2,58,25,20],...
			'backgroundcolor',FIGCOLOR,...
			'string','Min');
		HC14 = uicontrol(gcf,'style','edit',...
			'position',[28,58,90,18],...
			'string', sprintf('%.3e',YLIM(1)),...
			'min',1,'max',1,...  
			'backgroundcolor',FIGCOLOR);	
			
		
		% RADIO BUTTONS ----------------------------------------------------
		uicontrol(gcf,'style','push',...
			'position',[180,2,75,20],...
			'string','GO',...
			'backgroundcolor',FIGCOLOR,...
			'callback','EditSer(''go set limits'');');
			
		uicontrol(gcf,'style','push',...
			'position',[180,98,75,20],...
			'string','Y Self scale',...
			'backgroundcolor',FIGCOLOR,...
			'callback','EditSer(''y self scale'');');
%-------------------------------------------------------
% after completing the scale edit window
%-------------------------------------------------------
	elseif strcmp(kmode, 'go set limits')
		% DECODE TIMES AND SET LIMITS
		str = get(HC11,'string');
		t = fix(sscanf(str,'%f:%f',2));
		TLIM(1) = t(1) + t(2) / 60;		% in f.p. hour of the day
		
		% decode mx time and convert to mins
		str = get(HC12,'string');
		t = fix(sscanf(str,'%f:%f',2));
		TLIM(2) = t(1) + t(2)/60;		% in f.p. hour of the day
		YLIM(1) = str2num(get(HC14,'string'));  % y min
		YLIM(2) = str2num(get(HC13,'string'));  % y max
		close(FG_LIMITS);
		EditSer('replot');
%-------------------------------------------------------
%  'y self scale' --
%-------------------------------------------------------
	elseif strcmp(kmode, 'y self scale')
		
		YLIM = [-inf; inf];
		
		close(FG_LIMITS);
		
		Editser('replot');
				
%-------------------------------------------------------
%	'y3 create' -- 
%  create the output series y3 (1440 x 1) and plot
%  on the main plot
%  Primary series: DT Y3
%  Secondary series DT, Y1
%-------------------------------------------------------
	elseif strcmp(kmode,'y3 create')
	
		% FIRST -- FORM OUTPUT SERIES FROM SERIES 1
		% if only one series, then the output series = input series
		Y3 = Y1;
				
		Y3_OLD = Y3;  % for the "restore command"		
			
		% SECOND -- IF TWO INPUT SERIES, PUT SECONDARY INTO Y1
		% if two series, then put series 2 into series 1	
		if NSER == 2,
			%fprintf('swap y2 into y1\n');
			Y1 = Y2;
			y1old = Y1;  % for the "restore command"	
		end
%-------------------------------------------------------
%	'y3 offset' -- select offset amount for the T1, T2 interval
%-------------------------------------------------------
	elseif strcmp(kmode,'y3 offset')
	
		FG2 = figure('position',[50,200,150,50],'color',FIGCOLOR,...
			'name','Y3 OFFSET');		
				
		hc21 = uicontrol(gcf,...
			'style','text',...
				'position',[2,35,130,15],...
				'string','Enter offset amount');
				
		HC22 = uicontrol(gcf,...
			'style','edit',...
			'position',[5,10,140,20],...
			'string', sprintf('OFFSET:    %.5f',...
				Q(3) ),...
			'min',0,'max',0,...  % allows a return to close
			'callback', 'EditSer(''y3 enter offset'');');	
%-------------------------------------------------------
%	'y3 enter offset' -- select offset amount for the T1, T2 interval
%-------------------------------------------------------
	elseif strcmp(kmode,'y3 enter offset')
		str = get(HC22,'string');
		Q(3) = sscanf(str([8:length(str)]),'%f',1);
		Q(1) = 0;  Q(2) = 1;
		%close(HC22);
		
		EditSer('y3 quadratic');
%-------------------------------------------------------
%	'y3 quad' -- select offset amount for the T1, T2 interval
%-------------------------------------------------------
	elseif strcmp(kmode,'y3 quad')
	
		FG2 = figure('position',[50,200,200,100],'color',FIGCOLOR,...
			'name','Y3 QUAD');	
			
		hc30 = uicontrol(gcf,'style','text',...
			'position',[2,77,190,20],...
			'string','y3 = Q1 * y3^2 + Q2 * y3 + Q3');	
				
		hc31 = uicontrol(gcf,...
			'style','text',...
				'position',[2,52,20,20],...
				'string','Q1');
				
		hc32 = uicontrol(gcf,...
			'style','text',...
				'position',[2,27,20,20],...
				'string','Q2');
				
		hc33 = uicontrol(gcf,...
			'style','text',...
				'position',[2,2,20,20],...
				'string','Q3');
				
		HC31 = uicontrol(gcf,...
			'style','edit',...
			'position',[25,52,100,20],...
			'string',sprintf('%f',Q(1)),...
			'min',0,'max',0);	
		HC32 = uicontrol(gcf,...
			'style','edit',...
			'position',[25,27,100,20],...
			'string',sprintf('%f',Q(2)),...
			'min',0,'max',0);	
			
		HC33 = uicontrol(gcf,...
			'style','edit',...
			'position',[25,2,100,20],...
			'string',sprintf('%f',Q(3)),...
			'min',0,'max',0);	
		uicontrol(gcf,'style','push',...
			'position',[150,10,100,20],...
			'string','GO',...
			'backgroundcolor',FIGCOLOR,...
			'callback','EditSer(''y3 enter quad'');');
			
		
%-------------------------------------------------------
%	'y3 enter quad' -- select offset amount for the T1, T2 interval
%-------------------------------------------------------
	elseif strcmp(kmode,'y3 enter quad')
		str = get(HC31,'string');
		Q(1) = sscanf(str,'%f',1);
		str = get(HC32,'string');
		Q(2) = sscanf(str,'%f',1);
		str = get(HC33,'string');
      Q(3) = sscanf(str,'%f',1);
      %fprintf('Q1,Q2,Q3: %f, %f, %f\n',Q(1),Q(2),Q(3));
		EditSer('y3 quadratic');
%-------------------------------------------------------
%	'y3 quadratic' -- 
%-------------------------------------------------------
	elseif strcmp(kmode,'y3 quadratic')
	

		Y3_OLD = Y3;		% for restore command
		

		if length(I_SELECT) > 0,
			Y3(I_SELECT) = polyval(Q, Y3(I_SELECT));
		
			STR = sprintf('Quadratic Fit: %g,  %g,  %g',...
				Q(1), Q(2), Q(3) );
			EditSer('write edit string');
			
			% CORRECT FOR DIRECTION NOT IN [0,360) RANGE.
			if DATATYPEFLAG == 1,
				lenix = length( find( Y3 >=360 | Y3 < 0 ));
				if lenix > 0,
					Y3 = rem(Y3,360);
					ix = find( Y3 < 0 );
					if length(ix) > 0,
						Y3(ix) = Y3(ix) + 360 * ones(size(ix));
					end
					STR = sprintf('Direction correct %d points',lenix);
					EditSer('write edit string');
					
				end
			end
		
		end
		
		close(FG2);
% 		set(ZOOM_BOX,'visible','off');
% 		ZOOMFLAG = 0;
	
		EditSer('replot');		
		
%-------------------------------------------------------
%  'interpolate fill'  -- 
%-------------------------------------------------------
	elseif strcmp(kmode,'interpolate fill'),
		
		Y3_OLD = Y3;
		fprintf('interpolate fill\n');

		%the zoomed points are determined by I_SELECT.
		% we want to find all nan in this set and then 
		% interpolate over them.
		x = Y3(I_SELECT);  % short time series
		%TEST [[1:length(x)]' x]
		%fprintf('test - %d points to fill.\n',length(I_SELECT));
		t = DT(I_SELECT);  % short time series time base
		ix=find(isnan(x)); % find nans in the short time series
		%fprintf('test - %d NaNs in range.\n',length(ix));
		if length(ix) > 0, % if nans exist then fill them
			fprintf('Missing points = %d\n',length(ix));
			tnan=t(ix);		% times of bad values
			iy=find(~isnan(x));  % locate the good values
			x1=x(iy); t1=t(iy);  % only good values
			x2=interp1(t1,x1,tnan); % interpolate for all nan data
			x(ix)=x2; % fill in the interpolated values
			Y3(I_SELECT)=x;
		end
		
		STR = sprintf('interpolate fill');
		EditSer('write edit string');
		
		EditSer('replot');
%-------------------------------------------------------
%	'clean' -- 
%-------------------------------------------------------
	elseif strcmp(kmode,'clean')
		close all	
	
%-------------------------------------------------------
%	'test' 
%-------------------------------------------------------
	elseif strcmp(kmode,'test')

		load EditSer_test.mat;
		
		VARNAME = 'sst';
		MISSING = -99;
		EDFILE = 'hd:ftpio:Edit_test.txt';
		SAVESTRING = 'fprintf(''EditSer test, do not save the data\n'');';
		
		% begin the edit process
		%fprintf('Test EditSer with test series\n');
		EditSer(t, x, x1);
%-------------------------------------------------------
%	error -- no match
%-------------------------------------------------------
	else
		%fprintf('EditSeries: incorrect kmode\n');
	end
end

