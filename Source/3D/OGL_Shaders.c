/****************************/
/*   OPENGL SHADERS.C	    */
/* (c)2003 Pangea Software  */
/*   By Brian Greenstone    */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/


extern	AGLContext		gAGLContext;
extern	FSSpec				gDataSpec;


/****************************/
/*    PROTOTYPES            */
/****************************/

static GLuint OGL_VertexShaderProgram_Load(const char *theProgramText);
static void OGL_UnloadVertexShaderProgram(GLuint programID);



/****************************/
/*    CONSTANTS             */
/****************************/

#define	NUM_VERTEX_SHADERS	1

static const Str63 gVertexShaderFiles[NUM_VERTEX_SHADERS] =
{
	"\p:Shaders:VertexShader_Test.shdr"
};




/*********************/
/*    VARIABLES      */
/*********************/

GLuint	gVertexShaderID[NUM_VERTEX_SHADERS];



/**************** OGL:  LOAD ALL SHADER PROGRAMS ************************/
//
// Loads all of our standard vertex and pixel shader programs
//

void OGL_LoadAllShaderPrograms(void)
{
int			i;
FSSpec		spec;
short		fRefNum;
OSErr		iErr;
long		fileSize;
Ptr			buffer;
GLuint		programID;

	return;	//-----------

			/******************************************/
			/* LOAD ALL OF THE DEFAULT VERTEX SHADERS */
			/******************************************/

	for (i = 0; i < NUM_VERTEX_SHADERS; i++)
	{

				/* OPEN THE DATA FORK */

		FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, gVertexShaderFiles[i], &spec);
		iErr = FSpOpenDF(&spec, fsCurPerm, &fRefNum);
		if (iErr)
			DoFatalAlert("\pOGL_LoadAllShaderPrograms: FSpOpenDF failed!");

				/* HOW BIG IS THE DATA */

		iErr = GetEOF(fRefNum, &fileSize);
		if (iErr)
			DoFatalAlert("\pOGL_LoadAllShaderPrograms: GetEOF failed!");

				/* READ THE DATA */

		buffer = AllocPtr(fileSize+1);									// alloc the buffer with extra byte for the C string 0
		if (buffer == nil)
			DoFatalAlert("\pOGL_LoadAllShaderPrograms: AllocPtr failed!");

		iErr = FSRead(fRefNum, &fileSize, buffer);
		if (iErr)
			DoFatalAlert("\pOGL_LoadAllShaderPrograms: FSRead failed!");

		FSClose(fRefNum);

		buffer[fileSize] = 0x00;										// put end of string marker in there

				/* LOAD THE VERTEX PROGRAM INTO OPENGL */

		programID = OGL_VertexShaderProgram_Load(buffer);

		gVertexShaderID[i] = programID;


		SafeDisposePtr(buffer);											// free the buffer

	}


// 		OGL_SetActiveVertexShaderProgram(gVertexShaderID[0]);	//---------
}


/***************** OGL VERTEX SHADER PROGRAM LOAD **************************/
//
// Loads a vertex shader program.
//
// INPUT:  ptr to a c string containing the program to load.
//
// OUTPUT:  the OpenGL program's "name" identifier.
//

static GLuint OGL_VertexShaderProgram_Load(const char *theProgramText)
{
GLuint	programName;
//AGLContext agl_ctx = gAGLContext;


			/* GET A UNIQUE TEXTURE NAME & INITIALIZE IT */

	glGenProgramsARB(1, &programName);
	if (OGL_CheckError())
		DoFatalAlert("\pOGL_VertexShader_Load: glGenProgramsARB failed!");

	glBindProgramARB(GL_VERTEX_PROGRAM_ARB, programName);							// this makes it the currently active program
	if (OGL_CheckError())
		DoFatalAlert("\pOGL_VertexShader_Load: glBindProgramARB failed!");


				/* LOAD SHADER PROGRAM */

	glProgramStringARB(GL_VERTEX_PROGRAM_ARB, GL_PROGRAM_FORMAT_ASCII_ARB, strlen(theProgramText), theProgramText);
	if (OGL_CheckError())
		DoFatalAlert("\pOGL_VertexShader_Load: glProgramStringARB failed! - probably a bad vertex program");


	return(programName);
}


/********************** OGL:  UNLOAD ALL SHADER PROGRAMS ****************************/
//
// Unloads all vertex and pixel shaders.
//

void OGL_UnloadAllShaderPrograms(void)
{
int	i;
//AGLContext agl_ctx = gAGLContext;

   glDisable(GL_VERTEX_PROGRAM_ARB);												// turn the Vertex Program off


	for (i = 0; i < NUM_VERTEX_SHADERS; i++)
	{
		OGL_UnloadVertexShaderProgram(gVertexShaderID[i]);
	}
}



/********************** OGL: UNLOAD VERTEX SHADER PROGRAM *************************/
//
// Unloads a shader program.
//
// INPUT:  programID is the "name" ID that was returned from the Load function above.
//

static void OGL_UnloadVertexShaderProgram(GLuint programID)
{
//AGLContext agl_ctx = gAGLContext;

	glDeleteProgramsARB( 1, &programID );
}


/****************** OGL: SET ACTIVE VERTEX SHADER PROGRAM **************************/
//
// Sets the current shader program to the one referenced by the input ID name.
//

void OGL_SetActiveVertexShaderProgram(GLuint programID)
{
//AGLContext agl_ctx = gAGLContext;

	glBindProgramARB(GL_VERTEX_PROGRAM_ARB, programID);							// this makes it the currently active program
	if (OGL_CheckError())
		DoFatalAlert("\pOGL_Texture_SetOpenGLTexture: glBindProgramARB failed!");

   glEnable(GL_VERTEX_PROGRAM_ARB);												// turn the Vertex Programs on
}











