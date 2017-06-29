% SEE http://meted.ucar.edu/awips/validate/wetblb.htm
% The AWIPS calculation of wet bulb temperature is a function of
% relative humidity, temperature, and pressure. Relative humidity is
% checked to be sure the value is between 1-100%. Dewpoint is then
% calculated using the standard AWIPS algorithm. Using temperature,
% dewpoint, and pressure AWIPS finds the isobaric wet bulb temperature
% using an iterative technique.
% 
%  The first step is to calculate the saturation vapor pressure and
% dewpoint vapor pressure.
% 
%  Next, a first guess at the wet bulb temperature is calculated.
% 
%  Third, with a given guess of the wet bulb temperature, an attempt
% is made to do an energy balance. The difference (de) between the
% quantities below are examined:
% 
% 
% [The above equation can be found in Iribarne and Godson (1981)*]
% 
% When the difference between these is less than one part in 10,000 of
% the wet bulb vapor pressure, the looping calculation stops.
% Otherwise, a new guess at the wet-bulb temperature is calculated
% based on the difference found, and the loop is repeated. The new
% guess is found by taking the derivative (der) of the difference (de)
% with respect to the wet bulb temperature, which is fairly standard
% numerical technique for finding the zero value of a function.
% 
% The new wet bulb temperature is again tested. Up to ten iterations
% of the loop can be performed before a final value is returned.
% 
% From the above equations:
% 	¥ 	C  15  = 26.66082
% 	¥ 	C  1  = 0.0091379024
% 	¥ 	C  2  = 6106.396
% 	¥ 	T = temperature (K)
% 	¥ 	T  d  = dewpoint temperature (K)
% 	¥ 	s = intermediate step to calculate wet bulb
% 	¥ 	f = 0.0006355 = C  p  /(L*epsilon) (1/K)
% 	¥ 	C  p  = 1004 (J/(K*kg))
% 	¥ 	L = latent heat of vaporization = ~2.54 x 10  6  (J/kg)
% 	¥ 	epsilon = mass of water vapor / mass of dry air = ~0.622
% 	¥ 	p = pressure (mb)
% 	¥ 	T  w  = wet bulb temperature (K)
% 	¥ 	e  w  = wet bulb vapor pressure (mb)
% 
% *Iribarne, J. V., and W. L. Godson, 1981: Atmospheric
% Thermodynamics.  3d ed. D. Reidel, 259 pp.
% 
