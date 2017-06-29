function [ibad] = TimeBaseJump(tx),
%=========================================
%
% function [ibad] = TimeBaseJump(tx),
%
% The program checks through the time base and finds any points that
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
%
%output
% ibad = indexes of points that need removal.
%      returns [empty] if all is okay.
%===========================================
% v01 20061112 rmr -- create
ix = find(diff(tx) <= 0);
ibad = [];
		% SCAN EACH NON MONOTONIC POINT
j=1;
while j <= length(ix),
	ibad = [ibad; ix(j)+1];
	
	k=2;
	while tx(ix(j)+k) <= tx(ix(j)),
		ibad=[ibad; ix(j)+k];
		k = k + 1;
	end
	j=j+k-1;
end
fprintf('TimeBaseJump: TS size = %d, ibad length = %d\n',length(tx), length(ibad));
return
