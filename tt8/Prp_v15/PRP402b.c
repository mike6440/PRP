/*  Basic Quantities. */
#define  EEPROM_ID		8
#define	 VERSION	   "15b"
#define  EDITDATE	   "150625" //"140912"
#define	LOWSAMPPERIOD	6	// sec period in low mode

/* v15b - add HeaterOff to test loop  */

/* WARNING -- FAILURE MODE
  if the analog ppower -12 supply goes the head temperature circuit
  will be permanently in error. As an example, it is currently 
  failed and stuck at ~850 mv. The temperature comes out to ~10 C.
  So THE HEATER IS ALWAYS ON
  
  There has to some clever way to trap this failure.
*/

/*************************************************
FRSR --
v15 140905 rmr -- Set baud to 38400.
         If CheckHead returns 0 if Thead <-25 or >55. Disable heater. 

v402m -- Remove all RTC functions. Set-RTC(), Read_RTC(), QSM_Init(), and QSM_Uninit()

v402l -- remove zero tilt from menu.  Make it special.
		show true band rotation time
		shadow channel is set by eprom

v402k -- pitchroll zeros were not saved in eeprom.

v402j -- Add FRSR ON and OFF options to menu.
  If the FRSR is off the shadowband is parked but the head stays warm.

v402i -- ComputeNadirTime corrected

v402h -- CheckMode() error in transition timing

v402g -- Heartbeat at Startup()

v402e - CheckMode() uses head-1 chan for high/low

v402 -- JAMSTEC upgrade
 Add LIB file and proto402.c program functionality
 In sweep detection, use chan 4 and take the highest index with minimum value.
	The reason for taking the highest index is to push the minimum point
	so an amp with longer time constant will be fully down.
 Add SCS output files
 Develop Proto.c file

v401d -- Deleted RTC function.  Problems with electronic
  circuit.

v401c -- RSMAS preparation for PolarSea00 cruise
  Organized functions.  Used new RTC functions from ISAR

v401 -- 991101
 Single sweep operation
 New architecture with most processing done in laptop
 Baud = 28800

v304 -- 990820
 heartbeat() add to heater loop

v303 -- rmr 990524
 shadowratio overflow > 255 corrected

v302 -- rmr 990509
 This has the changes listed below.  Also, latest calib coefs for both
 01 and 02.  Compiled and saved as PRP_01.ahx or PRP_02.ahx
  1. shadowratio redefined
  2. shadowratio truncated to tenths, and shadowlimit resolution to tenths
	 we define a sweep if shadowratio >= limit

v301a --
  by setting a define, one can target different
  prp units.

VER 301
Taken from version 201 that went on the aerosol cruise
ray has made some alterations
* Add all seven channels to adc
**************************************************/

/* DATA FILE PACKING AND OUTPUT */
#define	NDATAFILE	50000  // size of data storage area
/* COMPOSITE AVERAGING */
#define	NBLKS 		11		// number of avg'd block per side of shadow
//#define	CHAN_SHADOW	3  		// the adc port (0--7) to search for a shadow

/* EEPROM DEFAULTS */
#define	MEMSTART   100
#define	DEFAULT_TEMP	35
#define	DEFAULT_PITCH	0
#define	DEFAULT_ROLL	0
#define DEFAULT_AZIMUTH 0
#define	DEFAULT_SHADRATIO	2.3  // THRESHOLD FOR SHADOW ANALYSIS
#define	DEFAULT_LOW		10  // mv from head-1 for low mode
#define	DEFAULT_TRANTIME	600 // sec transition time
#define DEFAULT_CYCLE 		6200  //rotation per in msec
#define DEFAULT_MINCHAN		4 // channel to look for a minimum value

/**************
Default configuration
0001 0101 binary -> 0011 hex
	0	NadirDisable; & 0x2 == test only, no nadir switch
	0	PrintSweep;	  & 0x4 == Do not print out each sweep
	0	BinaryBlock;  & 0x8 == Save and print binary
	1	SimulateHeadFlag; & 0x10 == puts in dummy sweep numbers
****************/
#define DEFAULT_CONFIGFLAG	0x0001
// MOTOR AND SHADOWBAND
#define	NSAMPS	250 // no. points across upper hemisphere
#define NCHANS 8
#define	NGLOBAL	10 // no. points at beg and end of sweep for global avg
// FLAG STATES
#define OK 1
#define NOTOK 0
#define YES 1
#define NO 0
#define OFF 0
#define ON 1
// MODE VALUES
#define TEST -1
#define LOW 0
#define TRANSITION  1
#define HIGH 2
// WATCHDOG TIMER  wdtwdt
#define	WDOGSECS	10


/*****************  INCLUDES *************************************/
// ansi
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#include <string.h>

#include <tt8.h>
#include <tat332.h>
#include <sim332.h>
#include <qsm332.h>
#include <tpu332.h>
#include <tpudef.h>
#include <dio332.h>
#include <tt8pic.h>
#include <tt8lib.h>
#include <userio.h>

/**************** VARIABLES *************************************/
int Missing;

/*****************
in and out buffers
*****************/
char	in_buffer[128];  // pointer only
char	str[128];
long	Baud_Rate;

/***********************************************************
 OPERATIONAL VARIABLES
***********************************************************/
// WATCHDOG TIMER  wdtwdt
time_t  wdogtime;
// MAIN LOOP
int RunMode; 		// -1=test stdby  0=low, 1=transition, 2=high
int WaitSecs;		// changed between high, transition, and low modes
// ADC VARIABLES
int 	adc12[NSAMPS*NCHANS];  // array size = 250*8 = 2000
int		adcMin[NCHANS];
int		nsamps;
// ADCEXT (4017) VARIABLES
double	adcext1[8], adcext2[8];  // 8 channels
// SWEEP VARIABLES
unsigned long Nsweeps;
double			adcMean, adcStd;
int 		idxMin;
float 		shadowratio;
int			sweepBlk[NBLKS*2+1][NCHANS];
char		SweepTime_string[26];
time_t		SweepTime;
int			globalSweep[2][NCHANS];
// TIME VARIABLES  timetime
char 		time_string[40];
struct tm	*rtc;
qsmdum[5];
// BLOCK AVERAGING
ushort		Nsz[NBLKS];
// SWEEP VARIABLES
int		Ncycles;
ulong	SampMicroSecs;
// DATA FILE PACKNG AND OUTPUT
uchar 			*datafile;
unsigned int 	df_index;
char			nmeastr[257];
unsigned		chksum;
//FLAGS
int		MotorPwrFlag;
int		PrintFlag;		//suppress printing in run mode
int		NadirDisable;	//   "        & 0x2 == test only, no nadir switch
int		PrintSweep;		//   "        & 0x4 == Do not print out each sweep
int		BinaryBlock;	//   "        & 0x8 == Save and print binary block
int		SimulateHeadFlag; // "        & 0x10 == puts in dummy sweep numbers
// HEATER AND HEAD TEMP  temptemp
int		HeaterFlag;
float	TempHead;
// PNI - TILT SENSOR VARIABLES
char *pnistr;		// output/input string for PNI
struct 	tiltstr
{
	float pitch;
	float roll;
	float azimuth;
} Tilt1, Tilt2;
float 	pitch, roll, azimuth;

// EEPROM VARIABLES
struct eeprom
{
	ushort	id;
	ushort	FrsrState;	// OFF=parked (same as low mode)  ON=normal operation
	ulong	CycleMilliSecs;
	float	TempHeadMax;
	float	pitch;
	float	roll;
	float	azimuth;
	float	ShadowRatio;
	unsigned ConfigFlag;
	unsigned Low;
	unsigned TransitionTime;
	unsigned MinChan;  // channel to look for minimum
};
struct eeprom *ee;

ulong msec0;  // shadowband cycle time

/******************** prototypes  ******************************/
/****** library functions **********************************/
int		SerPutStr(char *);
// MATH FUNCTIONS  mathmath
double 	d_round(double x);
void	MeanStdev(double*, double*, int, double);
// EEPROM FUNCTIONS eepromeeprom
int		StoreUee(struct eeprom *);
void	ReadUee(struct eeprom *);
void	PrintUee(struct eeprom *);
// TIME PROTOS    timetime
time_t  GetTime(char *);
time_t  ShowTime(void);
void 	SetDateTime(void);
/***** APPLICATION OPERATION  ********/
int		Startup(void);
void	Action(char *);
void	SetMode(int);
// HEATER AND HEAD TEMP
int		HeaterCheck(float, int);
void	HeaterPulse(int);
void	HeaterOn(int *);
void	HeaterOff(int *);
float	GetHeadTemp(void);  // returns temperature in degC
// 485 operation
short	Read4017All(double mv[]); // read all 8 chans into adcext[0-7][blk]
// ANALOG  analoganalog
int		ReadAnalog(int chan, int *, int missing);
void	ReadSweep(int *adc, int npts, ulong usecs);
// SHADOWBAND AND MOTOR  motormotor
void	MotorOff(int*);
void	MotorOn(int*);
ulong	ComputePeriod(void);
int		NadirCheck(time_t*);	// wait for arm to reach nadir
// PNI -- 	PRECISION NAVIGATION PITCH/ROLL/AZIMUTH
void	 ReadPNI(float*, float*, float*); // pitch, roll, az in degrees
void	PniCommand( char*, char *);  // send a command to the PNI
// DATA PROCESSING
void	ReadBlock(void); // start motor and make a full sweep
void	BlockSample(int nsamps);  // Take NSAMPS raw samples and store them.
void	PrintBlockTest(void);		// test print of entire adc block
void	PrintBlock(void);		// individual cycle printout
void	PackBlock(void);		// pack sweep data into a block
void 	PsuedoAscii(unsigned long, unsigned int); // returns character string
//void 	PackBytes(unsigned long, unsigned int, unsigned);
long 	CheckSum(char *packet, unsigned long N);
void	ProcessSweep(int nsamps);
void	CheckMode(ushort);
void	SendDataFile(unsigned);	// Send out the data file as a packet

// ONSET ROUTINES
void    HeartBeat(void);


void main()
/**************************************************************************/
{
	char  	chr1;
	int 	isec;	// for wait to top of minute
	int		i, ic;			// general purpose loop counter
	int		ifirst;   // used to jump to menu at startup
	ulong	cycleusecs, horizusec, clkf; //the time in usec from nadir to hemisphere
	time_t now;

	InitTT8 (NO_WATCHDOG, TT8_TPU);
	Missing = -999;
	nsamps = NSAMPS;

	// allocate memory for global pointer arrays
	ee = (struct eeprom *)calloc(1, sizeof(struct eeprom));
	datafile = (uchar*)calloc(NDATAFILE, sizeof(uchar));
	rtc = (struct tm*)calloc(1, sizeof(struct tm));

	// BAUD RATE IS 28800
	//SerSetBaud(19200, 16000000);  //Set Serial Baud Rate
	//SerSetBaud(38400, 16000000);  //Set Serial Baud Rate
	//v5 SerSetBaud(57600, 16000000);  //Set Serial Baud Rate

	// v402n set baud properly
	//clkf = SimSetFSys();
	clkf = 16000000;
	SerSetBaud(38400,clkf);
	printf("\n");
	printf("clkf = %ld\n", clkf);
	printf("\n");
	Baud_Rate = SerGetBaud(38400, clkf);  //Read Serial Baud Rate
	printf("Actual baud rate = %ld\n",Baud_Rate);
	// end v5 new code

	// BAUD RATE IS 28800
	//SerSetBaud(28800, 16000000);  //Set Serial Baud Rate
	//Baud_Rate = SerGetBaud(28800, 16000000);  //Read Serial Baud Rate

	/***********************
	// INITIALIZE THE TATTLETALE AND OTHER FUNCTIONS
	************************/
	if( Startup() == NOTOK )
	{
		printf("StartTT8 fails: stop\n");
		ResetToMon();
	}




	MotorPwrFlag=ON;
	MotorOff(&MotorPwrFlag);
	/*******************
	// SET THE COMPOSITE BLOCK AVERAGING VARIABLES
	// Total should equal 125 points for 25 point sweep
	********************/
	Nsz[0]=Nsz[1]=Nsz[2]=Nsz[3]=Nsz[4]=5;
	Nsz[5]=Nsz[6]=Nsz[7]=10;  Nsz[8]=Nsz[9]=20;  Nsz[10]=30;


	/*********************
	// INITIALIZE EEPROM STORED VARIABLES
	**********************/
	printf("Check EEPROM\n");
	ReadUee(ee);			// read eeprom structure to pointer ee
	if(ee->id == EEPROM_ID )
	{
		printf("EEPROM ID CHECKS");
	}
	else
	{
		printf("Initialize eeprom...\n");
		//SetUeeDefault();
		ee->id = EEPROM_ID;
		ee->CycleMilliSecs = DEFAULT_CYCLE;
		ee->TempHeadMax = DEFAULT_TEMP;
		ee->pitch = DEFAULT_PITCH;
		ee->roll = DEFAULT_ROLL;
		ee->azimuth = DEFAULT_AZIMUTH;
		ee->ShadowRatio = DEFAULT_SHADRATIO;
		ee->ConfigFlag = DEFAULT_CONFIGFLAG;
		ee->Low = DEFAULT_LOW;
		ee->TransitionTime = DEFAULT_TRANTIME;
		ee->FrsrState = ON;
		ee->MinChan = DEFAULT_MINCHAN;

		StoreUee(ee);
		ReadUee(ee);
		PrintUee(ee);
	}

	/*******************************
	// OTHER INITIALIZATIONS
	********************************/
	SetMode(HIGH);
	Nsweeps = 0;
	PrintFlag = NO;		// quiet mode until we enter the test mode

	/***********************************************
	MAIN LOOP WAIT FOR KEYBOARD ENTRY OR COMS INPUT
	***********************************************/
	printf("\n PRP Software Version: %s Edit: %s\n", VERSION, EDITDATE);

	/******************************
	// INITIALIZE CPU CLOCK FROM RTC
	********************************/
	//Read_RTC(rtc);
	//printf("RTC time: %04d-%02d-%02d %02d:%02d:%02d\n",
	 //rtc->tm_year+1900, rtc->tm_mon+1, rtc->tm_mday,
	 //rtc->tm_hour, rtc->tm_min, rtc->tm_sec);
	//SetTimeTM(rtc, NULL);
	strcpy(in_buffer,"U20000101000000\0");
	// call into action to set tt8 clock
	Action(in_buffer);  // produces a reply in out_buffer
	ShowTime();

	/*************************
	INITIALIZE WATCHDOG TIMER
	*************************/
	wdogtime = time(NULL) + 5;		// set time for next atchdog timer reset
	SerInFlush();

	/*********************
	MAIN LOOP
	mainmain
	**********************/
	ifirst = NO;  // TEST: set to NO for auto operation
	msec0 = 0; // initialize shadowband cycle time to start with default
	printf("Start main loop\n");
	while(1)
	{
		/**********************
		WATCHDOG TIMER RESET
		***********************/
		if( difftime(wdogtime, time(NULL)) <= 0 )
		{
			HeartBeat();
			wdogtime = time(NULL) + WDOGSECS;
		}

		/*****************************
		// CHECK FOR KEYBOARD ENTRY
		******************************/
		if( SerByteAvail() || ifirst == YES )
		{
			// IF KEYBOARD CHAR, GET THE CHARACTER
			if( ifirst == YES )
			{
				ifirst = NO;
				chr1 = 'T';
			}
			else	chr1 = SerGetByte();

			// FIRST CHECK FOR SINGLE STROKE Test CHARACTERS
			switch(chr1)
			{
				/**********************
				Test MODE LOOP
				keykey
				**********************/
				case 'T':
					// ENTER test MODE
					SetMode(TEST);
					HeaterOff(&HeaterFlag);
					/***************************
					Enter test mode
					Exit by changing mode or by time out
					***************************/
					while( RunMode == TEST )
					{
						printf("\n> ");
						gets(in_buffer);
						Action(in_buffer);
					}
					msec0 = 0;  // initialize the sweep computer
					break;
			}
		}
		/**************************
		COLLECT DATA
		sampsamp
		***************************/
		if( (RunMode == HIGH || RunMode == TRANSITION) )
		{
			/***********************
			Sample cycle -- first turn on the power
			Then wait for the arm to move to a nadir position
			The arm might be already at the nadir position or
			this routine will wait until it is.
			Returns NOTOK if the nadir is not valid.
			****************************/
			MotorOn(&MotorPwrFlag);   // turns motor on if it was off

			/**************************
			For the first cycle, the arm will go all the way around one
			sweep to sync on the start of the nadir switch on sector.
			On other cycles, the switch will be open after the composite
			calculations, and the sync will take place when the arm hits the
			nadir position.
			***************************/
			if( NadirCheck(&SweepTime) == OK )
			{
				sprintf(str," %.1fC ",TempHead);
				SerPutStr(str);
				ee->CycleMilliSecs = ComputePeriod();
				StopWatchStart();		// begin timing for horizon position
				horizusec =  ee->CycleMilliSecs * 1000 / 4;

				/*************
				Wait until 700 msec before horizon and turn off the heater.
				Read PNI for tilts and az
				**************/
				while( StopWatchTime() < horizusec - 700000);

				// Tilt sample at start of the sweep
				ReadPNI(&pitch, &roll, &azimuth);   //'P'
				if( Tilt1.pitch != Missing ) Tilt1.pitch = pitch - ee->pitch;
				if( Tilt1.roll != Missing ) Tilt1.roll = roll - ee->roll;
				Tilt1.azimuth = azimuth;

				/*************************
				READ 4017 DATA
				Update mean4017[] and stdev4017[]
				*************************/
				Read4017All(adcext1);    // 'D'

				/*************
				Wait for the arm to reach the horizon
				**************/
				while( StopWatchTime() < horizusec );
				HeaterOff(&HeaterFlag);  // Turn off during the sweep

				/*************
				Read a full block.
				**************/
				BlockSample(nsamps);  // "S.."

				/**************
				CHECK HEATER AND TURN ON NOW
				***************/
				if( HeaterCheck(ee->TempHeadMax, HeaterFlag) ) HeaterOn(&HeaterFlag);

				/****************
				// Tilt sample at end of the sweep
				****************/
				ReadPNI(&pitch, &roll, &azimuth);  // 'P'
				if( Tilt1.pitch != Missing ) Tilt2.pitch = pitch - ee->pitch;
				if( Tilt1.roll != Missing ) Tilt2.roll = roll - ee->roll;
				Tilt2.azimuth = azimuth;

				/*************************
				READ 4017 DATA
				*************************/
				Read4017All(adcext2);    // 'D'

				/*********************
				PROCESS THE SWEEP DATA
				**********************/
				ProcessSweep(nsamps);   // 'A'nalysis

				/*****************************
				 PACK DATA TO SEND
				******************************/
				PackBlock();  // 'B'

				/****************************
				Show heater temperature
				*****************************/
				TempHead=GetHeadTemp();

				/*****************************
				Send out the data file
				******************************/
				SendDataFile(0);  // 'T' Transmit

				/*****************************
				MODE CHECK -- LOW, TRANSITION, HIGH
				SET NEXT CYCLE START TIME
				*******************************/
				CheckMode(ee->FrsrState);	// check for high,low,transition modes
				if(RunMode == LOW)
				{
					// park the arm
					NadirCheck(&now);  MotorOff(&MotorPwrFlag);
				}
			}
			else
			{
				/**********************************
				NADIR SWITCH FAILS
				Revert to low mode sampling
				***********************************/
				RunMode = LOW;
			}
		}
		/*****************
		during standby mode routinely check the heater
		and read the 4017
		*****************/
		else // LOW MODE  if( RunMode == LOW )
		{
			/**************
			CHECK HEATER AND TURN ON NOW
			***************/
			if( HeaterCheck(ee->TempHeadMax, HeaterFlag) ) HeaterOn(&HeaterFlag);
			else HeaterOff(&HeaterFlag);
			TempHead=GetHeadTemp();
			sprintf(str," %.1f,",TempHead);
			SerPutStr(str);

			SweepTime = GetTime(SweepTime_string);
			cycleusecs = (ulong)DEFAULT_CYCLE * 1000;  //v401b
			StopWatchStart();
			while( StopWatchTime() < cycleusecs / 4 );

			// FIRST READ
			ReadPNI(&pitch, &roll, &azimuth);
			Tilt1.pitch = pitch - ee->pitch;
			Tilt1.roll = roll - ee->roll;
			Tilt1.azimuth = azimuth - ee->azimuth;
			Read4017All(adcext1);
			// WAIT FOR ONE-HALF THE CYCLE
			while( StopWatchTime() < cycleusecs * 3 / 4 );
			// SECOND READ
			ReadPNI(&pitch, &roll, &azimuth);
			Tilt2.pitch = pitch - ee->pitch;
			Tilt2.roll = roll - ee->roll;
			Read4017All(adcext2);
			// PREPARE AND SEND DATA
			PackBlock();
			SendDataFile(0);
			// MODE CHECK
			CheckMode(ee->FrsrState);
			if(RunMode==HIGH || RunMode == TRANSITION)
			{
				msec0 = 0; // initialize sweep computer
				NadirCheck(&now);
			}
			else while( StopWatchTime() < cycleusecs);
		}
	}
}


/***********************************************************************
		FUNCTION DEFINITIONS
***********************************************************************/


void BlockSample(int nsamps)
/*********************************
Take nsamps raw samples and store them.
Sample interval is SampMilliSecs
RMR 991101
************************************/
{
	int	i;
	int ic, idx; 		//simulate head
	ulong sampusec;
	double ddum;;

	ddum = (double)ee->CycleMilliSecs * 1000.0 / 2.0  / (double)nsamps;
	SampMicroSecs = (ulong)ddum;
	StopWatchStart();		// begin microsec clock

	// Read all sample
	if( !SimulateHeadFlag )
	{
		/***************
		Sweep sample - 250 samples over hemisphere
		******************/
		ReadSweep(adc12, NSAMPS, SampMicroSecs);
	}
	else
	{
		/*************
		Test - simulate the adc function
		***************/
		idx = 125;
		sampusec=StopWatchTime();
		for(i=0; i<nsamps; i++)
		{
			for( ic=0; ic<NCHANS; ic++)
			{
				if( i >= idx-10 && i < idx )
					adc12[i*nsamps+ic] = 20;
				else if( i == idx )
					adc12[i*nsamps+ic] = 10 + rand()/1000;
				else if( i > idx && i <= idx + 10 )
					adc12[i*nsamps+ic] = 30;
				else
					adc12[i*nsamps+ic] = 500 + ic * 500 + rand()/1000;
			}
			sampusec += SampMicroSecs;        	// increment to next samp time
			while( StopWatchTime() < sampusec );	// wait for sample time
		}
	}
	return;
}


void ProcessSweep(int nsamps)
/*********************************
Review the sweep, compute globals,
check for shadow and block avg.
RMR 991101
*********************************/
{
	double sum, sumsq;
	int i, i1, i2, npts, ic, isamps;
	int ib, ibk;
	float	adcmin;

	SerPutByte('A');

	// COMPUTE MEAN AND STD OF EACH CHANNEL -- MILLIVOLTS
	/***************************
	FIRST PASS
	SWEEP MEAN AND STDEV FOR EACH CHANNEL
	FIND MINIMUM VALUE IN CHANNEL 0 (OPTIONAL)
	****************************/
	adcmin = 32000.;
	idxMin = 0;

	// TEST -- print out one entire sweep
	/*
	for(i=0; i<250; i++)
	{
		if( i%12==0 ) printf("\n");
		printf("%4d ",adc12[i*NCHANS+ ee->MinChan]); // 3, 11, 19, ...
	}
	printf("\n");
	*/

	// FOR EACH CHANNELS
	for( ic=0; ic<NCHANS; ic++)
	{
		// SHADOW PRESENCE BASED ON A SINGLE CHANNEL
		if( ic == ee->MinChan )
		{
			// FIND MINIMUM VALUE
			for(i=0; i<nsamps; i++)
			{
				if( (float)adc12[i*NCHANS+ic] <= adcmin  ) // v402-take last min
				{
					adcmin = (float)adc12[i*NCHANS+ic];
					idxMin = i;
				}
			}

			sum = sumsq = 0;  // accumulators for each channel
			/*************************
			For SHADOW channel,
			compute the mean and stdev
			*************************/
			isamps = 0;
			for(i=0; i<nsamps; i++)
			{
				// EXCLUDE POINTS NEAR THE SHADOW  v302
				if( i < idxMin - 15 || i > idxMin + 15)
				{
					sum += (double)adc12[i*NCHANS+ic];
					sumsq += (double)adc12[i*NCHANS+ic] * (double)adc12[i*8+ic];
					isamps++;
				}
			}
			MeanStdev(&sum, &sumsq, isamps, 0);
			adcMean = sum;
			adcStd = sumsq;
		}

		/***********************
		GLOBAL VALUES - LEFT SIDE
		 -- typically NGLOBAL = 10
		************************/
		sum = 0;
		for(i=0; i<NGLOBAL; i++)
		{
			sum += (double)adc12[i*NCHANS+ic];
		}
		sum /= (double) NGLOBAL;
		globalSweep[0][ic] = (int) d_round(sum);

		/************************
		GLOBAL VALUES - RIGHT SIDE
		*************************/
		sum = 0;
		for(i=nsamps-NGLOBAL; i<nsamps; i++)
		{
			sum += (double) adc12[i*NCHANS+ic];
		}
		sum /= (double) NGLOBAL;
		globalSweep[1][ic] = (int) d_round(sum);
	}

	/******************************
	SHADOW RATIO:
	LOOK FOR A MINIMUM BELOW A SET AMOUNT BELOW MEAN
	Look only at channel 0 (global channel)
	*********************************/
	if( adcmin < 32000. && adcStd > 0 )
	{
		shadowratio = (adcMean - (double)adcmin) / adcStd;
		if( shadowratio < 0 ) shadowratio = 0;
	}
	else
		shadowratio = 0;

	// PRINT SHADOW RATIO
	sprintf(str,"sh%.1f/%.1f",shadowratio,ee->ShadowRatio);
	SerPutStr(str);

	//TEST printout
	/*
	ic= ee->MinChan;
	printf("idxMin=%d,   adcmin = %.1f,  adcMean = %.1lf,   adcStd = %.1lf\n",
		idxMin, adcmin, adcMean, adcStd);
	printf("shadowratio = %.2f\n",shadowratio);
	printf("Globals = %d,   %d\n",globalSweep[0][ic], globalSweep[1][ic]);
	*/
	/**********************************
	SECOND PASS
	SHADOW ANALYSIS
	IF A SHADOW, BLOCK AVERAGE COMPOSITE SWEEP
	************************************/
	if( shadowratio >= ee->ShadowRatio )   // v302, make >=
	{
		SerPutByte('+');

		/*****************************
		SHADOW STATS
		Each sweep and Composite
		*****************************/
		for(ic=0; ic<NCHANS; ic++)
		{
			/************************************
			ZERO BLOCK AVG BINS
			************************************/
			for(ib = 0; ib < 2 * NBLKS + 1; ib++)
				sweepBlk[ib][ic] = 0;

			/*****************************
			RIGHT SIDE BLOCK AVGS
			we accumulate all inst values for an overall avg
			*****************************/
			i2 = idxMin;
			for(ibk=0; ibk<NBLKS; ibk++)  // 0,1,...,10
			{
				// INDEX IN THE BLOCK ARRAY
				ib = NBLKS + ibk + 1; // 12,...22

				// SET SUMMATION LIMITS
				i1 = i2+1; // just to right of the shadow
				i2 = i1 + Nsz[ibk] - 1; // Nsz points in mean
				if( i2>= nsamps ) i2 = nsamps-1;  // do not overrun the array

				sum = 0;  npts=0;
				for(i=i1; i<=i2; i++)
				{
					sum += (double)adc12[i*NCHANS+ic];
					npts++;
				}
				sweepBlk[ib][ic] = (int) d_round(sum / (double)npts);
				if( i2 ==  nsamps-1 ) break;
			}

			/*****************************************
			LEFT SIDE BLOCK AVGS
			*****************************************/
			i1 = idxMin;
			for(ibk=0; ibk<NBLKS; ibk++)  // 0,1,...,10
			{
				// INDEX IN THE BLOCK ARRAY
				ib = NBLKS - ibk - 1; // 10,9,...,0

				// SET SUMMATION LIMITS -- from shadow to left
				i2 = i1 - 1;
				i1 = i2 - Nsz[ibk] + 1;
				if( i1 < 0 ) i1 = 0;

				sum = 0;  npts=0;
				for(i=i1; i<=i2; i++)
				{
					sum += (double)adc12[i*NCHANS+ic];
					npts++;
				}
				sweepBlk[ib][ic] = (int) d_round(sum / (double) npts);

				// IF AT THE END OF THE SWEEP, QUIT
				if( i1 ==  0 ) break;
			}

			/**********************************
			MINIMUM VALUES AT THE MIN INDEX
			***********************************/
			sweepBlk[NBLKS][ic] = adc12[idxMin*NCHANS+ic];  // single min at block 11

		}
		// TEST PRINT OUT BLOCKS
		/*
		for(i=0; i<23; i++)
		{
			if(i%12 == 0) printf("\n");
			printf("%4d ", sweepBlk[i][ee->MinChan]);
		}
		printf("\n");
		*/
	}
	else
	{
		SerPutByte('-');
	}
	return;
}

void CheckMode(ushort frsrstate)
/**********************************
Check the PSP reading.
The low cutoff set by ee->Low (in millivolts)
RMR 991101
**********************************/
{
	static time_t modetime;
	int		adc;

	// READ FRSR HEAD CHAN 1
	ReadAnalog(0,&adc,0);

	// SET TO LOW MODE IF FORCED BY FRSRSTATE VARIABLE
	if( frsrstate == OFF )
		SetMode(LOW);
	// HIGH MODE IF FRSR ABOVE THRESHOLD
	else if( adc >= ee->Low )
	{
		if( RunMode != HIGH )	SetMode(HIGH);
	}
	// BELOW THRESHOLD
	else
	{
		// TRANSITION MODE, CHECK TIME
		if( RunMode == TRANSITION && difftime(time(NULL), modetime) > 0 )
			SetMode(LOW);
		if( RunMode == HIGH )
		{
			modetime = time(NULL) + ee->TransitionTime;
			SetMode(TRANSITION);
		}
	}
	return;
}


void SetMode(int mode)
/*****************************
Puts the system in the correct state for a particular mode
mode=-1 -- test, standby park the arm and go to low power mode
RMR 991101
*****************************/
{
	time_t now;
	RunMode = mode; // set global variable RunMode to control all operations

	// ANY DETAILS RELATED TO THIS MODE
	switch (mode)
	{
		// TEST MODE
		case TEST:
			sprintf(str,"-Stby-");
			SerPutStr(str);
			NadirCheck(&now);
			MotorOff(&MotorPwrFlag);
			//testtime = time(NULL);  // set start test time
			break;

		// LOW MODE
		case LOW:
			sprintf(str,"-Low-");
			SerPutStr(str);
			break;

		// TRANSITION MODE
		case TRANSITION:
			sprintf(str,"-Trans-");
			SerPutStr(str);
			break;

		// HIGH MODE
		case HIGH:
			sprintf(str,"-High-");
			SerPutStr(str);
			break;

		default:
			printf("Bad input to SetMode()\n");
	}
	return;
}


/*******************
EEPROM FUNCTIONS
eepromeeprom
********************/

int StoreUee(struct eeprom *pu)
/**********************************************
Determines the size of the structure and stores it entirely
in eeprom space
991101
***********************************************/
{
	ushort i, location;
	uchar *ptst;

	location = MEMSTART;
	ptst = (uchar*)pu;
	printf("StoreUee...\n");

	if(PrintFlag) printf("Store Uee variables\n");
	location = MEMSTART;

	for(i=0; i < sizeof(struct eeprom); i++)
	{
		UeeWriteByte(location++, *ptst );  // get the byte
		ptst = ptst+1;
	}

	return;
}


void ReadUee(struct eeprom *pu)
/**********************************************
991101
**********************************************/
{
	ushort	i,location;
	uchar *ptst;

	location = MEMSTART;
	ptst = (uchar*)pu;

	printf("ReadUee:\n");
	for(i=0; i < sizeof(struct eeprom); i++)
	{
		UeeReadByte(location++, ptst++ );  // get the byte
	}


	/**************
	SEPARATE THE FLAGS
	***************/
	NadirDisable = ee->ConfigFlag & 0x2;
	PrintSweep = ee->ConfigFlag & 0x4;
	BinaryBlock = ee->ConfigFlag & 0x8;
	SimulateHeadFlag = ee->ConfigFlag & 0x10;

	return;
}

void PrintUee(struct eeprom *ep)
/****************************************
Print out the eeprom structure
991101
*****************************************/
{
	printf("PrintUee: \n"
			 "  id = %d\n"
			 "  FrsrState = %d\n"
			 "  CycleMilliSecs = %ld\n"
			 "  TempHeadMax = %.2f\n"
			 "  pitch/roll = %.1f/%.1f\n"
			 "  ShadowRatio = %.1f\n"
			 "  Low = %d mv"
			 "  Trans_time = %d sec\n"
			 "  Minimum Channel = %d\n"
			 ,ep->id, ep->FrsrState, ep->CycleMilliSecs,
			 ep->TempHeadMax, ep->pitch, ep->roll, ep->ShadowRatio,
			 ep->Low, ep->TransitionTime, ep->MinChan);
	printf(  "  ConfigFlag = %04x\n"
			 "     NadirDisable = %d\n"
			 "     PrintSweep = %d\n"
			 "     BinaryBlock = %d\n"
			 "     SimulateHeadFlag = %d\n"
			 , ee->ConfigFlag, NadirDisable, PrintSweep, BinaryBlock,
			 SimulateHeadFlag);

	return;
}

/**********************
DATA PROCESSING FUNCTIONS
datadata
***********************/

void PackBlock( void)
/**************************************************
Pack the sweep by sweep data into a character block
991117
***************************************************/
{
	unsigned long	ulng;
	int	ib, ic;
	char str[4];

	if(RunMode == HIGH || RunMode == TRANSITION)
	{
		//Place a marker to signify daytime record
		datafile[0] = 'H';
	}
	else
	{
		//Place a marker to signify LOW
		datafile[0] = 'L';
	}
		df_index = 1;

	/*****************************
	BASIC DATA SET -- FOR EACH SWEEP REGARDLESS OF SHADOW
	*******************************/
	// Sweep Time -- unsigned long - 4 bytes
	
	//PackBytes(SweepTime,4,0);
	// Head Temperature - 2 bytes
	ulng = (TempHead + 20) * 10 + 0.5;
	PsuedoAscii( ulng, 2);
	//printf("Thead = %.1f,  ulng = %ld,  psuedoascii=%s\n", TempHead, ulng, str);
	
	// pitch roll and globals, both sides -- angles are int theta*100
	// theta = (number-9000)/100;
	// PNI
	if( Tilt1.pitch == Missing ) ulng = 0;
	else ulng = (int)(Tilt1.pitch+40) *50;
	PsuedoAscii( ulng, 2);
	if( Tilt1.roll == Missing ) ulng = 0;
	else ulng = (int)(Tilt1.roll+40) * 50;
	PsuedoAscii( ulng, 2);
	if( Tilt1.azimuth == Missing ) ulng = Missing;
	else ulng = (int)(10*Tilt1.azimuth);
	PsuedoAscii( ulng, 2);
	//4017 CHANNELS - (i+500)*100 => unsigned int 0--100000 - 3 bytes
	for(ic=0; ic<8; ic++)
	{
		if( adcext1[ic] < -500) ulng = 0;
		else ulng = (adcext1[ic] + 500 ) * 100;
		PsuedoAscii( ulng, 3);
	}
	
	// PNI READING
	if( Tilt2.pitch == Missing ) ulng = 0;
	else ulng = (int)(Tilt2.pitch+40) *50;
	PsuedoAscii( ulng, 2);
	if( Tilt2.roll == Missing ) ulng = 0;
	else ulng = (int)(Tilt2.roll+40) * 50;
	PsuedoAscii( ulng, 2);
	if( Tilt2.azimuth == Missing ) ulng = Missing;
	else ulng = (int)(10*Tilt2.azimuth);
	PsuedoAscii( ulng, 2);
	//4017 CHANNELS - (i+500)*100 => unsigned int 0--100000
	for(ic=0; ic<8; ic++)
	{
		if(adcext2[ic] < -500 ) ulng = 0;
		else ulng = (adcext2[ic] + 500 ) * 100;
		//printf("adc=%.4f,  ulng=%ld\n", adcext2[ic], ulng);
		PsuedoAscii( ulng, 3);
	}

	/**********************
	// HIGH MODE DATA
	************************/
	if(RunMode == HIGH || RunMode == TRANSITION)
	{
		//shadowratio 2 bytes
		ulng = shadowratio*10.0;  // v302, truncate rather than round off
		if(ulng > 32000 ) ulng = 32000;  // v303, no overflow
		PsuedoAscii( ulng, 2);

		// Threshold shadow ratio - 2 bytes
		ulng = ee->ShadowRatio*10;   // v302, truncate rather than round off
		PsuedoAscii( ulng, 2);

		// GLOBAL VALUES - 2 bytes
		for(ic=0; ic<7; ic++) 
			PsuedoAscii( globalSweep[0][ic], 2);

		// GLOBAL SWEEP VALUES
		for(ic=0; ic<7; ic++) 
			PsuedoAscii( globalSweep[1][ic], 2);

		/******************************
		SHADOW DATA -- DO THIS ONLY FOR SHADOW SWEEPS
		******************************/
		if( shadowratio >= ee->ShadowRatio )   // v302 make >=
		{
			for(ic=0; ic< 7; ic++)
			{
				for(ib=0; ib< NBLKS*2 + 1; ib++)
					//PackBytes(sweepBlk[ib][ic], 2, 0);
					PsuedoAscii( sweepBlk[ib][ic], 2);
			}
		}
	}

	// TERMINATE DATA FILE STRING
	datafile[df_index] = '\0';

	// TEST
	/*
	ic=df_index;
	printf("datafile length = %d\n", df_index);
	for(ib=0; ib< df_index; ib++)
	{
		if(ib%20==0) printf("\n");
		printf("%3d ",datafile[ib]);
	}
	*/
	return;
}



void PsuedoAscii(unsigned long ul, unsigned int nc)
/************************************
v15 delete PackBytes() which is binary.
df_index is the pointer to the datafile[df_index] string.
c1 = x % 64 +48; lsb
c2 = int(x/64) % 64 + 48;
example:  x = 1055
c1 = 79 => O
c2 = 64 => @
ASCII output = @O
*************************************/
{
	unsigned int  n;
	unsigned long u1;
	char asc[6];
	
	// clip to the defined range
	u1 = pow((double)64, (double)nc) - 1;
	if( ul > u1 ) ul = u1;
	if( ul < 0 ) ul = 0;
	
	// pseudo ascii conversion
	n=1;
	u1 = ul;
	while( n < nc ) {
		datafile[df_index] = u1 % 64 + 48;	// put the character into the datafile
		df_index++;							// increment the pointer
		u1 = u1/64;							// divide and convert to integer
		n++;								// increment the character number
	}
	// Last character
	datafile[df_index] = u1 % 64 + 48;
	df_index++;
	return;
}


void	SendDataFile(unsigned prt)
/*******************************
Send out the data file as a packet
datafile[] contains the block string
df_index = number of points in the data buffer
991101
********************************/
{
	int i;
	unsigned chksum, slen, b1, b2, b3;  // 16 bit number
	char c1, c2, c3;
	unsigned long len;
	
	/******************
	Compute the CRC checksum
	*******************/
	chksum = (unsigned) CheckSum( (char*)datafile, (unsigned long) df_index);
	/*****************
	send out the checksum as four bytes
	******************/
	b1 = chksum; 
	c1 = b1 % 64 + 48;  	// msb
	b2 = b1 / 64;
	c2 = b2 % 64 + 48;			// 
	b3 = b2 / 64;
	c3 = b3 % 64 + 48;			// lsb
	if(prt) printf(" checksum %d, ascii: %d, %d, %d,  chars: %c, %c, %c\n", 
		chksum, b1, b2, b3, c1,c2,c3);
	
	// PRINT OUT THE STRING
	printf("##%04d,%s*%c%c%c##\r\n",df_index,datafile,c1,c2,c3);
	
	return;
}


long CheckSum(char *packet, unsigned long N)
/*****************************************************
CheckSum() --
	Routine to compute checksum based on a shifting summation of all
	bytes.  Routine provided by L. Hatfield of Battelle, 9404.
	See Reynolds notes, pp 1207-1208.			940505
	Modified for binary blocks of size N.		990108
*******************************************************/
{
	long    		nbyte;
	long			sum;
	char			chr;

	nbyte = 0;  sum=0;

	// COMPUTE SHIFTED CHECKSUM
	while(nbyte < N)
	{
		chr = packet[nbyte];
		nbyte++;
		if(sum & 01)	sum = (sum>>1) + 0x8000;
		else 			sum >>= 1;

		sum += chr;
		sum &= 0xFFFF;	// truncate to 16 bits
	}

	return sum;
}



/***********************
IO FUNCTIONS
ioio
*************************/

// void	SendDataFile(void)
// /*******************************
// Send out the data file as a packet
// datafile[] contains the block string
// df_index = number of points in the data buffer
// 991101
// ********************************/
// {
// 	int i;
// 	unsigned chksum, slen;  // 16 bit number
// 	char b;
// 
// 	// HEADER STRING
// 	sprintf(str,"\n<<%04d,",df_index);
// 
// 	/******************
// 	Compute the CRC checksum
// 	*******************/
// 	chksum = (unsigned) CheckSum( (char*)datafile, (unsigned long) df_index);
// 
// 	/****************
// 	send out the header string
// 	*****************/
// 	for(i=0; i<strlen(str); i++) SerPutByte(str[i]);
// 
// 	/*****************
// 	send out the data  bytes
// 	******************/
// 	for( i=0; i<df_index; i++)
// 		SerPutByte( datafile[i] );
// 
// 	/*****************
// 	send out the checksum as two bytes
// 	******************/
// 	b = chksum/256; SerPutByte(b);  // msb
// 	b = chksum%256; SerPutByte(b);	// LSB
// 
// 	/****************
// 	send out the end >>
// 	*****************/
// 	sprintf(str,">>\n");
// 	for(i=0; i<strlen(str); i++) SerPutByte(str[i]);
// 
// 	return;
// }

void PrintBlockTest(void)
/********************************
Test function -- print out the results from a single block
*********************************/
{
	int i,ix;

	for(i=0; i<nsamps; i++)
	{
		ix=i*8;
		printf("%3d %4d %4d %4d %4d  %4d %4d %4d %4d\n",i,
		adc12[ix], adc12[ix+1], adc12[ix+2], adc12[ix+3],
		adc12[ix+4], adc12[ix+5], adc12[ix+6], adc12[ix+7]);
	}
	printf("Statistics:\n");
	printf("MN  %5d\n", (int)d_round (adcMean));
	printf("STD %5d \n", (int)d_round (adcStd));
	// print shadow stats
	printf("MIN %4d %4d %4d %4d  %4d %4d %4d %4d\n",
		adcMin[0], adcMin[1], adcMin[2], adcMin[3],
		adcMin[4], adcMin[5], adcMin[6], adcMin[7]);

	printf("MIN INDEX:  %d\n",idxMin);
	printf("Shadow ratio: %.4f\n",shadowratio);
	return;
}

/***********************************
OPERATIONAL FUNCTIONS
actionaction
************************************/

void	Action(char *cmd)
/*****************************************************************
	Read message and take action.
	Create an output packet in out_buffer and send;
	input:
		in_buffer = pointer to a message string
		in_fromlist = char string, e.g. "121115"
			meaning the message came from 12 in the route 15->11->12
		RMR 991101
******************************************************************/
{
	char	chr;
	int	i;	// pointer to input message
	int j;  // pointer to command string
	int len;// length of input message
	float	fdum, fdum1; // dummy float
	double  ddum[8], ddumsq[8];
	int		idum;
	unsigned	udum;
	char	s[64], r[16];
	ulong	msec1,msec2, HorizUsec;
	time_t	now;
	struct tm *t;


	t = (struct tm*)calloc(1, sizeof(struct tm));

	len = strlen(cmd);


	// TAKE ACTION AND PREPARE AN OUTPUT MESSAGE IN out_message
	switch(*cmd)
	{

	   //	menumenu
		case '?':
			GetTime(time_string);
			printf("\nOPTIONS -- %s,   ver:%s, %s\n",
				time_string,VERSION, EDITDATE);
			printf(
				 "-------  ANALOG TESTS ---------------------------\n"
				 " A -- 12-bit ADC test loop\n"
				 " N -- 18-bit ADC test loop\n"
				 "------- FRSR TESTS ------------------------------\n"
				 " M -- motor on/off\n"
				 " B -- Block Sample\n"
				 " Hf.ff -- heater f.ff secs, 0=warm up\n"
				 "------- EEPROM -----------------------------------\n"
				 " E -- show eeprom\n"
				 " ELnn -- low thshld (mv)   EWnn -- Transition wait secs\n"
				 " ETff.f -- set head temp,  ESf.ff -- shadow ratio\n"
				 " EFxxxx -- config hex switch, hex 4-digits\n"
				 " EMx -- set the min channel (1-7 only)\n"
				 "------- PITCH, ROLL, COMPASS, CLOCK ---------------\n"
				 " T-PNI, TR-read loop, TC<str>-send a cmd, TS-setup PNI\n"
				 " U-read clock,        UyyyyMMddhhmmss-set clock\n"
				 "------- OPERATION COMMANDS ------------------------\n"
				 " L -- LOW, toggle FRSR Standby/Normal Operation\n"
				 " G -- GO : continue operation\n"
				 );
			break;

		case 'a':
		case 'A':
			printf("Read 12bit ADC\n");
			SampleADC();
			break;

		case 'N':
		case 'n':
			printf("Read 18bit Ext ADC\n");
			SampleADCExt();
			break;

		case 'B':
		case 'b':
			printf("Block sample...\n");
			ddum[0]=ddum[1]=ddum[2]=ddum[3]=ddum[4]=ddum[5]=ddum[6]=ddum[7]=0;
			ddumsq[0]=ddumsq[1]=ddumsq[2]=ddumsq[3]=ddumsq[4]=ddumsq[5]=ddumsq[6]=ddumsq[7]=0;
			MotorOn(&MotorPwrFlag);
			NadirCheck(&now); ComputePeriod();	// Find nadir and set timer
			NadirCheck(&now); idum=ComputePeriod(); // get sweep time
			// timing computations
			msec1 = (ulong)idum*2;  // sample rate in microsecs
			printf("Sample rate = %ld microsecs\n", msec1);
			// wait for first horiz
			StopWatchStart();
			while( StopWatchTime() < (ulong)idum*1000/4 );
			// read 250 samps from each channel
			ReadSweep(adc12, 250, msec1);
			NadirCheck(&now); MotorOff(&MotorPwrFlag);
			// PRINT OUT THE SWEEP
			for(i=0; i<250; i++)
			{
				printf("%3d ",i);
				for(j=0; j<8; j++)
				{
					ddum[j] += (double)*(adc12 + i*8 + j);
					ddumsq[j] += (double)*(adc12 + i*8 + j) * (double)*(adc12 + i*8 + j);
					printf("%4d ",*(adc12 + i*8 + j) );
				}
				printf("\n");
			}
			printf("MN: ");
			for(i=0; i<8; i++)
			{
				MeanStdev(&ddum[i], &ddumsq[i], 250, (double)Missing);
				printf("%6.1lf ",ddum[i]);
			}
			printf("\n");
			printf("STD:");
			for(i=0; i<8; i++)
			{
				printf("%6.1f ", ddumsq[i]);
			}
			printf("\n");
			break;

		// EEPROM SET
		case 'E':
		case 'e':
			switch( cmd[1] )
			{
				case 'm':
				case 'M':
					udum = 0;
					sscanf(cmd,"%*c%*c%d", &udum);
					printf("Chan for sweep min = %d\n",udum);
					if(udum>7 || udum < 1)
						printf("Error, must be 1--7.\n");
					else
						ee->MinChan = udum;
					chr = 'Y';
					break;

				case 'l':
				case 'L':
					udum = 0;
					chr = 'Y';
					sscanf(cmd,"%*c%*c%d", &udum);
					ee->Low = udum;
					break;
				case 'w':
				case 'W':
					udum = 0;
					sscanf(cmd,"%*c%*c%d", &udum);
					printf("Transition wait secs = %d secs\n",udum);
					ee->TransitionTime = udum;
					chr = 'Y';
					break;

				case 't':
				case 'T':
					fdum = 0;
					sscanf(cmd,"%*c%*c%f",&fdum);
					printf("Head temp from %.2f to %.2f, (y)es-(n)o ?\n",
						ee->TempHeadMax, fdum);
					chr = SerGetByte();
					if( chr == 'y' || chr == 'Y') ee->TempHeadMax = fdum;
					break;

				// SET SHADOW LIMIT
				case 's':
				case 'S':
					fdum = 0;
					sscanf(cmd,"%*c%*c%f",&fdum);
					fdum = (int)(fdum*10) / 10.0;  // v302, only to tenths
					printf("Shadow limit from %.1f to %.1f, (y)es-(n)o ?\n",
						ee->ShadowRatio, fdum);
					chr = SerGetByte();
					if( chr == 'y' || chr == 'Y') ee->ShadowRatio = fdum;
					break;

				// SET CONFIGURATION FLAG
				case 'f':
				case 'F':
					udum = 0;
					sscanf(cmd,"%*c%*c%x",&udum);
					printf("ConfigFlag from %04X to %04X hex, (y)es-(n)o ?\n",
						ee->ConfigFlag, udum);
					chr = SerGetByte();
					if( chr == 'y' || chr == 'Y') ee->ConfigFlag = udum;
					break;

				default:
					chr = 'n';
					PrintUee(ee);
					break;
			}
			if(chr == 'y' || chr == 'Y')
			{
				StoreUee(ee);
				ReadUee(ee);
				PrintUee(ee);
			}
			break;


		case 'M':
		case 'm':
			puts("Motor operation");
			MotorOn(&MotorPwrFlag);
			/*********
			nadir switch time-- wait for nadir off then
			wait for nadir and report time each time
			**********/
			NadirCheck(&now);  //first nadir check
			idum = ComputePeriod();
			while( !SerByteAvail() )
			{
				NadirCheck(&now);  // defines NadirTime
				idum = ComputePeriod();
			}
			MotorOff(&MotorPwrFlag);
			break;


		case 'P':
		case 'p':
			if( PrintFlag == YES ) PrintFlag = NO;
			else PrintFlag = YES;
			printf("PrintFlag = %d\n",PrintFlag);
			break;

		case 'H':
		case 'h':
			TempHead=GetHeadTemp();
			fdum = 0;
			sscanf(cmd,"%*c%f",&fdum);
			printf("Head Temp: %.2f  Threshold: %.2f\n", TempHead, ee->TempHeadMax);

			/********************
			Heater loop, this will bring the head to a set temp
			and maintain it at that temp
			**********************/
			if( fdum == 0.0 )
			{
				/************************
				Heater Check - pause to bring the heater up to temp
				*************************/
				while( !SerByteAvail() )
				{
					HeartBeat();
					if( HeaterCheck(ee->TempHeadMax, HeaterFlag) )
					{
						HeaterPulse(5000);
					}
					else
					{
						//printf("Heater standby: TempHead = %.2f C\n",TempHead);
						HeaterOff(&HeaterFlag);
						DelayMilliSecs(5000);
					}
				}
			}
			else if( fdum < 0 || fdum > 10 )
			{
				printf("   no. secs incorrect, abort command\n");
			}
			else
			{
				idum = fdum * 1000;  // convert to millisecs 1--10000
				HeaterPulse(idum);
			}
			break;

		case 'l':
		case 'L':
			if( ee->FrsrState == OFF )
			{
				printf("Turn FRSR operation ON\n");
				ee->FrsrState = ON;
			}
			else
			{
				printf("Turn FRSR operation OFF\n");
				ee->FrsrState = OFF;
			}
			StoreUee(ee);
			break;

		case 'g':
		case 'G':
			printf("Continue operation\n");
			SetMode(HIGH);
			PrintFlag = NO;
			break;

		case 'U':
		case 'u':
			if( len == 1 )
			{
				ShowTime();
			}
			else if( len == 15 )
			{
				sscanf(in_buffer,"%*c%4d%2d%2d%2d%2d%2d",
					&udum, &t->tm_mon,&t->tm_mday,
					&t->tm_hour,&t->tm_min,&t->tm_sec);
				t->tm_mon--;  // mons 0-11
				t->tm_year = udum-1900;

				SetTimeTM(t, NULL);
				ShowTime();
			}
			else
			{
				printf("RTC does NOT work in this unit\n");
			}

			break;

		/*******************
		PNI operation
		*********************/
		case 'T':
		case 't':

			/*****************
			Second letter defines action
			******************/
			switch (*(cmd+1))
			{
				/*************
				Read a data record, continuous loop
				Stop after key press or 60 samples
				***************/
				case 'R':
				case 'r':
					i = 0;
					while( i < 60 && !SerByteAvail() )
					{
						i++;
						ReadPNI(&pitch, &roll, &azimuth);
						if(pitch != Missing) pitch -= ee->pitch;
						if(roll != Missing ) roll -= ee->roll;
						printf("pitch=%.1f,  roll=%.1f,  azimuth = %.1f\n",
							pitch, roll, azimuth);
						DelayMilliSecs(1000);
					}
					break;

				/*****************
				Send a command to the PNI and wait for
				a reply.  Wait only 2 sec then jump out.
				******************/
				case 'C':
				case 'c':
					SerPutStr("Enter string: ");
					scanf("%s", s);
					printf("Sending PNI string: %s\n",str);

					PniCommand(s, r);
					printf("reply=%s\n",r);
					break;

				/***************
				ZERO TILT VALUES
				****************/
				case 'Z':
				case 'z':
					printf("Enter password: ");
					gets(s);
					if (strcmp(s,"bnl") == 0)
					{
						ReadPNI(&pitch, &roll, &azimuth);
						ee->pitch = pitch;  ee->roll = roll;
						StoreUee(ee);
						printf("Set ref pitch, roll: %.1f,  %.1f\n",
						ee->pitch, ee->roll);
					}
					break;

				/******************
				SETUP PNI FOR OPERATION
				******************/
				case 's':
				case 'S':
					strcpy(cmd,"fast=d");
					PniCommand(cmd,r);
					printf("reply=%s\n",r);

					strcpy(cmd,"clock=10");
					PniCommand(cmd,r);
					printf("reply=%s\n",r);

					strcpy(cmd,"damping=d");
					PniCommand(cmd,r);
					printf("reply=%s\n",r);

					strcpy(cmd,"sp=1");
					PniCommand(cmd,r);
					printf("reply=%s\n",r);

					strcpy(cmd,"sp=1");
					PniCommand(cmd,r);
					printf("reply=%s\n",r);

					break;

			}
			break;

		case 'X':
		case 'x':
			ResetToMon();
			break;

		default: break;
	}
	SerInFlush();
	return;
}

