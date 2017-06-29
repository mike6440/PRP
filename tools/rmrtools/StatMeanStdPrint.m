function StatSeries(i1, i2, var, x)

fprintf('var = %s\n',var);
x


fprintf('%-10s %10.5f %10.5f\n', var, mean(x(i1:i2)), std(x(i1:i2)))'


return
