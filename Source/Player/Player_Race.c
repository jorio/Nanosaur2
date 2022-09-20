/***************************/
/*   	PLAYER_RACE.C      */
/***************************/

#include "game.h"


/***************/
/* EXTERNALS   */
/***************/


/****************************/
/*    PROTOTYPES            */
/****************************/

static void PlayerCompletedRace(short playerNum);



/****************************/
/*    CONSTANTS             */
/****************************/



/**********************/
/*     VARIABLES      */
/**********************/


short				gNumLapsThisRace = 3;



/*********************** UPDATE PLAYER RACE MARKERS ***************************/
//
// Called from the player's update function to see which line markers we've crossed as part of the
// race placement testing.
//

void UpdatePlayerRaceMarkers(ObjNode *player)
{
short	i;
short	oldCheckpoint,newCheckpoint,nextCheckpoint;
float	x1,z1,x2,z2,rot;
OGLVector2D	checkToCheck,aim,deltaVec;
short	p = player->PlayerNum;
long		c;

				/********************************/
				/* SEE IF CROSSED A LINE MARKER */
				/********************************/

	if (SeeIfCrossedLineMarker(player, &c))
	{

				/* USE CENTERPOINT OF THIS FOR REINCARNATION */

		SetReincarnationCheckpointAtMarker(player, c);



		oldCheckpoint = gPlayerInfo[p].raceCheckpointNum;								// get old checkpoint #

				/******************************/
				/* SEE IF CROSSED FINISH LINE */
				/******************************/
				//
				// This can happen by going forward or backward over it, so
				// we need to handle it carefully.
				//

		if (c == 0)
		{
					/* SEE IF WENT FORWARD THRU FINISH LINE */

			if (oldCheckpoint == (gNumLineMarkers - 1))
			{
				short	count = 0;

				for (i = 0; i < gNumLineMarkers; i++)								// count # of checkpoints tagged
				{
					if (gPlayerInfo[p].raceCheckpointTagged[i])
						count++;
				}

						/* SEE IF WE DID A NEW LAP */

				if (count > (gNumLineMarkers / 2))									// if crossed at least 50% of the checkpoints then assume we did a full lap
				{
					gPlayerInfo[p].lapNum++;

					if (gPlayerInfo[p].lapNum >= gNumLapsThisRace)					// see if completed race
						PlayerCompletedRace(p);
					else
						ShowLapNum(p);
				}
			}
					/* RESET ALL CHECKPOINT TAGS WHENEVER WE CROSS THE FINISH LINE*/

			for (i = 0; i < gNumLineMarkers; i++)
				gPlayerInfo[p].raceCheckpointTagged[i] = false;

			newCheckpoint = c;
		}

				/******************/
				/* SEE IF FORWARD */
				/******************/
		else
		if (c > oldCheckpoint)
		{
			newCheckpoint = c;
			gPlayerInfo[p].raceCheckpointTagged[c] = true;
		}

				/********************/
				/* SEE IF WENT BACK */
				/********************/
		else
		if (c <= oldCheckpoint)
		{
			if (c == 0)																// if went back over finish line then dec lap counter
			{
				if (gPlayerInfo[p].lapNum >= 0)
					gPlayerInfo[p].lapNum--;										// just lost a lap
				newCheckpoint = gNumLineMarkers-1;
				for (i = 0; i < gNumLineMarkers; i++)								// set all tags so can go back thru finish line for credit
					gPlayerInfo[p].raceCheckpointTagged[i] = true;

			}
			else
			{
				newCheckpoint = c-1;
				gPlayerInfo[p].raceCheckpointTagged[c] = false;							// untag the other checkpoint
			}
		}

			/**********************************************************************/
			/* THIS SHOULD ONLY HAPPEN WHEN LAPPED AROUND TO 1ST CHECKPOINT AGAIN */
			/**********************************************************************/
			//
			// This happens anytime the finish line is crossed, but remember that
			// it does not guarantee that the player did a lap - they could have
			// just cheated by backing up and re-crossing the finish line.  So,
			// we have to check that they went all the way around the track and
			// didnt skip any checkpoints.
			//

		else
		{
			newCheckpoint = c;

			for (i = 0; i < gNumLineMarkers; i++)									// verify that all checkpoints were tagged
			{
				if (!gPlayerInfo[p].raceCheckpointTagged[i])							// if this checkpoint was not tagged then they didnt lap
					goto no_lap;
			}
			gPlayerInfo[p].lapNum++;												// yep, we lapped because all the checkpoints were tagged

				/* SEE IF COMPLETED THE RACE */

			if (gPlayerInfo[p].lapNum >= gNumLapsThisRace)
				PlayerCompletedRace(p);
			else
				ShowLapNum(p);


no_lap:;
			for (i = 0; i < gNumLineMarkers; i++)									// reset all tags
				gPlayerInfo[p].raceCheckpointTagged[i] = false;
			gPlayerInfo[p].raceCheckpointTagged[c] = true;								// except the one we passed thru
		}

		gPlayerInfo[p].raceCheckpointNum = newCheckpoint;								// update player's current ckpt #
	}


			/**************************************/
			/* SEE HOW FAR TO THE NEXT CHECKPOINT */
			/**************************************/

	newCheckpoint = gPlayerInfo[p].raceCheckpointNum;

				/* GET NEXT CKP # */

	if (newCheckpoint == (gNumLineMarkers-1))						// see if wrap around
		nextCheckpoint = 0;
	else
		nextCheckpoint = newCheckpoint+1;


		/* GET CENTERPOINT OF THE NEXT CHECKPOINT */

	x1 = (gLineMarkerList[nextCheckpoint].x[0] + gLineMarkerList[nextCheckpoint].x[1]) * .5f;
	z1 = (gLineMarkerList[nextCheckpoint].z[0] + gLineMarkerList[nextCheckpoint].z[1]) * .5f;


			/* CALC DIST TO NEXT CHECKPOINT */

	gPlayerInfo[p].distToNextCheckpoint = CalcDistance(x1, z1, gCoord.x, gCoord.z);


				/*********************************/
				/* SEE IF WE'RE AIMING BACKWARDS */
				/*********************************/


				/* GET CENTERPOINT OF CURRENT CHECKPOINT */

	x2 = (gLineMarkerList[newCheckpoint].x[0] + gLineMarkerList[newCheckpoint].x[1]) * .5f;
	z2 = (gLineMarkerList[newCheckpoint].z[0] + gLineMarkerList[newCheckpoint].z[1]) * .5f;


					/* CALC VECTOR FROM NEXT CHECKPOINT TO CURRENT */

	x1 = x2 - x1;
	z1 = z2 - z1;
	FastNormalizeVector2D(x1, z1, &checkToCheck, false);


				/* ALSO CALC DELTA VECTOR */

	FastNormalizeVector2D(gDelta.x, gDelta.z, &deltaVec, true);


				/* SEE IF AIM VECTOR IS CLOSE TO PARALLEL TO THAT VEC */

	rot = player->Rot.y;
	aim.x = -sin(rot);
	aim.y = -cos(rot);

	if ((OGLVector2D_Dot(&aim, &checkToCheck) > .6f) && (OGLVector2D_Dot(&deltaVec, &checkToCheck) > .6f))
		gPlayerInfo[p].wrongWay = true;
	else
		gPlayerInfo[p].wrongWay = false;

}


/************************** CALC PLAYER PLACES **************************/
//
// Determine placing by counting how many players are in front of each player.
//

void CalcPlayerPlaces(void)
{
short	p,place,i;



	for (p = 0; p < gNumPlayers; p++)
	{
		if (gPlayerInfo[p].raceComplete)							// if player already done, then dont do anything
			continue;

		place = 0;													// assume 1st place

		for (i = 0; i < gNumPlayers; i++)						// check place with other players
		{
			if (p == i)												// dont compare against self
				continue;

			if (gPlayerInfo[i].raceComplete)						// skip players that have completed race
				goto next;


						/* CHECK LAPS */

			if (gPlayerInfo[p].lapNum > gPlayerInfo[i].lapNum)					// see if I'm more laps than other guy
				continue;

			if (gPlayerInfo[p].lapNum < gPlayerInfo[i].lapNum)					// see if I'm less laps than other guy
				goto next;


					/* SAME LAP, SO CHECK CHECKPOINT */

			if (gPlayerInfo[p].raceCheckpointNum > gPlayerInfo[i].raceCheckpointNum)	// see if I'm more cp's than other guy
				continue;

			if (gPlayerInfo[p].raceCheckpointNum < gPlayerInfo[i].raceCheckpointNum)	// see if I'm less cp's than other guy
				goto next;


					/* SAME LAP & CHECKPOINT, SO CHECK DIST TO NEXT CHECKPOINT */

			if (gPlayerInfo[p].distToNextCheckpoint < gPlayerInfo[i].distToNextCheckpoint)
				continue;

next:
			place++;
		}


		gPlayerInfo[p].place = place;
	}
}




/****************** PLAYER COMPLETED RACE ************************/
//
// Called when player crosses the finish line on the final lap.
//

static void PlayerCompletedRace(short playerNum)
{
short	i;

	gPlayerInfo[playerNum].raceComplete = true;


	if (!gLevelCompleted)									// only if this is the 1st guy to win
	{
		for (i = 0; i < gNumPlayers; i++)				// see which player Won (was not eliminated)
		{
			if (i != playerNum)
			{
				ShowWinLose(i, 1);					// lost
			}
			else
				ShowWinLose(i, 0);					// won!
		}

		StartLevelCompletion(5.0f);
	}
}









