function [tgood, Xgood, ibad] = TimeBaseCheck(tx, X, maxjumpdays),
%=========================================
%
% function [tgood, Xgood, ibad] = TimeBaseCheck(tx, X, maxjumpdays),
%
% First positive jumps greater than maxjumpdays (days) are 
% located.  At each jump, all points are rmoved until the 
% too-big jumps are gone.
%
% Next, the program checks through the time base and finds any points that
% should be removed because time is non-monotonic.
% Points are marked for removal if diff(dt) <= 0.  Also,
% if diff(tx) < 0, all times are tagged until the time exceeds
% the first point where it was negative.
%
% Points are removed. 
% The time base does not have to be equally spaced.
%
% The first time point must be good.
%
%input
%  tx = datenum time series, nx1, n time points
% x = input array, (n x m), m variables,
% maxjumpdays == limit on positive jumps.
%
%output
% tgood = monotonic series (ngood x 1)
% Xgood = good series (ngood x m)
% ibad = indexes of points that need removal.
%      returns [empty] if all is okay.
%===========================================
% v01 20061112 rmr -- create
tgood=0; Xgood=0; ibad=0;

%% REMOVE POINTS WHERE THERE IS A TOO-BIG POSITIVE TIME JUMP
ix = find ( diff(tx) > maxjumpdays );
fprintf('Found %d gaps\n',length(ix));
while length(ix) > 0
	%% FIRST POINT OF THE BAD PATCH
	i1 = ix(end)+1;
	if i1 == length(tx), 
		i2 = i1;
	else
		%% THE NEXT POINT BELOW THE JUMP AMOUNT
		i2 = find( (tx(i1+1:end) - tx(i1-1)) < maxjumpdays );
		if ( length(i2) == 0 ) i2 = length(tx); 
		else i2 = i1+i2(1); end
	end
	tx(i1:i2) = [];
	X(i1:i2,:) = [];
	ix = find ( diff(tx) > maxjumpdays );
end

%% REMOVE POINTS WITH NEGATIVE TIME JUMPS

ix = find(diff(tx) <= 0);
while length(ix) > 0, 	
	fprintf('test Found %d non-monotonic points.\n',length(ix));
	%% THE LAST SLOPE <= 0
	j = ix(end);  
	%% THE FIRST POINT IN THIS NEGATIVE GROUP
	%% There could be several segments with diff(t)<=0 in a block
	jx = find(diff(tx(1:j)) > 0 );
	if length(jx) == 0, 
		i1 = 2;
	else
		i1 = jx(end)+2;
	end	
	%% THE LAST POIINT IN THE NEGATIVE BLOCK
	jx = find( tx(i1:end) > tx(i1-1) );
	if length(jx) == 0,
		i2 = length(tx);
	else
		i2 = jx(1)+i1-1;
		if i2 > length(tx), i2 = length(ix); end
	end
	
	%% POINT OUT BIG TIME JUMPS > 2 hours
	if (tx(i2)-tx(i1-1)) > 2/24, 
		fprintf('test Big time drop, index %d, %.1f hours\n',i1, (tx(i2)-tx(i1-1))*24);
	end
	%% REMOVE ALL THE POINTS IN THIS BLOCK
	fprintf('%d -- %d\n',i1,i2);
	ii=input('test quit?', 's');
	if strcmp(ii,'y'), return; end
	tx(i1:i2)=[];
	X(i1:i2,:) = [];
	%% LOOK FOR THE NEXT BAD PATCH
	ix = find(diff(tx)<=0);
end

tgood = tx;  Xgood = X;

return
