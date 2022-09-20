#if 0
/****************************/
/*      INTERNET ROUTINES   */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/***************/
/* EXTERNALS   */
/***************/

extern	PrefsType	gGamePrefs;
extern	unsigned char	gRegInfo[64];
extern	short	gPrefsFolderVRefNum;
extern	long	gPrefsFolderDirID;
extern	Str255  gSerialFileName;
extern	FSSpec				gDataSpec;
extern	Boolean	gLittleSnitch;
extern	CFBundleRef 		gBundle;


/****************************/
/*    PROTOTYPES            */
/****************************/


static OSErr SkipToPound(void);
static OSErr FindBufferStart(void);
static Boolean InterpretTag(void);
static void ParseNextWord(Str255 s);
static void InterpretVersionName(void);
static void InterpretNoteName(void);
static void InterpretBadSerialsName(void);
static void DoVersionDialog(Str255 s);


/****************************/
/*    CONSTANTS             */
/****************************/

enum
{
	kNotHTTPURLErr 			= -666,
	kWhatImplementationErr 	= -667
};

enum
{
	kTransferBufferSize = 4096
};


/**********************/
/*     VARIABLES      */
/**********************/

Handle		gHTTPDataHandle = nil;
static	int			gHTTPDataSize = 0;
static	int			gHTTPDataIndex = 0;

Boolean	gSuccessfulHTTPRead = false;					// set to true when HTTP data is successfully read




/************************** READ HTTP DATA: VERSION INFO **********************************/

void ReadHTTPData_VersionInfo(void)
{
OSStatus err;
const char urlString[256] = "http://www.pangeasoft.net/nano2/files/updatedata";


				/* DONT DO IT UNLESS THERE'S A TCP/IP CONNECTION */

	if (!IsInternetAvailable())
	{
		gSuccessfulHTTPRead = true;					// set to true even tho we didn't read - no internet so pass.
		return;
	}

	printf("Internet Connection Available...\n");

			/* ALLOCATE BUFFER TO STORE DATA */

	if (gHTTPDataHandle == nil)
	{
		gHTTPDataSize = 40000;
		gHTTPDataHandle = AllocHandle(gHTTPDataSize);					// alloc 40k buffer
	}


			/***************************/
			/* DOWNLOAD DATA TO BUFFER */
			/***************************/

	printf("Downloading Data...\n");

	gHTTPDataIndex = 0;

	err = DownloadURL(urlString);
	if (err)
	{
		switch(err)									// check error to see if hackers have messed with our URLs
		{
			case	kURLInvalidURLError:
					DoFatalAlert("This application's checksum does not match.  Please reinstall the game.");
					break;

		}
		return;
	}

			/****************/
			/* PARSE BUFFER */
			/****************/

	printf("parsing buffer...\n");

	gSuccessfulHTTPRead = true;						// we read it ok!

			/* FIND BUFFER START */

	if (FindBufferStart() != noErr)					// if buffer is bad (probably 404 File Not Found)
		return;

			/* READ AND HANDLE ALL TAGS */

	while (!InterpretTag())
	{

	};

	printf("success!\n");

}


/****************** INTERPRET TAG **********************/
//
// Returns true when done or error
//

static Boolean InterpretTag(void)
{
uint32_t	name, *np;
char	*c;

	SkipToPound();													// skip to next tag

	c = *gHTTPDataHandle;											// point to buffer
	np = (uint32_t *)(c + gHTTPDataIndex);							// point to tag name
	name = *np;														// get tag name
	gHTTPDataIndex += 4;											// skip over it

	name = SwizzleULong(&name);

	switch(name)
	{
		case	'BVER':												// BEST VERSION name
				InterpretVersionName();
				break;

		case	'NOTE':												// NOTE name
				InterpretNoteName();
				break;

		case	'BSER':												// BAD SERIALS name
				InterpretBadSerialsName();
				break;

		case	'TEND':												// END name
				return(true);
	}

	return(false);
}


/******************* INTERPRET VERSION NAME ************************/
//
// We got a VERS tag, so let's read the version and see if our app's verion is this recent.
//

static void InterpretVersionName(void)
{
Str255		s;
NumVersion	*fileVers;
NumVersion	bestVers;
UInt32		vers;

			/* READ VERSION STRING */

	ParseNextWord(s);


		/* CONVERT VERSION STRING TO NUMVERSION */

	bestVers.majorRev = s[1] - '0';					// convert character to number
	bestVers.minorAndBugRev = s[3] - '0';
	bestVers.minorAndBugRev <<= 4;
	bestVers.minorAndBugRev |= s[5] - '0';


			/* GET OUR VERSION */

	vers = CFBundleGetVersionNumber(gBundle);
	fileVers =  (NumVersion *)&vers;



		/* SEE IF THERE'S AN UPDATE */

	if (bestVers.majorRev > fileVers->majorRev)		// see if there's a major rev better
	{
		goto update;
	}
	else
	if ((bestVers.majorRev == fileVers->majorRev) &&		// see if there's a minor rev better
		(bestVers.minorAndBugRev > fileVers->minorAndBugRev))
	{
update:
		DoVersionDialog(s);
	}

}


/****************** DO VERSION DIALOG *************************/

static void DoVersionDialog(Str255 s)
{
Str255			v = "Version               ";
SInt16      	alertItemHit;

	BlockMove(&s[1], &v[9], s[0]);				// copy version number string into full string


	Enter2D();

	StandardAlert(kAlertPlainAlert, "There is a Nanosaur 2 update available at www.pangeasoft.net/downloads.html :", v, NULL, &alertItemHit);

	Exit2D();
}


/********************* INTERPRET NOTE NAME ***************************/
//
// We got a NOTE tag, so let's interpret it and display the note in a dialog.
//

static void InterpretNoteName(void)
{
int		noteID,i;
char	*c = *gHTTPDataHandle;											// point to buffer
Str255	s;
SInt16      alertItemHit;

		/****************************/
		/* READ NOTE'S 4-DIGIT CODE */
		/****************************/

	noteID = (c[gHTTPDataIndex++] - '0') * 1000;
	noteID += (c[gHTTPDataIndex++] - '0') * 100;
	noteID += (c[gHTTPDataIndex++] - '0') * 10;
	noteID += (c[gHTTPDataIndex++] - '0');


		/* SEE IF THIS NOTE HAS ALREADY BEEN SEEN */

	if (gGamePrefs.didThisNote[noteID])
		return;


			/********************/
			/* READ NOTE STRING */
			/********************/

	i = 1;
	s[0] = 0;
	while(c[gHTTPDataIndex] != '#')							// scan until next # marker
	{
		s[i++] = c[gHTTPDataIndex++];
		s[0]++;
	}

			/* DO ALERT WITH NOTE */

	Enter2D();
	StandardAlert(kAlertStopAlert, s, NULL, NULL, &alertItemHit);
	Exit2D();

	gGamePrefs.didThisNote[noteID] = 0xff;
	SavePrefs();
}


/********************* INTERPRET BAD SERIALS NAME ***************************/
//
// We got a BSER tag, so let's read each serial and see if it's ours.
//

static void InterpretBadSerialsName(void)
{
int		i,count;
Str255	s;
OSErr   iErr;
FSSpec  spec;
Handle	hand;
short	fRefNum;

			/* PREPARE TO SAVE BAD SERIALS INTO A DATA FILE */


	if (FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":terrain:level1.ter", &spec) == noErr)
	{
		fRefNum = FSpOpenResFile(&spec,fsRdWrPerm);
		if (fRefNum != -1)
		{
			UseResFile(fRefNum);
		}
	}
	else
	{
		DoFatalAlert("InterpretBadSerialsName: FSMakeFSSpec failed!");
		return;
	}


	count = 0;

	while(true)
	{
		ParseNextWord(s);												// read next word
		if (s[1] == '*')												// see if this is the end marker
			break;

			/* SAVE CODE INTO PERMANENT REZ */

		hand = Get1Resource('savs', 128+count);							// get existing rez
		if (hand)
		{
			BlockMove(&s[1], *hand, SERIAL_LENGTH);						// copy code into handle
			ChangedResource(hand);
		}
		else
		{
			hand = AllocHandle(SERIAL_LENGTH);							// alloc handle
			BlockMove(&s[1], *hand, SERIAL_LENGTH);						// copy code into handle
			AddResource(hand, 'savs', 128+count, "");					// write rez to file
		}
		WriteResource(hand);
		ReleaseResource(hand);
		count++;




			/* COMPARE THIS ILLEGAL SERIAL WITH OURS */

		for (i = 0; i < SERIAL_LENGTH; i++)
		{
			if (gRegInfo[i] != s[1+i])									// doesn't match
				goto next_code;
		}

				/* CODE WAS A MATCH, SO WIPE IT */

		iErr = FSMakeFSSpec(gPrefsFolderVRefNum, gPrefsFolderDirID, gSerialFileName, &spec);
	    if (iErr == noErr)
		{
			FSpDelete(&spec);											// delete the serial file
			DoAlert("The serial number being used is invalid.  Please enter a valid serial number to continue playing.");
		}
		gGamePrefs.lastVersCheckDate.year = 0;							// reset date so will check again next launch
		SavePrefs();
		CleanQuit();
		goto bye;

next_code:;
	}

bye:
	CloseResFile(fRefNum);
}



/********************* PARSE NEXT WORD ****************************/
//
// Reads the next "word' from the buffer.  A word is text between
// any spaces or returns.
//

static void ParseNextWord(Str255 s)
{
char 	*c = *gHTTPDataHandle;														// point to buffer
int		i = 1;

		/* SKIP BLANKS AT FRONT */

	while((c[gHTTPDataIndex] == ' ') || (c[gHTTPDataIndex] == CHAR_RETURN))
	{
		gHTTPDataIndex++;
	}


		/* READ THE GOOD CHARS */

	do
	{
		s[i] = c[gHTTPDataIndex];												// copy from buffer to string
		gHTTPDataIndex++;
		s[0] = i;
		i++;
	}while((c[gHTTPDataIndex] != ' ') && (c[gHTTPDataIndex] != CHAR_RETURN));	// stop when reach space or CR
}


/********************* FIND BUFFER START ***************************/
//
// Skips to the #$#$ tag in the buffer which denotes the beginning of our data
//

static OSErr FindBufferStart(void)
{
	gHTTPDataIndex = 0; 						// start @ beginning of file

	while(true)
	{
		char *c = *gHTTPDataHandle;				// point to buffer

		if (SkipToPound() != noErr)
			return(1);

		if ((c[gHTTPDataIndex] == '$') &&		// see if $#$
			(c[gHTTPDataIndex+1] == '#') &&
			(c[gHTTPDataIndex+2] == '$'))
		{
			if (SkipToPound() != noErr)						// skip to next tag
				return(1);
			return(noErr);
		}

		if (gHTTPDataIndex > gHTTPDataSize)		// see if out of buffer range
			return(1);
	};

}



/********************** SKIP TO POUND ************************/
//
// Skips to the next # character in the buffer
//

static OSErr SkipToPound(void)
{
char	*c;

	c = *gHTTPDataHandle;						// point to buffer

	while(c[gHTTPDataIndex] != '#')				// scan for #
	{
		gHTTPDataIndex++;
		if (gHTTPDataIndex >= gHTTPDataSize)	// see if out of buffer range
			return(1);
	}

	gHTTPDataIndex++;							// skip past the #

	return(noErr);
}


#pragma mark -

/************************** DOWNLOAD URL **********************************/

OSStatus DownloadURL(const char *urlString)
{
OSStatus 	err;

	if (gHTTPDataHandle == nil)
	{
		DoFatalAlert("DownloadURL: gHTTPDataHandle == nil");

	}

			/* DOWNLOAD DATA */

	err = URLSimpleDownload(
						urlString,					// pass the URL string
						nil,						// download to handle, not FSSpec
						gHTTPDataHandle,			// to this handle
						0, 							// no flags
						nil,						// no callback eventProc
						nil);							// no userContex



	return(err);


}


#pragma mark -

/************************ IS INTERNET AVAILABLE ****************************/

#include <SystemConfiguration/SCNetwork.h>

Boolean IsInternetAvailable(void)
{
#if 0
OSErr				iErr;
InetInterfaceInfo 	info;

	iErr = OTInetGetInterfaceInfo(&info, kDefaultInetInterface);

	if (iErr)
		return(false);

	return(true);
#else

Boolean						isReachable;
SCNetworkConnectionFlags	theFlags;

	// Get the flags

	theFlags    = 0;
	isReachable = SCNetworkCheckReachabilityByName("www.apple.com", &theFlags);



	 // Check the reachability
	if (isReachable)
		isReachable = (theFlags & kSCNetworkFlagsReachable);

	if (isReachable)
		isReachable = !(theFlags & kSCNetworkFlagsConnectionRequired);

	 return(isReachable);


#endif
}


/************************ LAUNCH URL *****************************/

OSStatus LaunchURL(ConstStr255Param urlStr)
{
OSStatus err;
ICInstance inst;
long startSel;
long endSel;

    err = ICStart(&inst, kGameID);
    if (err == noErr)
    {
	    startSel = 0;
	    endSel = urlStr[0];
	    err = ICLaunchURL(inst, "", (char *) &urlStr[1], urlStr[0], &startSel, &endSel);
        ICStop(inst);
    }
    return (err);
}



#endif
