% Initial development, 070413, rmr
% COMPARE TWO DIFFERENT TIME SERIES


% THE INPUT SERIES, A AND B
Na = length(dta);
Nb = length(dtb);
dta1 = dta(1);  dta2 = dta(end);
dtb1 = dtb(1);  dtb2 = dtb(end);
fprintf('Series A: %d points, %s to %s\n',Na, dtstr(dta1,'short'), dtstr(dta2,'short'));
fprintf('Series B: %d points, %s to %s\n',Nb, dtstr(dtb1,'short'), dtstr(dtb2,'short'));

% TRUNCATE AS NECESSARY TO THE SAME TS SIZE


% DIFFERENCE STATISTICS
TSdiff = ScrubSeries(taira-tairb);
fprintf('Mean difference (A-B) = %.3g,  Stdev = %.3g\n', mean(TSdiff), std(TSdiff));


return
