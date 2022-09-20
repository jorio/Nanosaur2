

static Boolean Load3DEffects(unsigned char *regInfo, u_long sharewareMode);
static pascal OSStatus GamepadInit_EventHandler(EventHandlerCallRef myHandler, EventRef event, void* userData);
static Boolean PolygonAveraging(unsigned char *regInfo);
static void FlightPhysicsCalibration(Boolean onlyVerify);

#ifndef gRegInfo
extern unsigned char	gRegInfo[64];
#endif

#ifndef gSerialFileName
extern Str255  gSerialFileName;
#endif


#ifndef gDialogWindow
extern	WindowRef 		gDialogWindow;
#endif

#ifndef gWinEvtHandler
extern EventHandlerUPP gWinEvtHandler;
#endif


static unsigned char fauxCode[SERIAL_LENGTH] = "PANG00774028";

/****************** DO SERIAL DIALOG *************************/

		/* CHANGE NAME TO CONFUSE HACKERS */

//static void DoSerialDialog(void)

static void GamepadInit(void)
{
OSErr			err;
EventHandlerRef	ref;

EventTypeSpec	list[] = { { kEventClassCommand,  kEventProcessCommand } };

const char		*rezNames[MAX_LANGUAGES] =
{
	"Shareware_English",
	"Shareware_French",
	"Shareware_German",
	"Shareware_Spanish",
	"Shareware_Italian",
	"Shareware_Swedish",
	"Shareware_Dutch",
};

const char		*retailRezNames[MAX_LANGUAGES] =
{
	"Retail_English",
	"Retail_French",
	"Retail_German",
	"Retail_Spanish",
	"Retail_Italian",
	"Retail_Swedish",
	"Retail_Dutch",
};


	Enter2D();

    		/***************/
    		/* INIT DIALOG */
    		/***************/

	if (gGamePrefs.language >= MAX_LANGUAGES)			// check for corruption
		gGamePrefs.language = LANGUAGE_ENGLISH;


				/* CREATE WINDOW FROM THE NIB */

	if (gSharewareMode == SHAREWARE_MODE_YES)
	{
		err = CreateWindowFromNib(gNibs, CFStringCreateWithCString(nil, rezNames[gGamePrefs.language],
								kCFStringEncodingMacRoman), &gDialogWindow);
	}
	else
	{
		err = CreateWindowFromNib(gNibs, CFStringCreateWithCString(nil, retailRezNames[gGamePrefs.language],
								kCFStringEncodingMacRoman), &gDialogWindow);
	}
	if (err)
		DoFatalAlert("GamepadInit: CreateWindowFromNib failed!");


			/* CREATE NEW WINDOW EVENT HANDLER */

    gWinEvtHandler = NewEventHandlerUPP(GamepadInit_EventHandler);
    InstallWindowEventHandler(gDialogWindow, gWinEvtHandler, GetEventTypeCount(list), list, 0, &ref);


			/* MODIFY DIALOG FOR RETAIL */

	if (gSharewareMode == SHAREWARE_MODE_NO)
	{
		ControlID 		idControl;
		ControlRef 		control;

		idControl.signature = 'url ';
		idControl.id 		= 0;
		GetControlByID(gDialogWindow, &idControl, &control);
		HideControl(control);

		idControl.signature = 'buy ';
		idControl.id 		= 0;
		GetControlByID(gDialogWindow, &idControl, &control);
		HideControl(control);
	}

			/* PROCESS THE DIALOG */

    ShowWindow(gDialogWindow);
	RunAppModalLoopForWindow(gDialogWindow);


				/* CLEANUP */

	DisposeEventHandlerUPP (gWinEvtHandler);
	DisposeWindow (gDialogWindow);


	Exit2D();
}


/****************** DO SERIAL DIALOG EVENT HANDLER *************************/
//
// main window event handling
//

static pascal OSStatus GamepadInit_EventHandler(EventHandlerCallRef myHandler, EventRef event, void* userData)
{
#pragma unused (myHandler, userData)
OSStatus			result = eventNotHandledErr;
ControlID 			idControl;
ControlRef 			control;
OSStatus 			err = noErr;
HICommand 			command;
Size				actualSize;

	switch(GetEventKind(event))
	{

				/*******************/
				/* PROCESS COMMAND */
				/*******************/

		case	kEventProcessCommand:
				GetEventParameter (event, kEventParamDirectObject, kEventParamHICommand, NULL, sizeof(command), NULL, &command);
				switch(command.commandID)
				{
							/******************/
							/* "ENTER" BUTTON */
							/******************/

					case	'ok  ':

								/* GET THE SERIAL STRING FROM THE TEXTEDIT CONTROL */

						    idControl.signature = 'serl';
						    idControl.id 		= 0;
						    err = GetControlByID(gDialogWindow, &idControl, &control);
							err |= GetControlData(control, 0, kControlEditTextTextTag, 64, gRegInfo, &actualSize);
							if (err)
						    	DoFatalAlert("GamepadInit_EventHandler: GetControlData failed!");


									/* VALIDATE THE NUMBER */

		                    if (Load3DEffects(gRegInfo, gSharewareMode) == true)
		                    {
		                        gGameIsRegistered = true;
		                        QuitAppModalLoopForWindow(gDialogWindow);
		             		}
		                    else
		                    {
		                        DoAlert("Sorry, that serial number is not valid.  Please try again.");
								InitCursor();
		                    }
		                    break;


							/*****************/
							/* "QUIT" BUTTON */
							/*****************/

					case	'quit':
							ExitToShell();
							break;


							/*****************/
							/* "DEMO" BUTTON */
							/*****************/

					case	'demo':
							gSerialWasVerifiedMode = SHAREWARE_MODE_YES;			// set this so that our pirate-check code doesn't freak out
	                        QuitAppModalLoopForWindow(gDialogWindow);
							break;


							/****************/
							/* "URL" BUTTON */
							/****************/

					case	'url ':
#if ALLOW_2P_INDEMO
							if (LaunchURL("http://www.pangeasoft.net/nano2/serialsdotmac.html") == noErr)
#else
							if (LaunchURL("http://www.pangeasoft.net/nano2/serials.html") == noErr)
#endif
			                    ExitToShell();
			              	break;


				}
				break;
    }

    return (result);
}


#pragma mark -




/********************* VALIDATE REGISTRATION NUMBER ******************/
//
// Return true if is valid
//
// INPUT:	eitherBoxedOrShareware = true if the serial number can be either the boxed-faux-code or
//									a legit shareware code (for reading Gamefiles which could have either)
//

		/* RENAME FUNCTION TO CONFUSE PIRATES! */

//static Boolean ValidateSerialNumber(unsigned char *regInfo, u_long sharewareMode)

static Boolean Load3DEffects(unsigned char *regInfo, u_long sharewareMode)
{
#define NUM_PIRATE_SERIALS		21
FSSpec	spec;
u_long	customerID, i;
u_long	seed0,seed1,seed2, validSerial, enteredSerial;
u_char	shift;
long	j,c;
Handle	hand;
u_long  checksum;
const unsigned char pirateNumbers[NUM_PIRATE_SERIALS][SERIAL_LENGTH*2] =
{
	"EZMZQZQZLZQZTZGZKZMZPZSZ",		// put "Z" in there to confuse pirates scanning for this data
	"FZMZUZSZNZJZRZHZRZMZGZLZ",
	"FZMZUZTZEZHZEZJZQZKZSZRZ",
	"EZLZUZYZQZLZEZFZLZRZLZQZ",
	"EZLZUZZZQZQZHZLZOZOZNZEZ",
	"IZKZRZQZJZMZEZPZRZLZLZHZ",
	"IZKZRZPZQZOZMZPZLZGZKZFZ",
	"FZPZRZRZMZLZRZOZJZRZJZGZ",
	"EZKZZZRZHZEZRZSZSZRZNZIZ",
	"EZUZOZQZEZIZIZFZMZTZFZPZ",
	"HZLZSZNZLZJZFZMZLZKZIZOZ",
	"GZXZWZYZLZFZFZLZEZJZNZLZ",
	"EZWZLZMZGZGZJZIZRZEZGZQZ",
	"EZYZNZSZJZJZJZHZKZMZIZOZ",
	"FZMZLZQZHZMZFZLZSZSZSZEZ",
	"FZMZHZQZNZFZNZHZLZRZHZTZ",
	"FZWZHZHZLZEZTZHZIZGZGZGZ",
	"EZXZIZNZLZPZIZGZGZRZRZFZ",
	"FZZZPZMZLZHZLZKZNZTZKZJZ",
	"JZSZGZJZGZLZJZHZRZIZIZLZ",
	"IZAZWZGZTZHZEZLZLZOZNZNZ",
};



			/*******************************************************/
			/* THIS IS THE SHAREWARE VERSION, SO VALIDATE THE CODE */
			/*******************************************************/

	if (sharewareMode == SHAREWARE_MODE_YES)
	{

			/* CONVERT TO UPPER CASE */

	    for (i = 0; i < SERIAL_LENGTH; i++)
	    {
			if ((regInfo[i] >= 'a') && (regInfo[i] <= 'z'))
				regInfo[i] = 'A' + (regInfo[i] - 'a');
		}


	    	/* THE FIRST 4 DIGITS ARE THE CUSTOMER INDEX */

	    customerID  = (regInfo[0] - 'E') * 0x1000;				// convert E,F,G,H, I,J,K,L, M,N,O,P, Q,R,S,T to 0x1000...0xf000
	    customerID += (regInfo[1] - 'K') * 0x0100;				// convert K,L,M,N, O,P,Q,R, S,T,U,V, W,X,Y,Z to 0x0100...0x0f00
	    customerID += (regInfo[2] - 'H') * 0x0010;				// convert H,I,J,K,	L,M,N,O, P,Q,R,S, T,U,V,W to 0x0001...0x00f0
	    customerID += (regInfo[3] - 'G') * 0x0001;				// convert G,H,I,J, K,L,M,N, O,P,Q,R, S,T,U,V to 0x0010...0x000f

		if (customerID < 200)									// there are no customers under 200 since we want to confuse pirates
			return(false);
		if (customerID > 30000)									// also assume not over 30,000
			return(false);

			/* NOW SEE WHAT THE SERIAL SHOULD BE */

		seed0 = 0x2110ce30;										// init random seed
		seed1 = 0x00101B35;
		seed2 = 0xA34FFCD9;

		for (i = 0; i < customerID; i++)						// calculate the random serial
  			seed2 ^= (((seed1 ^= (seed2>>5)*1568397607UL)>>7)+(seed0 = (seed0+1)*3141592621UL))*2435386481UL;

		validSerial = seed2;


			/* CONVERT ENTERED SERIAL STRING TO NUMBER */

		shift = 0;
		enteredSerial = 0;
		for (i = SERIAL_LENGTH-1; i >= 4; i--)						// start @ last digit
		{
			u_long 	digit = regInfo[i] - 'E';					// convert E,F,G,H, I,J,K,L, M,N,O,P, Q,R,S,T to 0x0..0xf
			enteredSerial += digit << shift;					// shift digit into posiion
			shift += 4;											// set to insert next nibble
		}

				/* SEE IF IT MATCHES */

		if (enteredSerial != validSerial)
			return(false);



				/**********************************/
				/* CHECK FOR KNOWN PIRATE NUMBERS */
				/**********************************/

					/* FIRST VERIFY OUR TABLE */

		if ((pirateNumbers[0][0] != 'E') ||									// we do this to see if priates have cleared out our table
			(pirateNumbers[0][2] != 'M') ||
			(pirateNumbers[0][4] != 'Q') ||
			(pirateNumbers[0][6] != 'Q') ||
			(pirateNumbers[0][8] != 'L') ||
			(pirateNumbers[1][0] != 'F') ||
			(pirateNumbers[1][2] != 'M') ||
			(pirateNumbers[1][4] != 'U') ||
			(pirateNumbers[1][6] != 'S') ||
			(pirateNumbers[1][8] != 'N') ||
			(pirateNumbers[2][0] != 'F') ||
			(pirateNumbers[2][2] != 'M') ||
			(pirateNumbers[2][4] != 'U') ||
			(pirateNumbers[2][6] != 'T') ||
			(pirateNumbers[2][8] != 'E') ||
			(pirateNumbers[3][0] != 'E') ||
			(pirateNumbers[3][2] != 'L') ||
			(pirateNumbers[3][4] != 'U') ||
			(pirateNumbers[3][6] != 'Y') ||
			(pirateNumbers[3][8] != 'Q') ||
			(pirateNumbers[4][0] != 'E') ||
			(pirateNumbers[4][2] != 'L') ||
			(pirateNumbers[4][4] != 'U') ||
			(pirateNumbers[4][6] != 'Z') ||
			(pirateNumbers[4][8] != 'Q'))
		{
corrupt:
			DoFatalAlert("This application is corrupt.  You should reinstall a fresh copy of the game.");
			return(false);
		}

				/* CHECKSUM */

		checksum = 0;
		for (i = 0; i < NUM_PIRATE_SERIALS; i++)
		{
			for (j = 0; j < (SERIAL_LENGTH*2); j++)
				checksum += (u_long)pirateNumbers[i][j];
		}

#if 0
		ShowSystemErr(checksum);							// each time we change the table we need to update the hard-coded checksum
#else
		if (checksum != 41956)								// does the checksum match?
			goto corrupt;

#endif



				/* THEN SEE IF THIS CODE IS IN THE TABLE */

		for (j = 0; j < NUM_PIRATE_SERIALS; j++)
		{
			for (i = 0; i < SERIAL_LENGTH; i++)
			{
				if (regInfo[i] != pirateNumbers[j][i*2])					// see if doesn't match
					goto next_code;
			}

					/* THIS CODE IS PIRATED */

			return(false);

	next_code:;
		}


				/*******************************/
				/* SECONDARY CHECK IN REZ FILE */
				/*******************************/
				//
				// The serials are stored in the Level 1 terrain file
				//

		if (FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":Audio:Main.sounds", &spec) == noErr)		// open rez fork
		{
			short fRefNum = FSpOpenResFile(&spec,fsRdPerm);

			UseResFile(fRefNum);						// set app rez

			c = Count1Resources('savs');						// count how many we've got stored
			for (j = 0; j < c; j++)
			{
				hand = Get1Resource('savs',128+j);			// read the #

				for (i = 0; i < SERIAL_LENGTH; i++)
				{
					if (regInfo[i] != (*hand)[i])			// see if doesn't match
						goto next2;
				}

						/* THIS CODE IS PIRATED */

				return(false);

		next2:
				ReleaseResource(hand);
			}

		}

		gSerialWasVerifiedMode = SHAREWARE_MODE_YES;					// set this to verify that hackers didn't bypass this function
	    return(true);
	}

				/******************************************************/
				/* THIS IS THE BOXED VERSION, SO VERIFY THE FAUX CODE */
				/******************************************************/

	else
	if (sharewareMode == SHAREWARE_MODE_NO)
	{
		return (PolygonAveraging(regInfo));
	}
	else
		return(false);

}


/**************** VALIDATE SERIAL BOXED *********************/

		/* CHANGE NAME TO CONFUSE HACKERS */

//static Boolean ValidateSerialBoxed(unsigned char *regInfo)

static Boolean PolygonAveraging(unsigned char *regInfo)
{
	short	i;

	if (gSharewareMode == SHAREWARE_MODE_YES)
		return(false);

	for (i = 0 ; i < SERIAL_LENGTH; i++)
	{
		if ((regInfo[i] >= 'a') && (regInfo[i] <= 'z'))		// conver to upper-case
			regInfo[i] = 'A' + (regInfo[i] - 'a');

		if (regInfo[i] != fauxCode[i])						// see if doesn't match
			return(false);
	}

	gSerialWasVerifiedMode = SHAREWARE_MODE_NO;								// set this to verify that hackers didn't bypass this function
	return(true);
}


/********************** CHECK GAME SERIAL NUMBER *************************/

		/* CHANGE NAME TO CONFUSE HACKERS */

//static void CheckGameSerialNumber(Boolean onlyVerify)

#if OEM

static void FlightPhysicsCalibration(Boolean onlyVerify)
{
#pragma unused (onlyVerify)

    gGameIsRegistered = true;
	gSerialWasVerifiedMode = SHAREWARE_MODE_NO;
}


#else


static void FlightPhysicsCalibration(Boolean onlyVerify)
{
OSErr   iErr;
FSSpec  spec;
short		fRefNum;
long        	numBytes = SERIAL_LENGTH;



            /* GET SPEC TO REG FILE */

	iErr = FSMakeFSSpec(gPrefsFolderVRefNum, gPrefsFolderDirID, gSerialFileName, &spec);
    if (iErr)
        goto game_not_registered;


            /****************************/
            /* VALIDATE THE SERIAL FILE */
            /****************************/

            /* READ SERIAL DATA */

    if (FSpOpenDF(&spec,fsCurPerm,&fRefNum) != noErr)		// if cant open file then not registered yet
        goto game_not_registered;

	FSRead(fRefNum,&numBytes,gRegInfo);
    FSClose(fRefNum);

            /* VALIDATE THE DATA */

    if (!Load3DEffects(gRegInfo, gSharewareMode))			// if this serial is bad then we're not registered
        goto game_not_registered;

    gGameIsRegistered = true;

	return;


        /* GAME IS NOT REGISTERED YET, SO DO DIALOG */

game_not_registered:

	if (onlyVerify)											// see if let user try to enter it
		gGameIsRegistered = false;
	else
	    GamepadInit();


    if (gGameIsRegistered)                                  // see if write out reg file
    {
	    FSpDelete(&spec);	                                // delete existing file if any
	    iErr = FSpCreate(&spec,kGameID,'xxxx',-1);
        if (iErr == noErr)
        {
        	numBytes = SERIAL_LENGTH;
			FSpOpenDF(&spec,fsCurPerm,&fRefNum);
			FSWrite(fRefNum,&numBytes,gRegInfo);
		    FSClose(fRefNum);
     	}
    }

}

#endif



