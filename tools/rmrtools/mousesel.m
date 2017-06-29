function [ZOOMPOS] = MouseSel(switchstr),
%MOUSESEL -- use the mouse to drag a rectangle on a graph
%  [ZOOMPOS] = MouseSel(switchstr);
%input
%  switchstr is a recursive function.  
%  externally, the call is simply  [pos] = mousesel;
%
%ZOOMPOS -- is a global variable to be used by other fcns

global ZOOMPOS  ZOOM_BOX
global FG_MAIN  AX_MAIN

%  INITIALIZE THINGS
if nargin == 0 
	Hf = get(0,'children');
	if isempty(Hf),  error('No figure available'),  end
	
	Hf = FG_MAIN;
	Ha = findobj(Hf,'type','axes');
	if isempty(Ha),  error('No axes in current figure');, end
	
	set(Hf, 'pointer','crossh',...
		'backingstore','off',...
		'windowbuttondownfcn','mousesel(''start box'');');
	
	ZOOMPOS = [nan nan nan nan];
	ZOOM_BOX = [];
	
	figure(Hf);
	
%----------------------------------------------------------	
elseif strcmp(switchstr,'clearzoom')

	
	%fprintf('mousesel-clearzoom\n');
	
		if exist('ZOOM_BOX') & ~isempty(ZOOM_BOX), 
			% set(ZOOM_BOX,'visible','off');
			ZOOM_BOX = [];
		end
	
	
%----------------------------------------------------------		
elseif strcmp(switchstr,'start box'),
		
		%fprintf('mousesel-startbox\n');
		
		if ~isempty(ZOOM_BOX), 
			%set(ZOOM_BOX,'visible','off');
			ZOOM_BOX = [];
		end

	fp = get(gca,'currentpoint');	  fp = fp(1,1:2);
	set(gca,'userdata',fp);
	
	%fprintf('mouse button down at %f,  %f\n', fp(1), fp(2));
	
	set(gcf,'windowbuttonmotionfcn', 'mousesel(''motion'');',...
		'windowbuttonupfcn','mousesel(''end box'');' );

%----------------------------------------------------------		
%----------------------------------------------------------		
elseif strcmp(switchstr,'motion');

	fp = get(gca,'userdata');
	cp = get(gca,'currentpoint');  cp = cp(1, 1:2);
	
	H1 = line('xdata',[fp(1); cp(1); cp(1); fp(1); fp(1)],...
		'ydata',[fp(2); fp(2); cp(2); cp(2); fp(2)],...
		'erasemode','xor',...
		'color','k','linestyle','-',...
		'clipping','off');
	
	
	if ~isempty(ZOOM_BOX),  delete(ZOOM_BOX),  end
	ZOOM_BOX = H1;
	
	ZOOMPOS = [fp cp];

%----------------------------------------------------------		
%----------------------------------------------------------		
elseif strcmp(switchstr,'end box');
	%fprintf('mousesel-end box\n');
	
	set(gcf,'pointer','arrow',...
		'backingstore','on',...
		'windowbuttondownfcn', '',...
		'windowbuttonmotionfcn', '',...
		'windowbuttonupfcn', '');

	set(ZOOM_BOX,'erasemode','normal');
		
	eval('EditSer(''zoom acknowledge'');');

end

