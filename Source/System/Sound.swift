// Sound.swift - Port of Sound.c to Swift
//
// gChannelInfo, gSongPlayingFlag, and gCurrentSong are native Swift storage
// now: nothing in any .c file touches them anymore (verified 2026-07-07,
// after MainMenu.c was deleted). ToggleMusic is declared in sound2.h but
// its entire implementation was already #if 0'd out in the original
// (referencing globals that no longer exist), and nothing calls it, so
// it's skipped.

struct ChannelInfoType {
    var effectNum: Int16 = -1
    var volumeAdjust: Float = 0
    var leftVolume: Float = 0
    var rightVolume: Float = 0
}

private let maxChannels = 40

var gChannelInfo: [ChannelInfoType] = Array(repeating: ChannelInfoType(), count: maxChannels)
var gSongPlayingFlag: UInt8 = 0
var gCurrentSong: Int16 = -1
private let maxEffects = 70
private let maxAudioStreams = 9

private let fullSongVolume: Float = 1.0
private let fullEffectsVolume: Float = 1.0

private let volumeMinDist: Float = 700.0 // distance at which volume is 1.0 (maxxed).  Larger is louder

private let kNoErr: OSErr = 0
private let FULL_CHANNEL_VOLUME: UInt32 = 0x0100

private struct EffectDef {
    let bank: UInt8
    let name: String?
    let refVol: Float
}

private struct AutoRumbleDef {
    let lowFrequencyStrength: Float
    let highFrequencyStrength: Float
    let duration: UInt16

    init(_ low: Float = 0, _ high: Float = 0, _ duration: UInt16 = 0) {
        self.lowFrequencyStrength = low
        self.highFrequencyStrength = high
        self.duration = duration
    }
}

// MARK: - Effects table (must match order of the EFFECT_* enum in sound2.h)

private let gSoundBankNames: [String?] = [
    nil, // SOUND_BANK_NULL
    "Main", // SOUND_BANK_MAIN
    "Narration", // SOUND_BANK_NARRATION
]

private let gEffectsTable: [EffectDef] = [
    EffectDef(bank: UInt8(SOUND_BANK_NULL), name: nil, refVol: 1), // EFFECT_NULL
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "ChangeSelect", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "GetPOW", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "Splash", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "TurretExplosion", refVol: 2),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "ImpactSizzle", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "Shield", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "MineExplode", refVol: 3),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "PlaneCrash", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "TurretFire", refVol: 0.6),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "StunGun", refVol: 0.7),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "RocketLaunch", refVol: 1), // unused?
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "WeaponCharge", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "FlareShoot", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "ChangeWeapon", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "SonicScream", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "ElectrodeHum", refVol: 0.5),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "Wormhole", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "WormholeVanish", refVol: 1.6),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "WormholeAppear", refVol: 1.6),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "EggIntoWormhole", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "BodyHit", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "LaunchMissile", refVol: 0.7),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "GrabEgg", refVol: 0.7),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "JetpackHum", refVol: 0.8),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "JetpackIgnite", refVol: 0.6),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "MenuSelect", refVol: 0.6 * (1.0 / 4.0)),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "MissileEngine", refVol: 0.6),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "BombDrop", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "DustDevil", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "LaserBeam", refVol: 0.7),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "CrystalShatter", refVol: 1.5),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "RaptorDeath", refVol: 0.8),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "RaptorAttack", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "BrachHurt", refVol: 1.2),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "BrachDeath", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "Dirt", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_MAIN), name: "BadSelect", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_NARRATION), name: "story1", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_NARRATION), name: "story2", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_NARRATION), name: "story3", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_NARRATION), name: "story4", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_NARRATION), name: "story5", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_NARRATION), name: "story6", refVol: 1),
    EffectDef(bank: UInt8(SOUND_BANK_NARRATION), name: "story7", refVol: 1),
]

private let gAutoRumbleTable: [AutoRumbleDef] = [
    AutoRumbleDef(), // EFFECT_NULL
    AutoRumbleDef(), // EFFECT_CHANGESELECT
    AutoRumbleDef(0.0, 0.7, 150), // EFFECT_GETPOW
    AutoRumbleDef(), // EFFECT_SPLASH
    AutoRumbleDef(), // EFFECT_TURRETEXPLOSION
    AutoRumbleDef(), // EFFECT_IMPACTSIZZLE
    AutoRumbleDef(1.0, 1.0, 300), // EFFECT_SHIELD
    AutoRumbleDef(), // EFFECT_MINEEXPLODE
    AutoRumbleDef(1.0, 1.0, 1000), // EFFECT_PLANECRASH
    AutoRumbleDef(), // EFFECT_TURRETFIRE
    AutoRumbleDef(0.0, 0.9, 50), // EFFECT_STUNGUN
    AutoRumbleDef(0.0, 1.0, 180), // EFFECT_ROCKETLAUNCH (unused I think)
    AutoRumbleDef(), // EFFECT_WEAPONCHARGE
    AutoRumbleDef(0.0, 1.0, 180), // EFFECT_FLARESHOOT
    AutoRumbleDef(), // EFFECT_CHANGEWEAPON
    AutoRumbleDef(), // EFFECT_SONICSCREAM
    AutoRumbleDef(), // EFFECT_ELECTRODEHUM
    AutoRumbleDef(), // EFFECT_WORMHOLE
    AutoRumbleDef(0.5, 0.0, 750), // EFFECT_WORMHOLEVANISH
    AutoRumbleDef(), // EFFECT_WORMHOLEAPPEAR
    AutoRumbleDef(0.5, 0.0, 750), // EFFECT_EGGINTOWORMHOLE
    AutoRumbleDef(1.0, 1.0, 300), // EFFECT_BODYHIT
    AutoRumbleDef(0.0, 1.0, 180), // EFFECT_LAUNCHMISSILE
    AutoRumbleDef(0.0, 0.9, 100), // EFFECT_GRABEGG
    AutoRumbleDef(0.5, 0.0, 100), // EFFECT_JETPACKHUM
    AutoRumbleDef(), // EFFECT_JETPACKIGNITE
    AutoRumbleDef(), // EFFECT_MENUSELECT
    AutoRumbleDef(), // EFFECT_MISSILEENGINE
    AutoRumbleDef(0.0, 1.0, 180), // EFFECT_BOMBDROP
    AutoRumbleDef(), // EFFECT_DUSTDEVIL
    AutoRumbleDef(), // EFFECT_LASERBEAM
    AutoRumbleDef(), // EFFECT_CRYSTALSHATTER
    AutoRumbleDef(), // EFFECT_RAPTORDEATH
    AutoRumbleDef(), // EFFECT_RAPTORATTACK
    AutoRumbleDef(), // EFFECT_BRACHHURT
    AutoRumbleDef(), // EFFECT_BRACHDEATH
    AutoRumbleDef(), // EFFECT_DIRT
    AutoRumbleDef(), // EFFECT_BADSELECT
]

private struct SongDef {
    let path: String
    let volumeTweak: Float
}

private let gSongs: [SongDef] = [
    SongDef(path: ":Audio:theme.mp3", volumeTweak: 1.0), // SONG_THEME
    SongDef(path: ":Audio:introsong.mp3", volumeTweak: 1.0), // SONG_INTRO
    SongDef(path: ":Audio:level1song.mp3", volumeTweak: 1.1), // SONG_LEVEL1
    SongDef(path: ":Audio:level2song.mp3", volumeTweak: 1.0), // SONG_LEVEL2
    SongDef(path: ":Audio:level3song.mp3", volumeTweak: 1.0), // SONG_LEVEL3
    SongDef(path: ":Audio:winsong.mp3", volumeTweak: 1.0), // SONG_WIN
]

// MARK: - State

private var gGlobalVolumeFade: Float = 1.0 // multiplier applied to sfx/song volumes (changes during fade out)
private var gEffectsVolume: Float = fullEffectsVolume
private var gMusicVolume: Float = fullSongVolume
private var gMusicVolumeTweak: Float = 1.0

private var gEarCoords = [OGLPoint3D](repeating: OGLPoint3D(), count: Int(MAX_PLAYERS)) // coord of camera plus a tad to get pt in front of camera
private var gEyeVector = [OGLVector3D](repeating: OGLVector3D(), count: Int(MAX_PLAYERS))

private var gSndHandles: [SndListHandle?] = Array(repeating: nil, count: maxEffects) // handles to ALL sounds
private var gSndOffsets: [Int] = Array(repeating: 0, count: maxEffects)

private var gSndChannel: [SndChannelPtr?] = Array(repeating: nil, count: maxChannels)
private var gMusicChannel: SndChannelPtr?

private var gMaxChannels: Int16 = 0
private var gMostRecentChannel: Int16 = -1

// MARK: - Init sound tools

func InitSoundTools() {
    gMaxChannels = 0
    gMostRecentChannel = -1

    // ALLOC CHANNELS

    gMaxChannels = 0
    while gMaxChannels < Int16(maxChannels) {
        // NEW SOUND CHANNEL

        var chan: SndChannelPtr?
        let iErr = SndNewChannel(&chan, Int16(sampledSynth.rawValue), Int(initStereo.rawValue), nil)
        gSndChannel[Int(gMaxChannels)] = chan
        if iErr != 0 { // if err, stop allocating channels
            break
        }
        gMaxChannels += 1
    }

    // SONG CHANNEL

    let iErr = SndNewChannel(&gMusicChannel, Int16(sampledSynth.rawValue), Int(initStereo.rawValue), nil)
    SwGameAssert(iErr == 0)

    // SET INITIAL VOLUME IN ALL CHANNELS FROM PREFS

    UpdateGlobalVolume()

    // LOAD DEFAULT SOUNDS

    LoadSoundBank(UInt8(SOUND_BANK_MAIN))
}

// MARK: - Shutdown sound

// Called at Quit time
func ShutdownSound() {
    // STOP ANY PLAYING AUDIO

    StopAllEffectChannels()
    KillSong()

    // DISPOSE OF CHANNELS

    for i in 0..<Int(gMaxChannels) {
        SndDisposeChannel(gSndChannel[i], 1)
    }
    gMaxChannels = 0

    // DISPOSE OF ALL SOUND BANKS

    for i in 0..<Int(NUM_SOUND_BANKS) {
        DisposeSoundBank(UInt8(i))
    }
}

// MARK: -

// MARK: - Load sound bank

func LoadSoundBank(_ bank: UInt8) {
    let kSoundExts = ["aiff", "mp3"]

    StopAllEffectChannels()

    // DISPOSE OF EXISTING BANK

    DisposeSoundBank(bank)

    // LOAD ALL EFFECTS IN BANK

    for i in 0..<Int(NUM_EFFECTS) {
        let effectDef = gEffectsTable[i]

        // FILTER EFFECTS BY BANK

        if effectDef.bank != bank {
            continue
        }

        // FIND FSSPEC TO EFFECT FILE

        var spec = FSSpec()
        var refNum: Int16 = -1
        var iErr: OSErr = kNoErr

        for ext in kSoundExts {
            let path = ":Audio:\(gSoundBankNames[Int(effectDef.bank)] ?? ""):\(effectDef.name ?? "").\(ext)"
            iErr = path.withCString { FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, $0, &spec) }
            if iErr == kNoErr { // if the file exists, stop; otherwise try next extension
                break
            }
        }

        // after trying all extensions, stop here if still don't have a valid FSSpec
        SwGameAssert(iErr == kNoErr)

        // OPEN DATA FORK

        iErr = FSpOpenDF(&spec, Int8(fsRdPerm.rawValue), &refNum)
        SwGameAssert(iErr == kNoErr)

        // LOAD SND REZ

        gSndHandles[i] = Pomme_SndLoadFileAsResource(refNum)
        SwGameAssert(gSndHandles[i] != nil)

        // GET OFFSET INTO IT

        var offset = 0
        GetSoundHeaderOffset(gSndHandles[i], &offset)
        gSndOffsets[i] = offset

        // PRE-DECOMPRESS IT

        var handle = gSndHandles[i]
        var offsetForDecompress = offset
        _ = Pomme_DecompressSoundResource(&handle, &offsetForDecompress)
        gSndHandles[i] = handle
        gSndOffsets[i] = offsetForDecompress

        // CLOSE DATA FORK

        FSClose(refNum)
    }
}

// MARK: - Dispose sound bank

func DisposeSoundBank(_ bank: UInt8) {
    StopAllEffectChannels() // make sure all sounds are stopped before nuking any banks

    // FREE ALL SAMPLES

    for i in 0..<Int(NUM_EFFECTS) {
        if gEffectsTable[i].bank == bank {
            if let handle = gSndHandles[i] {
                DisposeHandle(UnsafeMutableRawPointer(handle).assumingMemoryBound(to: Optional<UnsafeMutablePointer<Int8>>.self))
            }

            gSndHandles[i] = nil
            gSndOffsets[i] = 0
        }
    }
}

// MARK: -

// MARK: - Stop a channel

// Stops the indicated sound channel from playing.
func StopAChannel(_ channelNum: UnsafeMutablePointer<Int16>!) {
    let c = channelNum.pointee

    if (c < 0) || (c >= gMaxChannels) { // make sure its a legal #
        return
    }

    var mySndCmd = SndCommand()
    mySndCmd.cmd = UInt16(flushCmd.rawValue)
    mySndCmd.param1 = 0
    mySndCmd.param2 = 0
    SndDoImmediate(gSndChannel[Int(c)], &mySndCmd)

    mySndCmd.cmd = UInt16(quietCmd.rawValue)
    mySndCmd.param1 = 0
    mySndCmd.param2 = 0
    SndDoImmediate(gSndChannel[Int(c)], &mySndCmd)

    channelNum.pointee = -1

    gChannelInfo[Int(c)].effectNum = -1
}

// MARK: - Stop a channel if effect num

// Stops the indicated sound channel from playing if it is still this effect #
func StopAChannelIfEffectNum(_ channelNum: UnsafeMutablePointer<Int16>!, _ effectNum: Int16) -> UInt8 {
    let c = channelNum.pointee

    if c < 0 {
        return 0
    }

    if gChannelInfo[Int(c)].effectNum != effectNum { // make sure its the right effect
        return 0
    }

    StopAChannel(channelNum)

    return 1
}

// MARK: - Stop all effect channels

func StopAllEffectChannels() {
    for i in 0..<Int(gMaxChannels) {
        var c = Int16(i)
        StopAChannel(&c)
    }
}

// MARK: -

// MARK: - Play song

// if songNum == -1, then play existing open song
//
// INPUT: loopFlag = true if want song to loop
func PlaySong(_ songNum: Int16, _ loopFlag: UInt8) {
    if songNum == gCurrentSong { // see if this is already playing
        return
    }

    // ZAP ANY EXISTING SONG

    gCurrentSong = songNum
    KillSong()

    // OPEN APPROPRIATE SONG FILE

    var spec = FSSpec()
    var musicFileRefNum: Int16 = 0

    let song = gSongs[Int(songNum)]

    var iErr = song.path.withCString { FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, $0, &spec) }
    SwGameAssert(iErr == kNoErr)

    iErr = FSpOpenDF(&spec, Int8(fsRdPerm.rawValue), &musicFileRefNum)
    SwGameAssert(iErr == kNoErr)

    gCurrentSong = songNum
    gMusicVolumeTweak = song.volumeTweak

    // START PLAYING

    // START PLAYING FROM FILE

    iErr = SndStartFilePlay(
        gMusicChannel,
        musicFileRefNum,
        0,
        0,
        nil,
        nil,
        nil,
        1)

    FSClose(musicFileRefNum) // close the file (Pomme decompresses entire song into memory)

    if iErr != kNoErr {
        SwFatal("PlaySong: SndStartFilePlay failed! (System error \(iErr))")
    }

    gSongPlayingFlag = 1

    // SET LOOP FLAG ON STREAM (SOURCE PORT ADDITION)
    // So we don't need to re-read the file over and over.

    var mySndCmd = SndCommand()
    mySndCmd.cmd = UInt16(pommeSetLoopCmd.rawValue)
    mySndCmd.param1 = loopFlag != 0 ? 1 : 0
    mySndCmd.param2 = 0
    iErr = SndDoImmediate(gMusicChannel, &mySndCmd)
    if iErr != kNoErr {
        SwFatal("PlaySong: SndDoImmediate (pomme loop extension) failed!")
    }

    let lv2 = UInt32(Float(kFullVolume.rawValue) * gMusicVolumeTweak * gMusicVolume)
    let rv2 = UInt32(Float(kFullVolume.rawValue) * gMusicVolumeTweak * gMusicVolume)
    mySndCmd.cmd = UInt16(volumeCmd.rawValue)
    mySndCmd.param1 = 0
    mySndCmd.param2 = Int((rv2 << 16) | lv2)
    iErr = SndDoImmediate(gMusicChannel, &mySndCmd)
    if iErr != kNoErr {
        SwFatal("PlaySong: SndDoImmediate (volumeCmd) failed!")
    }

    // (the #if 0'd "mute music" block referenced gMuteMusicFlag/gSongMovie,
    // neither of which exist anymore, so it's dropped.)
}

// MARK: - Kill song

func KillSong() {
    gCurrentSong = -1

    if gSongPlayingFlag == 0 {
        return
    }

    gSongPlayingFlag = 0 // tell callback to do nothing

    SndStopFilePlay(gMusicChannel, 1) // stop it
}

// MARK: -

// MARK: - Play effect 3D

// NO SSP
//
// OUTPUT: channel # used to play sound
func PlayEffect3D(_ effectNum: Int16, _ where_: UnsafeMutablePointer<OGLPoint3D>!) -> Int16 {
    if effectNum >= Int16(maxEffects) { // see if illegal sound #
        SwFatal("Illegal sound number \(effectNum)!")
    }

    // CALC VOLUME

    var leftVol: UInt32 = 0
    var rightVol: UInt32 = 0
    calc3DEffectVolume(effectNum, where_, 1.0, &leftVol, &rightVol)
    if (leftVol + rightVol) == 0 {
        return -1
    }

    let theChan = PlayEffect_Parms(effectNum, leftVol, rightVol, UInt(NORMAL_CHANNEL_RATE))

    if theChan != -1 {
        gChannelInfo[Int(theChan)].volumeAdjust = 1.0 // full volume adjust
    }

    return theChan // return channel #
}

// MARK: - Play effect parms 3D

// Plays an effect with parameters in 3D
//
// OUTPUT: channel # used to play sound
func PlayEffect_Parms3D(_ effectNum: Int16, _ where_: UnsafeMutablePointer<OGLPoint3D>!, _ rateMultiplier: UInt32, _ volumeAdjust: Float) -> Int16 {
    if effectNum >= Int16(maxEffects) { // see if illegal sound #
        SwFatal("Illegal sound number \(effectNum)!")
    }

    // CALC VOLUME

    var leftVol: UInt32 = 0
    var rightVol: UInt32 = 0
    calc3DEffectVolume(effectNum, where_, volumeAdjust, &leftVol, &rightVol)
    if (leftVol + rightVol) == 0 {
        return -1
    }

    // PLAY EFFECT

    let theChan = PlayEffect_Parms(effectNum, leftVol, rightVol, UInt(rateMultiplier))

    if theChan != -1 {
        gChannelInfo[Int(theChan)].volumeAdjust = volumeAdjust // remember volume adjuster
    }

    return theChan // return channel #
}

// MARK: - Update 3D sound channel

// Returns TRUE if effectNum was a mismatch or something went wrong
func Update3DSoundChannel(_ effectNum: Int16, _ channel: UnsafeMutablePointer<Int16>!, _ where_: UnsafeMutablePointer<OGLPoint3D>!) -> UInt8 {
    let c = channel.pointee

    if c == -1 {
        return 1
    }

    // MAKE SURE THE SAME SOUND IS STILL ON THIS CHANNEL

    if effectNum != gChannelInfo[Int(c)].effectNum {
        channel.pointee = -1
        return 1
    }

    // SEE IF SOUND HAS COMPLETED

    if IsEffectChannelPlaying(c) == 0 {
        return 1
    }

    // UPDATE THE THING

    if where_ != nil {
        var leftVol: UInt32 = 0
        var rightVol: UInt32 = 0
        calc3DEffectVolume(gChannelInfo[Int(c)].effectNum, where_, gChannelInfo[Int(c)].volumeAdjust, &leftVol, &rightVol)
        if (leftVol + rightVol) == 0 { // if volume goes to 0, then kill channel
            StopAChannel(channel)
            return 0
        }

        ChangeChannelVolume(c, Float(leftVol), Float(rightVol))
    }
    return 0
}

// MARK: - Calc 3D effect volume

private func calc3DEffectVolume(_ effectNum: Int16, _ where_: UnsafeMutablePointer<OGLPoint3D>!, _ volAdjust: Float, _ leftVolOut: UnsafeMutablePointer<UInt32>!, _ rightVolOut: UnsafeMutablePointer<UInt32>!) {
    var whichEar = 0

    var dist = where_.pointee.distance(to: gEarCoords[0]) // calc dist to sound for pane 0
    if gNumPlayers > 1 { // see if other pane is closer (thus louder)
        let dist2 = where_.pointee.distance(to: gEarCoords[1])

        if dist2 < dist {
            dist = dist2
            whichEar = 1
        }
    }

    // DO VOLUME CALCS

    var volumeFactor = (volumeMinDist / dist) * gEffectsTable[Int(effectNum)].refVol
    if volumeFactor > 1.0 {
        volumeFactor = 1.0
    }

    let volume = Float(FULL_CHANNEL_VOLUME) * volumeFactor * volAdjust

    if volume < 6 { // if really quiet, then just turn it off
        leftVolOut.pointee = 0
        rightVolOut.pointee = 0
        return
    }

    // DO STEREO SEPARATION

    var maxLeft: UInt32 = 0
    var maxRight: UInt32 = 0

    // CALC VECTOR TO SOUND

    var earToSound = OGLVector2D()
    earToSound.x = where_.pointee.x - gEarCoords[whichEar].x
    earToSound.y = where_.pointee.z - gEarCoords[whichEar].z
    FastNormalizeVector2D(earToSound.x, earToSound.y, &earToSound, 1)

    // CALC EYE LOOK VECTOR

    var lookVec = OGLVector2D()
    FastNormalizeVector2D(gEyeVector[whichEar].x, gEyeVector[whichEar].z, &lookVec, 1)

    // DOT PRODUCT  TELLS US HOW MUCH STEREO SHIFT

    var dot = 1.0 - fabsf(OGLVector2D_Dot(&earToSound, &lookVec))
    if dot < 0.0 {
        dot = 0.0
    } else if dot > 1.0 {
        dot = 1.0
    }

    // CROSS PRODUCT TELLS US WHICH SIDE

    let cross = OGLVector2D_Cross(&earToSound, &lookVec)

    // DO LEFT/RIGHT CALC

    var left: UInt32
    var right: UInt32

    if cross > 0.0 {
        left = UInt32(volume + (volume * dot))
        right = UInt32(volume - (volume * dot))
    } else {
        right = UInt32(volume + (volume * dot))
        left = UInt32(volume - (volume * dot))
    }

    // KEEP MAX

    if left > maxLeft {
        maxLeft = left
    }
    if right > maxRight {
        maxRight = right
    }

    leftVolOut.pointee = maxLeft
    rightVolOut.pointee = maxRight
}

// MARK: -

// MARK: - Update listener location

// Get ear coord for all local players
func UpdateListenerLocation() {
    for i in 0..<Int(gNumPlayers) {
        let p = cameraPlacementsBase()[i]

        var v = OGLVector3D()
        v.x = p.pointOfInterest.x - p.cameraLocation.x // calc line of sight vector
        v.y = p.pointOfInterest.y - p.cameraLocation.y
        v.z = p.pointOfInterest.z - p.cameraLocation.z
        FastNormalizeVector(v.x, v.y, v.z, &v)

        gEarCoords[i].x = p.cameraLocation.x + (v.x * 300.0) // put ear coord in front of camera
        gEarCoords[i].y = p.cameraLocation.y + (v.y * 300.0)
        gEarCoords[i].z = p.cameraLocation.z + (v.z * 300.0)

        gEyeVector[i] = v
    }
}

@inline(__always) private func cameraPlacementsBase() -> UnsafeMutablePointer<OGLCameraPlacement> {
    UnsafeMutableRawPointer(gGameViewInfoPtr!.pointer(to: \.cameraPlacement)!).assumingMemoryBound(to: OGLCameraPlacement.self)
}

// MARK: - Play effect

// OUTPUT: channel # used to play sound
func PlayEffect(_ effectNum: Int16) -> Int16 {
    PlayEffect_Parms(effectNum, FULL_CHANNEL_VOLUME, FULL_CHANNEL_VOLUME, UInt(NORMAL_CHANNEL_RATE))
}

// MARK: - Play effect parms

// Plays an effect with parameters
//
// OUTPUT: channel # used to play sound
func PlayEffect_Parms(_ effectNum: Int16, _ leftVolume: UInt32, _ rightVolume: UInt32, _ rateMultiplier: UInt) -> Int16 {
    SwGameAssert(effectNum >= 0)
    SwGameAssert(effectNum < Int16(maxEffects))
    SwGameAssertMessage(gSndHandles[Int(effectNum)] != nil, "sound effect wasn't loaded!")

    // LOOK FOR FREE CHANNEL

    let theChan = findSilentChannel()
    if theChan == -1 {
        return -1
    }

    let lv2 = UInt32(Float(leftVolume) * gEffectsVolume) // amplify by global volume
    let rv2 = UInt32(Float(rightVolume) * gEffectsVolume)

    // GET IT GOING

    let chanPtr = gSndChannel[Int(theChan)]

    var mySndCmd = SndCommand()
    mySndCmd.cmd = UInt16(flushCmd.rawValue)
    mySndCmd.param1 = 0
    mySndCmd.param2 = 0
    var myErr = SndDoImmediate(chanPtr, &mySndCmd)
    if myErr != kNoErr {
        return -1
    }

    mySndCmd.cmd = UInt16(quietCmd.rawValue)
    mySndCmd.param1 = 0
    mySndCmd.param2 = 0
    myErr = SndDoImmediate(chanPtr, &mySndCmd)
    if myErr != kNoErr {
        return -1
    }

    mySndCmd.cmd = UInt16(volumeCmd.rawValue) // set sound playback volume
    mySndCmd.param1 = 0
    mySndCmd.param2 = Int((rv2 << 16) | lv2)
    myErr = SndDoImmediate(chanPtr, &mySndCmd)

    mySndCmd.cmd = UInt16(bufferCmd.rawValue) // make it play
    mySndCmd.param1 = 0
    let soundHeaderBase = UnsafeMutableRawPointer(gSndHandles[Int(effectNum)]!.pointee!).assumingMemoryBound(to: Int8.self)
    let soundHeaderPtr: Ptr = soundHeaderBase + gSndOffsets[Int(effectNum)] // pointer to SoundHeader
    mySndCmd.ptr = soundHeaderPtr
    _ = SndDoImmediate(chanPtr, &mySndCmd)
    if myErr != kNoErr {
        return -1
    }

    mySndCmd.cmd = UInt16(rateMultiplierCmd.rawValue) // modify the rate to change the frequency
    mySndCmd.param1 = 0
    mySndCmd.param2 = Int(rateMultiplier)
    SndDoImmediate(chanPtr, &mySndCmd)

    // (the #if 0'd "looping effect" block is a source-port no-op per the
    // original comment, so it's dropped.)

    // SET MY INFO

    gChannelInfo[Int(theChan)].effectNum = effectNum // remember what effect is playing on this channel
    gChannelInfo[Int(theChan)].leftVolume = Float(leftVolume) // remember requested volume (not the adjusted volume!)
    gChannelInfo[Int(theChan)].rightVolume = Float(rightVolume)
    return theChan // return channel #
}

// MARK: -

// MARK: - Update global volume

// Call this whenever gGlobalVolume is changed.  This will update
// all of the sounds with the correct volume.
func UpdateGlobalVolume() {
    gEffectsVolume = fullEffectsVolume * (0.01 * Float(gGamePrefs.sfxVolumePercent)) * gGlobalVolumeFade

    // ADJUST VOLUMES OF ALL CHANNELS REGARDLESS IF THEY ARE PLAYING OR NOT

    for c in 0..<Int(gMaxChannels) {
        ChangeChannelVolume(Int16(c), gChannelInfo[c].leftVolume, gChannelInfo[c].rightVolume)
    }

    // UPDATE SONG VOLUME

    // First, resume song playback if it was paused -- e.g. when we're adjusting the volume via pause menu
    var cmd1 = SndCommand()
    cmd1.cmd = UInt16(pommeResumePlaybackCmd.rawValue)
    SndDoImmediate(gMusicChannel, &cmd1)

    // Now update song channel volume
    gMusicVolume = fullSongVolume * (0.01 * Float(gGamePrefs.musicVolumePercent)) * gGlobalVolumeFade
    let lv2 = UInt32(Float(kFullVolume.rawValue) * gMusicVolumeTweak * gMusicVolume)
    let rv2 = UInt32(Float(kFullVolume.rawValue) * gMusicVolumeTweak * gMusicVolume)
    var cmd2 = SndCommand()
    cmd2.cmd = UInt16(volumeCmd.rawValue)
    cmd2.param1 = 0
    cmd2.param2 = Int((rv2 << 16) | lv2)
    SndDoImmediate(gMusicChannel, &cmd2)
}

// MARK: - Change channel volume

// Modifies the volume of a currently playing channel
func ChangeChannelVolume(_ channel: Int16, _ leftVol: Float, _ rightVol: Float) {
    if channel < 0 { // make sure it's valid
        return
    }

    let lv2 = UInt32(leftVol * gEffectsVolume) // amplify by global volume
    let rv2 = UInt32(rightVol * gEffectsVolume)

    let chanPtr = gSndChannel[Int(channel)] // get the actual channel ptr

    var mySndCmd = SndCommand()
    mySndCmd.cmd = UInt16(volumeCmd.rawValue) // set sound playback volume
    mySndCmd.param1 = 0
    mySndCmd.param2 = Int((rv2 << 16) | lv2) // set volume left & right
    SndDoImmediate(chanPtr, &mySndCmd)

    gChannelInfo[Int(channel)].leftVolume = leftVol // remember requested volume (not the adjusted volume!)
    gChannelInfo[Int(channel)].rightVolume = rightVol
}

// MARK: - Change channel rate

// Modifies the frequency of a currently playing channel
//
// The Input Freq is a fixed-point multiplier, not the static rate via rateCmd.
// This function uses rateMultiplierCmd, so a value of 0x00020000 is x2.0
func ChangeChannelRate(_ channel: Int16, _ rateMult: Int) {
    if channel < 0 { // make sure it's valid
        return
    }

    let chanPtr = gSndChannel[Int(channel)] // get the actual channel ptr

    var mySndCmd = SndCommand()
    mySndCmd.cmd = UInt16(rateMultiplierCmd.rawValue) // modify the rate to change the frequency
    mySndCmd.param1 = 0
    mySndCmd.param2 = rateMult
    SndDoImmediate(chanPtr, &mySndCmd)
}

// MARK: -

// MARK: - Find silent channel

private func findSilentChannel() -> Int16 {
    var theChan = gMostRecentChannel + 1 // start on channel after the most recently acquired one - assuming it has the best chance of being silent
    if theChan >= gMaxChannels {
        theChan = 0
    }
    let startChan = theChan

    repeat {
        var theStatus = SCStatus()
        let myErr = SndChannelStatus(gSndChannel[Int(theChan)], Int16(MemoryLayout<SCStatus>.size), &theStatus) // get channel info

        if myErr == kNoErr, theStatus.scChannelBusy == 0 { // error-free and not playing anything, pick this one
            gMostRecentChannel = theChan
            return theChan
        } else {
            theChan += 1 // try next channel
            if theChan >= gMaxChannels {
                theChan = 0
            }
        }
    } while theChan != startChan

    // NO FREE CHANNELS

    return -1
}

// MARK: - Is effect channel playing

func IsEffectChannelPlaying(_ chanNum: Int16) -> UInt8 {
    var theStatus = SCStatus()
    SndChannelStatus(gSndChannel[Int(chanNum)], Int16(MemoryLayout<SCStatus>.size), &theStatus) // get channel info
    return theStatus.scChannelBusy
}

// MARK: - Pause all sound channels

func PauseAllChannels(_ pause: UInt8) {
    var cmd = SndCommand()
    cmd.cmd = UInt16(pause != 0 ? pommePausePlaybackCmd.rawValue : pommeResumePlaybackCmd.rawValue)

    for c in 0..<Int(gMaxChannels) {
        SndDoImmediate(gSndChannel[c], &cmd)
    }

    SndDoImmediate(gMusicChannel, &cmd)
}

// MARK: -

// MARK: - Global volume fade

func FadeSound(_ loudness: Float) {
    gGlobalVolumeFade = loudness
    UpdateGlobalVolume()
}

// MARK: -

// MARK: - Play rumble effect

func PlayRumbleEffect(_ effectNum: Int16, _ playerNum: Int32) {
    if effectNum < 0 || effectNum >= Int16(NUM_EFFECTS) {
        return
    }

    let rumbleEffect = gAutoRumbleTable[Int(effectNum)]

    if rumbleEffect.duration > 0 {
        Rumble(rumbleEffect.lowFrequencyStrength, rumbleEffect.highFrequencyStrength, UInt32(rumbleEffect.duration), playerNum)
    }
}
