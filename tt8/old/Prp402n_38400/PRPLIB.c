// Version 2  --  
//110110--remove ALL RTC functions and software.

//EDITDATE = 000112
// INCLUDES
#include <time.h>
#include <tt8.h>
#include <tat332.h>
#include <sim332.h>
#include <qsm332.h>
#include <tpu332.h>
#include <tpudef.h>
#include <dio332.h>
#include <tt8pic.h>
#include <tt8lib.h>
#include <stdio.h>
#include <stdlib.h>
#include <userio.h>
#include <math.h>
#include <string.h>

/**********************
DEFINES
************************/
// FLAG STATES
#define OK 1
#define NOTOK 0
#define ON 1
#define OFF 0
//485 PORTS  485485
#define	RX485	2		//TPU2 for 485 (RX)
#define	TX485	5		//TPU5 for 485 (TX)
#define		RX485WAIT	100  // millisecs wait
#define		BITDELAY 11900
// PNI DEFINES  pnipni
#define RXPNI 14        //PNI RX
#define TXPNI 13       //PNI TX
#define	PNIWAIT 200 // = timeout in msec
#define PNISTRLEN 400 // = chars set aside for pni strings
// PRP HEAD TEMP CALIBRATION
#define A1 -3.4868183734e-7
#define A2 -8.9323216739e-6
#define A3 -3.308255931317e-4
#define A4 7.92320546465e-4


/***************
PROTOTYPES
protoproto
****************/
int		Startup(void);
void    HeartBeat(void);
int		SerPutStr(char *);
time_t  GetTime(char *);
time_t  ShowTime(void);
void 	SetDateTime(void);
void	TimeString(struct tm *, time_t *, char*);
// ANALOG --  analoganalog
int		ReadAnalog(int chan, int *, int missing);  // 1 or 8 channels
void	ReadSweep(int *adc, int npts, ulong usecs);
void	SampleADC(void); // test the 12bit adc circuit
// MATH mathmath
double 	d_round(double x);
void	MeanStdev(double*, double*, int, double);
// SHADOWBAND AND MOTOR --  motormotor
void	MotorOff(int*);
void	MotorOn(int*);
ulong	ComputePeriod(void);
int		NadirCheck(time_t *);	// wait for arm to reach nadir
// 485 PROTOS      485485
int		Read4017All(double *); // read all 8 chans into float[0-7]
int  	Read4017(int , double *);  // read one channel of the 4017
int 	RS_485(char*, char*, unsigned);  // general 485 function
// PNI PROTOS    pnipni
void	ReadPNI(float*, float*, float*); // pitch, roll, az in degrees
unsigned PniSendStr( char*); // send a string to the PNI tilt sensor
unsigned PniGetStr( char*);  // receive a string from PNI
void	PniCommand( char*, char *);  // send a command to the PNI
// HEATER AND HEAD TEMP
int		HeaterCheck(float, int);
void	HeaterPulse(int);
void	HeaterOn(int*);
void	HeaterOff(int*);
float	GetHeadTemp(void);  // returns temperature in degC



/*******************
GLOBAL VARIABLES -- globalglobal
*******************/
extern int		MotorPwrFlag;
extern	int		NadirDisable;
extern int		Missing;
// TIME VARIABLES timetime
qsmdum[5];


/*******************
THE FUNCTIONS
********************/

/**********************
MOTOR AND SHADOWBAND FUNCTIONS -- motormotor
***********************/

void MotorOn (int *MotorPwrFlag)
/*********************************************************
Turn on Switch Power B for motor
991101
************************************************************/
{
	if( *MotorPwrFlag == OFF)
	{
		SerPutByte('M');
		PSet(E,1);
		*MotorPwrFlag = ON;
	}
	return;
}

void MotorOff (int *MotorPwrFlag)
/*************************************************************
Turn off Switch Power B, the motor
991101
**************************************************************/
{
	if( *MotorPwrFlag == ON )
	{
		SerPutByte('m');
		PClear(E,1);
		*MotorPwrFlag = OFF;
	}
	return;
}

int NadirCheck(time_t *NadirTime )
/**********************************
If the motor is off, then just jump out.
If the motor is on, then
	first: wait for the switch to open, then
	second: wait for the switch to close
	third: return

Ver 301 -- note nadir logic is reversed for the new boards DL99
RMR 991101
**********************************/
{
#define	TPU_NADIR		7	// in - reed relay input
#define NADIRWAITTIME 8000000 // MICROSECS wait after starting motor
#define NADIRDELAY	1

	SerPutByte('N');

	/********************
	Wait for the
	nadir switch to close.  Use a timeout
	to ensure the arm is turning and the
	switch is functional
	**********************/
	if( MotorPwrFlag == ON)
	{
		/**************
		Normal operation
		***************/
		if( !NadirDisable )
		{
			StopWatchStart();
			// If the switch is currently closed, complete a full cycle
			if( !TPUGetPin(TPU_NADIR) )
			{
				SerPutByte('c');
				while( !TPUGetPin(TPU_NADIR))
				{
					if( StopWatchTime() > (ulong)NADIRWAITTIME )
					{
						//printf("No nadir switch -- break\n");
						SerPutByte('x');
						//HeaterOff(); // safety turn off the heater if the motor fails
						return NOTOK;
					}
				} // be sure you are out of nadir region
				SerPutByte('o');
			}

			// START TIMER -- the arm is at the beginning of nadir sector
			while( TPUGetPin(TPU_NADIR) )
			{
				// No nadir switch -- error
				if( StopWatchTime() > (ulong)NADIRWAITTIME )
				{
					//printf("No nadir switch -- break\n");
					SerPutByte('x');
					//HeaterOff(); // safety turn off the heater if the motor fails
					return NOTOK;
				}
			}
		}
		else
		{
			//printf("Test nadir routine\n");
			SerPutStr("tst");
			DelayMilliSecs(6800);
		}
		/******************
		The arm may already be in its nadir position.
		We check for this situation and update the
		timer only if this is a new nadir position.
		 *******************/
		DelayMilliSecs(NADIRDELAY);  // adjust for true bottom
		*NadirTime = time(NULL);
		SerPutByte('+');
		return OK;
	}
	else
	{
			//SerPutStr("motoroff");
			return OK;
	}
}

ulong ComputePeriod(void)
/**********************************
Use consecutive nadir transitions
to compute cycle time.
RMR 000715
**********************************/
{
	static unsigned	msec0;    // remember the last time
	unsigned 		msec, sweep_msec, l1, l2;  // the
	unsigned 		msec_default; // default cycle period
	char			str[10];


	msec_default = 6200;  // msec default cycle number
	l1 = 5900;  l2 = 6900;

	msec = TensMilliSecs();  // note time in 100 Hz counts

	if(msec0 == 0 )
		sweep_msec = msec_default;
	else
	{
		sweep_msec = 10 * (msec - msec0);
		sprintf(str," %d",sweep_msec); SerPutStr(str);
		if( sweep_msec > l2 || sweep_msec < l1 )
		{
			sprintf(str,"x "); SerPutStr(str);
			sweep_msec = msec_default;
		}
		else
		{
			sprintf(str," "); SerPutStr(str);
		}
	}
	msec0=msec;
	return (sweep_msec);
}



/*********************
MATH FUNCTIONS -- mathmath
**********************/

double d_round(double x)
/***********************************/
{
	return( (x>0) ? floor(x+0.5) : -floor(-x+0.5) );
}



void	MeanStdev(double *sum, double *sum2, int N, double missing)
/********************************************
Compute mean and standard deviation from
the count, the sum and the sum of squares.
991101
*********************************************/
{
	if( N <= 2 )
	{
		*sum = missing;
		*sum2 = missing;
	}
	else
	{
		*sum /= (double)N;		// mean value
		*sum2 = *sum2/(double)N - (*sum * *sum); // sumsq/N - mean^2
		*sum2 = *sum2 * (double)N / (double)(N-1); // (N/N-1) correction
		if( *sum2 < 0 ) *sum2 = 0;
		else *sum2 = sqrt(*sum2);
	}
	return;
}



/****************************
12-BIT ANALOG FUNCTIONS
******************************/
void	ReadSweep(int *adc, int npts, ulong usecs)
/*********************************************************
Read npts at a sample rate of usecs microsecs.
Fill the array adcarray.
The array is grouped into blocks of 8 chans for each sample
i.e. 0,0,0,0,0,0,0,0   1,1,1,1,1,1,1,1   2,2,2,2,2,2,2,2 ... (npts-1),(npts-1),...
***********************************************************/
{
	int i;
	ulong udum;

	SerPutStr("S..");
	// initialize the times
	StopWatchStart();
	udum = StopWatchTime();

	for(i=0; i<npts; i++)
	{
		ReadAnalog(8, (adc+i*8), Missing); // read all adc chans and store in adc[]
		udum += usecs;        	// increment to next samp time
		while( StopWatchTime() < udum );	// wait for sample time
	}
	return;
}


int ReadAnalog(int chan, int *f, int missing)
/*****************************************************
Read all channels of the analog-to-digital circuits at once
Data is placed into float location f.
RMR 000305
******************************************************/
{
	int i;
	// SINGLE CHANNEL OPERATION
	if( chan > 7 )
	{
		for(i=0; i<8; i++)
		{
			*(f+i) = AtoDReadMilliVolts(i);
		}
		return OK;
	}
	// ALL EIGHT CHANNELS
	else if( chan >= 0 && chan <= 7 )
	{
		*f =  AtoDReadMilliVolts(chan);
		return OK;
	}
	else
	{
		*f = missing;
		return OK;
	}
}

void SampleADC(void)
/********************************************************
Test the ADC circuit
**********************************************************/
{
	double ddum[8], ddumsq[8];
	int i, npts, adc12[8];

	ddum[0]=ddum[1]=ddum[2]=ddum[3]=ddum[4]=ddum[5]=ddum[6]=ddum[7]=0;
	ddumsq[0]=ddumsq[1]=ddumsq[2]=ddumsq[3]=ddumsq[4]=ddumsq[5]=ddumsq[6]=ddumsq[7]=0;
	npts=0;
	while( !SerByteAvail() )
	{
		ReadAnalog(8,adc12, Missing);
		printf("%7d %7d %7d %7d %7d %7d %7d %7d\n",
		adc12[0],adc12[1],adc12[2],adc12[3],
		adc12[4],adc12[5],adc12[6],adc12[7]);
		for(i=0; i<8; i++)
		{
			ddum[i] += (double)adc12[i];
			ddumsq[i] += (double)adc12[i] * (double)adc12[i];
		}
		npts++;
		DelayMilliSecs(1000);
	}
	for(i=0; i<8; i++)
		MeanStdev((ddum+i), (ddumsq+i), npts, Missing);

	printf("%7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f\n",
		ddum[0],ddum[1],ddum[2],ddum[3],
		ddum[4],ddum[5],ddum[6],ddum[7]);
	printf("%7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f\n",
		ddumsq[0],ddumsq[1],ddumsq[2],ddumsq[3],
		ddumsq[4],ddumsq[5],ddumsq[6],ddumsq[7]);
	return;
}

void SampleADCExt(void)
/********************************************************
Test the 18-bit Adam ADC circuit
**********************************************************/
{
	double dum[8], ddum[8], ddumsq[8];
	int i, npts;

	ddum[0]=ddum[1]=ddum[2]=ddum[3]=ddum[4]=ddum[5]=ddum[6]=ddum[7]=0;
	ddumsq[0]=ddumsq[1]=ddumsq[2]=ddumsq[3]=ddumsq[4]=ddumsq[5]=ddumsq[6]=ddumsq[7]=0;
	npts=0;
	while( !SerByteAvail() )
	{
		Read4017All(dum);
		printf("%8.4lf %8.4f %8.4lf %8.4lf %8.4lf"
		"%8.4lf %8.4lf %8.4lf\n",
		 dum[0],dum[1],dum[2],dum[3],dum[4],
		 dum[5], dum[6], dum[7]);

		for(i=0; i<8; i++)
		{
			ddum[i] += (double)dum[i];
			ddumsq[i] += (double)dum[i] * (double)dum[i];
		}
		npts++;
		DelayMilliSecs(1000);
	}
	for(i=0; i<8; i++)
		MeanStdev((ddum+i), (ddumsq+i), npts, Missing);

	printf("%7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f\n",
		ddum[0],ddum[1],ddum[2],ddum[3],
		ddum[4],ddum[5],ddum[6],ddum[7]);
	printf("%7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f\n",
		ddumsq[0],ddumsq[1],ddumsq[2],ddumsq[3],
		ddumsq[4],ddumsq[5],ddumsq[6],ddumsq[7]);
	return;
}


int     Startup(void)
/**********************************************
TT8 PRP 402 and after, startup routines
rmr 000411 -- add heartbeat
**********************************************/
{
	// HEARTBEAT AT STARTUP
	HeartBeat();

	// SET UP COM PORT FOR PREC. NAV. TILT
	TSerOpen(RXPNI,HighPrior,0,malloc(256+TSER_MIN_MEM),256,9600,'N',8,1);
	TSerOpen(TXPNI,HighPrior,1,malloc(256+TSER_MIN_MEM),256,9600,'N',8,1);

	// HEATER
	PConfOutp(E,2);
	PClear(E,2);	// heater starts off

	// PNI AND PREAMP POWER -- ON ALL THE TME
	PConfOutp(E,0); // pni and preamp power & 4520
	PSet(E,0);		// pni & preamp - just leave this power on

	// MOTOR START UP
	PConfOutp(E,1); // motor control, starts on
	PClear(E,1);
	MotorPwrFlag = OFF;

	// Set up Com3 (RS-485)
	TSerOpen(RX485,HighPrior,0,malloc(256+TSER_MIN_MEM),512,9600,'N',8,1);
	TSerOpen(TX485,HighPrior,1,malloc(256+TSER_MIN_MEM),256,9600,'N',8,1);

	// SETUP FOR 485 CHANNEL
	PConfOutp(E,3);   // Power SwD (4017)
	PClear(E,3);
	PConfOutp(E,4);   // RE- (Receive Enable active low)
	PClear(E,4);
	PConfOutp(E,5);   // DE (Data Enable)
	PClear(E,5);

	/*****************
	POWER UP THE 4017
	******************/
	PSet(E,3);		// Turns power on to 4017

	/*****************************
	Start with RTC OFF
	*****************************/
	TPUSetPin(15,0);
	TPUSetPin(7,0);

	return OK;
}

int	SerPutStr(char *s)
/*************************
Put out a string one character at a time
991101
**************************/
{
	int	i;
	//good to here

	for(i=0; i<strlen(s); i++)
	{
		SerPutByte(s[i]);
	}
	return strlen(s);
}

/*******************************
// TIME FUNCTIONS    timetime
******************************/


void	TimeString( struct tm *t, time_t *tm, char *s)
/***************************************
****************************************/
{
	t = gmtime(tm);
	sprintf(s,"%04d%03d,%02d%02d%02d",
		t->tm_year+1900,t->tm_yday,t->tm_hour,t->tm_min,t->tm_sec);
	printf("TimeString:%s\n",s);
	return;
}


time_t ShowTime(void)
/***************************************

****************************************/
{
	char a[24];
	time_t now;

	now = GetTime(a);
	printf("Current time: %s\n",a);
	return now;
}


time_t	GetTime(char *a)
/**************************************
**************************************/
{
	struct tm *tt;
	time_t now;
	int len;

	// GET THE TIME
	now = time(NULL);
	tt = localtime(&now); // pointer to structure

	// PRINT THE TIME IN STD FORMAT
	sprintf(a,"%4d-%02d-%02d %02d:%02d:%02d\0\n",
	tt->tm_year+1900, tt->tm_mon+1, tt->tm_mday, tt->tm_hour, tt->tm_min,
	tt->tm_sec);
	len = strlen(a);
	return now;
}


/**********************************************************
485 TOOLBOX
485485
***********************************************************/


int		Read4017(int chan, double *v)
/***************************************************
READ THE 4017 CHANNEL
input = chan (0-7)
  v = output voltage
return OK/NOTOK
reynolds 000114
*****************************************************/
{
	char	s[10], r[16];
	double fdum;
	int i;

	sprintf(s, "#01%d",chan);
	RS_485(s,r, 11000);  // required LMdelay for 4017 = 11000

	// FIND THE PLUS SIGN
	i=0;
	while( *(r+i) != '+' & *(r+i) != '-' & i < strlen(r) ) i++;


	if( strlen(r) == 0 || sscanf((r+i),"%lf", &fdum ) == 0)
	{
		*v = (double)Missing;
		return NOTOK;
	}
	else
	{
		*v = fdum;
		return OK;
	}
}


int 	Read4017All(double *mv)
/*************************************************
Read all eight channels of the 4017 adc
991227
**************************************************/
{
	char	s[10], r[16];
	unsigned i, igood;
	double fdum;

	SerPutByte('D');
	igood = 0;
	for(i=0; i<8; i++)
	{
		if( Read4017(i,(mv+i)) == OK )  igood++;
	}
	return igood;
}


int	RS_485 (char *s, char *r, unsigned bitdelay)
/**************************************************
	RS-485 Channel Enable

Send the string 's' out the 485 port.
NOTE: <cr> will be added to the end of the transmission
ver 102 991117 rmr
  tighten times for faster response
**************************************************/
{
#define		BUFFERTIME		25	//Allow time for rx buffer to load

	unsigned i, len;
	short rxok;
	ushort	indx;
	int		ch;
	char str[10];

	TSerInFlush(RX485);

	len = strlen(s);  // string length

	/*****************
	// turn 485 port to tx
	*******************/
	PSet(E,4);		// RE-  High for TX
	/****************
	Send the output characters
	*****************/
	for(i=0; i<len; i++)
	{
		TSerPutByte( TX485, s[i] );
	}
	TSerPutByte(TX485,13); // cr

	/************
	return to receive
	**************/
	LMDelay(bitdelay); 	// 4017: 12000==> 0.5 * 12000 microsecs
	PClear(E,4);		// RE-  Low for RX

	indx = 0;
	// Read an initial char
	DelayMilliSecs(BUFFERTIME);  // v401 Allow time to load rx buffer
	while( TSerByteAvail(RX485) )
	{
		ch = TSerGetByte(RX485);
		//printf(" ch= %d", ch);
		*(r+indx) = ch;
		indx++;
	}
	//SerPutByte('\n');
	*(r+indx) = '\0';


	if( indx == 0 ) rxok = NOTOK;
	else rxok = OK;
	return rxok;
}

/***********************
PNI FUNCTIONS
pnipni
*************************/


void PniCommand(char *cmd, char *reply)
/*******************************************************
Send a string, with cr (13) on the end, to the PNI then
receive the reply.

reynolds 000105
********************************************************/
{
	unsigned len;

	// BE SURE STRING ENDS WITH A CR (13)
	len = strlen(cmd);
	if(cmd[len] != 13)
	{
		cmd[len] = 13;
		cmd[len+1]='\0';
	}
	printf("Cmd: %s", cmd);

	TSerInFlush(RXPNI);
	PniSendStr(cmd);
	PniGetStr(reply);
	return;
}


unsigned PniGetStr( char *s)
/****************************************************
Get a string from the precision navigation Inc. PNI tilt/az sensor.
Need external define PNIWAIT delay time.
reynolds 000105
*****************************************************/
{
	#define MAXSTR 64
	ulong t1;
	int ch, len, strflag;


	t1 = TensMilliSecs() + PNIWAIT/10; // wait time in msec/10

	len = 0;
	strflag = NOTOK;
	TSerInFlush(RXPNI);

	while(TensMilliSecs() < t1)
	{
		if( TSerByteAvail(RXPNI) )
		{
			ch = TSerGetByte(RXPNI);
			*(s+len) = ch;
			len++;
			if( ch == 13 )
			{
				*(s+len) = '\0';
				strflag = OK;
				break;
			}
			else if (len > MAXSTR)
			{
				SerPutStr("Buffer full ");
				break;
			}
			t1 = TensMilliSecs() + PNIWAIT; // wait timeout on msec/10
		}
	}

	if( strflag == NOTOK )
	{
		 SerPutStr("Fails ");
		 return NOTOK;
	}
	else
	{
		return OK;
	}
}


unsigned PniSendStr( char *str )
/*****************************************************
Send a string to the PNI tilt/azimuth sensor
IN: str is the string of characters.

You need to define RXPNI channel.
This function ensures a <cr> is on the end of the string.

OUT:
Returns number of characters sent.

reynolds 000105
*****************************************************/
{
	unsigned len, i;

	len = strlen(str);	// Be sure string has CR at end
	if( *(str + len) != 13 )
	{
		*(str+len) = 13;
		*(str+len+1) = '\0';
		len++;
	}

	for(i=0; i<len; i++)
	{
		TSerPutByte(TXPNI,*(str+i));
	}
	return len;
}

void ReadPNI(float *p, float *r, float *a)
/**********************************************************
Read the PNI pitch/roll/azimuth sensor
reynolds 000105
***********************************************************/
{
	char *ptr;
	char *endptr;
	char cmd[6], reply[31];

	SerPutByte('P');
	/***************
	SEND AN ENQUIRY COMMAND
	****************/
	TSerInFlush(RXPNI);

	strcpy(cmd,"s?");
	PniSendStr( cmd );

	/******************
	READ IN THE RESPONSE STRING
	******************/
	if ( PniGetStr(reply) == OK )
	{
		ptr = strchr(reply,67);
		if( ptr == NULL)
			*a = Missing;
		else
		{
			*a = strtod( (ptr+1), &endptr );
			if( *a < 0 || *a > 360 ) *a = 0;
		}

		ptr = strchr(reply,'R');
		if( ptr == NULL )
			*r = Missing;
		else
		{
			*r = strtod( (ptr+1), &endptr );
			if( *r < -90 || *r > 90 ) *r = Missing;
		}

		ptr = strchr(reply,'P');
		if( ptr == NULL )
			*p = Missing;
		else
		{
			*p = strtod( (ptr+1), &endptr );
			if( *p < -90 || *p > 90 ) *p = Missing;

		}
	}
	else SerPutByte('x');

	return;
}

/**********************
HEATER AND HEAD TEMP
temptemp  headhead
************************/

void	HeaterOn(int *HeaterFlag)
/********************************
Turn heater On
RMR 991101
*********************************/
{
		if( *HeaterFlag == OFF)
		{
			SerPutByte('H');
			*HeaterFlag = ON;
			PSet(E,2);
		}
}

void	HeaterOff(int *HeaterFlag)
/********************************
Turn heater Off
RMR 991101
*********************************/
{
	if( *HeaterFlag == ON)
	{
		SerPutByte('h');
		PClear(E,2);
		*HeaterFlag = OFF;
	}
	return;
}

float GetHeadTemp(void)
/*************************************
Read the analog circuit corresponding to the head temperature.
Put degC into TempHead
RMR 991101
*************************************/
{
	float TempHead;
	int id;
	char str[8];
	double d;

	ReadAnalog(7, &id, Missing);  // read temp channel and put into arrays
	d = (double)id / 1000; // volts

	// TempHead = 48.33 * (float)id/1000. - 37.67;
	d = (double)4999 * (5.0 - 2.0 * d) / d; // resistance
	d = log(1.0/d);
	d = A1 * d * d * d + A2 * d * d + A3 * d + A4;
	TempHead = 1.0 / d - 273.15;

	/***********
	Error check
	************/
	if( TempHead < -20 || TempHead > 50)
	{
		TempHead = Missing;
		SerPutByte('x');
	}
	return TempHead;
}

void	HeaterPulse(int on_millisecs)
/***********************************
Operate the heater for on_millisecs milliseconds
RMR 991101
********************************************/
{
	int idum;

	if( on_millisecs > 0 && on_millisecs < 10000 )
	{
		idum = OFF;
		HeaterOn(&idum);
		DelayMilliSecs(on_millisecs);
		HeaterOff(&idum);
	}

	return;
}

int HeaterCheck(float hdtemp_max, int HeaterFlag)
/*********************************
If necessary, operate the heater
1. read temperature -> TempHead degC
2. Check if necc to turn on heater
return
 0=no heater pulse required
 1=head was cold and a pulse was necessary
 RMR 991101
v2 -- do not turn on heater if T<-40 or T>55
**********************************/
{
	float hdtemp;

	hdtemp = GetHeadTemp();

	/************
	Bad temperature -- TURN OFF HEATER
	*************/
	if( hdtemp == Missing || hdtemp < -40 )
		return 0;

	if( hdtemp < -40 || hdtemp > 55 )
		return 0;

	/****************
	IF HEATER IS OFF AND TEMP < LOW THRESHOLD TURN ON
	ELSE LEAVE OFF
	******************/
	if( HeaterFlag == OFF )
	{
		if( hdtemp < hdtemp_max - 0.2 )
			return 1;
		else
			return 0;
	}
	/*****************
	IF HEATER IS ON AND TEMP > HIGH THRESHOLD TURN OFF
	ELSE LEAVE ON
	******************/
	else
	{
		if( hdtemp > hdtemp_max + 0.2 )
			return 0;
		else
			return 1;
	}
}


void    HeartBeat(void)
/************************************************************
RMR 991101
991117 rmr change last delay from 500 to 50 msec
************************************************************/
{
#define TPU_HEARTBEAT  0    // out - TPU for heartbeat LED (Hdwr Wdog)

	SerPutByte('.');
	TPUSetPin(TPU_HEARTBEAT,1);
	DelayMilliSecs(50);
	TPUSetPin(TPU_HEARTBEAT,0);
	DelayMilliSecs(50);
}


