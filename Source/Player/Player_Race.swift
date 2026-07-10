// Player_Race.swift - Port of Player_Race.c to Swift

private var gNumLapsThisRace: Int16 = 3

private func raceCheckpointTaggedBase(_ pi: UnsafeMutablePointer<PlayerInfoType>) -> UnsafeMutablePointer<UInt8> {
    UnsafeMutableRawPointer(pi.pointer(to: \.raceCheckpointTagged)!).assumingMemoryBound(to: UInt8.self)
}

private func PlayerCompletedRace(_ playerNum: Int16) {
    GetPlayerInfoPtr(Int32(playerNum)).pointee.raceComplete = 1

    if gLevelCompleted == 0 { // only if this is the 1st guy to win
        for i in 0..<Int16(gNumPlayers) { // see which player Won (was not eliminated)
            if i != playerNum {
                _ = ShowWinLose(i, 1) // lost
            } else {
                _ = ShowWinLose(i, 0) // won!
            }
        }

        StartLevelCompletion(5.0)
    }
}

// Called from the player's update function to see which line markers we've crossed as part of the
// race placement testing.
func UpdatePlayerRaceMarkers(_ player: UnsafeMutablePointer<ObjNode>) {
    var newCheckpoint: Int32 = 0
    let p = Int32(player.pointee.PlayerNum)
    var c: Int = 0

    // SEE IF CROSSED A LINE MARKER

    if SeeIfCrossedLineMarker(player, &c) != 0 {
        // USE CENTERPOINT OF THIS FOR REINCARNATION

        SetReincarnationCheckpointAtMarker(player, Int16(c))

        let pi = GetPlayerInfoPtr(p)
        let oldCheckpoint = pi.pointee.raceCheckpointNum // get old checkpoint #

        // SEE IF CROSSED FINISH LINE
        //
        // This can happen by going forward or backward over it, so
        // we need to handle it carefully.

        if c == 0 {
            // SEE IF WENT FORWARD THRU FINISH LINE

            if oldCheckpoint == Int16(gNumLineMarkers - 1) {
                var count: Int16 = 0

                for i in 0..<gNumLineMarkers { // count # of checkpoints tagged
                    if raceCheckpointTaggedBase(pi)[Int(i)] != 0 {
                        count += 1
                    }
                }

                // SEE IF WE DID A NEW LAP

                if count > Int16(gNumLineMarkers / 2) { // if crossed at least 50% of the checkpoints then assume we did a full lap
                    pi.pointee.lapNum += 1

                    if pi.pointee.lapNum >= gNumLapsThisRace { // see if completed race
                        PlayerCompletedRace(Int16(p))
                    } else {
                        _ = ShowLapNum(Int16(p))
                    }
                }
            }
            // RESET ALL CHECKPOINT TAGS WHENEVER WE CROSS THE FINISH LINE

            for i in 0..<gNumLineMarkers {
                raceCheckpointTaggedBase(pi)[Int(i)] = 0
            }

            newCheckpoint = Int32(c)
        }

        // SEE IF FORWARD
        else if c > Int(oldCheckpoint) {
            newCheckpoint = Int32(c)
            raceCheckpointTaggedBase(pi)[c] = 1
        }

        // SEE IF WENT BACK
        else if c <= Int(oldCheckpoint) {
            if c == 0 { // if went back over finish line then dec lap counter
                if pi.pointee.lapNum >= 0 {
                    pi.pointee.lapNum -= 1 // just lost a lap
                }
                newCheckpoint = gNumLineMarkers - 1
                for i in 0..<gNumLineMarkers { // set all tags so can go back thru finish line for credit
                    raceCheckpointTaggedBase(pi)[Int(i)] = 1
                }
            } else {
                newCheckpoint = Int32(c - 1)
                raceCheckpointTaggedBase(pi)[c] = 0 // untag the other checkpoint
            }
        }

        // THIS SHOULD ONLY HAPPEN WHEN LAPPED AROUND TO 1ST CHECKPOINT AGAIN
        //
        // This happens anytime the finish line is crossed, but remember that
        // it does not guarantee that the player did a lap - they could have
        // just cheated by backing up and re-crossing the finish line. So,
        // we have to check that they went all the way around the track and
        // didnt skip any checkpoints.
        else {
            newCheckpoint = Int32(c)

            var allTagged = true
            for i in 0..<gNumLineMarkers { // verify that all checkpoints were tagged
                if raceCheckpointTaggedBase(pi)[Int(i)] == 0 { // if this checkpoint was not tagged then they didnt lap
                    allTagged = false
                    break
                }
            }

            if allTagged {
                pi.pointee.lapNum += 1 // yep, we lapped because all the checkpoints were tagged

                // SEE IF COMPLETED THE RACE

                if pi.pointee.lapNum >= gNumLapsThisRace {
                    PlayerCompletedRace(Int16(p))
                } else {
                    _ = ShowLapNum(Int16(p))
                }
            }

            // no_lap:
            for i in 0..<gNumLineMarkers { // reset all tags
                raceCheckpointTaggedBase(pi)[Int(i)] = 0
            }
            raceCheckpointTaggedBase(pi)[c] = 1 // except the one we passed thru
        }

        pi.pointee.raceCheckpointNum = Int16(newCheckpoint) // update player's current ckpt #
    }

    // SEE HOW FAR TO THE NEXT CHECKPOINT

    let pi = GetPlayerInfoPtr(p)
    newCheckpoint = Int32(pi.pointee.raceCheckpointNum)

    // GET NEXT CKP #

    let nextCheckpoint: Int32 = newCheckpoint == (gNumLineMarkers - 1) ? 0 : newCheckpoint + 1 // see if wrap around

    // GET CENTERPOINT OF THE NEXT CHECKPOINT

    let nextMarker = GetLineMarkerPtr(nextCheckpoint)
    var x1 = (nextMarker.pointee.x.0 + nextMarker.pointee.x.1) * 0.5
    var z1 = (nextMarker.pointee.z.0 + nextMarker.pointee.z.1) * 0.5

    // CALC DIST TO NEXT CHECKPOINT

    pi.pointee.distToNextCheckpoint = CalcDistance(x1, z1, gEngine.objects.coord.x, gEngine.objects.coord.z)

    // SEE IF WE'RE AIMING BACKWARDS

    // GET CENTERPOINT OF CURRENT CHECKPOINT

    let curMarker = GetLineMarkerPtr(newCheckpoint)
    let x2 = (curMarker.pointee.x.0 + curMarker.pointee.x.1) * 0.5
    let z2 = (curMarker.pointee.z.0 + curMarker.pointee.z.1) * 0.5

    // CALC VECTOR FROM NEXT CHECKPOINT TO CURRENT

    x1 = x2 - x1
    z1 = z2 - z1
    var checkToCheck = OGLVector2D(x: 0, y: 0)
    FastNormalizeVector2D(x1, z1, &checkToCheck, 0)

    // ALSO CALC DELTA VECTOR

    var deltaVec = OGLVector2D(x: 0, y: 0)
    FastNormalizeVector2D(gEngine.objects.delta.x, gEngine.objects.delta.z, &deltaVec, 1)

    // SEE IF AIM VECTOR IS CLOSE TO PARALLEL TO THAT VEC

    let rot = player.pointee.Rot.y
    var aim = OGLVector2D(x: 0, y: 0)
    aim.x = -sin(rot)
    aim.y = -cos(rot)

    if OGLVector2D_Dot(&aim, &checkToCheck) > 0.6, OGLVector2D_Dot(&deltaVec, &checkToCheck) > 0.6 {
        pi.pointee.wrongWay = 1
    } else {
        pi.pointee.wrongWay = 0
    }
}

// Determine placing by counting how many players are in front of each player.
func CalcPlayerPlaces() {
    for p in 0..<Int32(gNumPlayers) {
        let pi = GetPlayerInfoPtr(p)
        if pi.pointee.raceComplete != 0 { // if player already done, then dont do anything
            continue
        }

        var place: Int16 = 0 // assume 1st place

        for i in 0..<Int32(gNumPlayers) { // check place with other players
            if p == i { // dont compare against self
                continue
            }

            let ii = GetPlayerInfoPtr(i)

            var countAsAhead = true
            repeat {
                if ii.pointee.raceComplete != 0 { break } // skip players that have completed race -> goto next

                // CHECK LAPS

                if pi.pointee.lapNum > ii.pointee.lapNum { countAsAhead = false; break } // I'm more laps -> continue (don't count)
                if pi.pointee.lapNum < ii.pointee.lapNum { break } // I'm less laps -> goto next

                // SAME LAP, SO CHECK CHECKPOINT

                if pi.pointee.raceCheckpointNum > ii.pointee.raceCheckpointNum { countAsAhead = false; break }
                if pi.pointee.raceCheckpointNum < ii.pointee.raceCheckpointNum { break }

                // SAME LAP & CHECKPOINT, SO CHECK DIST TO NEXT CHECKPOINT

                if pi.pointee.distToNextCheckpoint < ii.pointee.distToNextCheckpoint { countAsAhead = false; break }
            } while false

            if countAsAhead {
                place += 1
            }
        }

        pi.pointee.place = place
    }
}
