// SoundEngine.swift - Native sound-effect/music playback engine, replacing
// Pomme's Sound Manager emulation (SndNewChannel/SndDoImmediate/
// SndChannelStatus/SndStartFilePlay/SndStopFilePlay, and the AIFF/MP3
// decoders underneath it). Sound.swift is the only consumer of this file -
// see it for the PlayEffect/PlaySong-level API everything else in the game
// actually calls; nothing outside Sound.swift touches these types.
//
// Design:
//  - Effects and music are fully decoded to interleaved Int16 PCM up front
//    (same as before - the original codebase's own comment already noted
//    "Pomme decompresses entire song into memory").
//  - Each of the 40 effect channels + 1 music channel owns its own
//    SDL_AudioStream, opened directly against the default output device
//    (SDL_OpenAudioDeviceStream) - SDL mixes any number of such streams
//    together automatically, so no custom mixer is needed.
//  - Volume is baked into the PCM samples before queuing (SDL_AudioStream
//    has no live per-stream gain control) - changing the volume of an
//    already-playing sound clears the stream and re-queues the *remaining*
//    unplayed samples at the new volume. This matches the original Sound
//    Manager's own behavior: volumeCmd is a discrete "set from now on"
//    command, not sample-interpolated, so a re-queue produces the same
//    audible effect.
//  - Rate/pitch changes use SDL_SetAudioStreamFrequencyRatio, which
//    live-resamples already-queued data - no re-queue needed.
//  - Looping (music only) is polled once a frame (see MaintainSoundChannels,
//    called from UpdateListenerLocation which already runs every frame) -
//    when a looping stream's queue empties, it's re-queued from the start.

// MARK: - PCM decoding

private struct DecodedPCM {
    var samples: [Int16] // interleaved
    var channels: Int32
    var sampleRate: Int32
}

private enum SoundDecodeError: Error {
    case invalidFormat
}

// Parses a big-endian IEEE 754 80-bit extended float (AIFF's COMM.sampleRate
// field) - no implicit leading mantissa bit, unlike Double/Float80's usual
// x87 encoding assumptions, so this is spelled out by hand rather than
// reinterpreting the bytes as some existing Swift float type.
private func parseIEEEExtended(_ bytes: ArraySlice<UInt8>) -> Double {
    let b = Array(bytes)
    let sign: Double = (b[0] & 0x80) != 0 ? -1 : 1
    let exponent = Int((UInt16(b[0] & 0x7F) << 8) | UInt16(b[1])) - 16383
    var mantissa: UInt64 = 0
    for i in 2..<10 {
        mantissa = (mantissa << 8) | UInt64(b[i])
    }
    return sign * Double(mantissa) * pow(2.0, Double(exponent - 63))
}

// MARK: - IMA4 (QuickTime IMA ADPCM) decoding
//
// Ported from extern/Pomme/src/SoundFormats/IMA4.cpp (itself adapted from
// ffmpeg's libavcodec/adpcm.c) - some of this game's own effect files
// (Splash/RocketLaunch/ChangeWeapon/FlareShoot) use this compression, so
// 'NONE'/'twos'/'sowt' alone wasn't enough.

private let ffAdpcmIndexTable: [Int32] = [-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8]

private let ffAdpcmStepTable: [Int32] = [
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17,
    19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
    50, 55, 60, 66, 73, 80, 88, 97, 107, 118,
    130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
    337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
    876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
    2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
    5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
    15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767,
]

private struct ADPCMChannelStatus {
    var predictor: Int32 = 0
    var stepIndex: Int32 = 0
}

private func adpcmIMAQTExpandNibble(_ status: inout ADPCMChannelStatus, _ nibble: Int32) -> Int32 {
    let step = ffAdpcmStepTable[Int(status.stepIndex)]
    var stepIndex = status.stepIndex + ffAdpcmIndexTable[Int(nibble)]
    stepIndex = min(max(stepIndex, 0), 88)

    var diff = step >> 3
    if nibble & 4 != 0 { diff += step }
    if nibble & 2 != 0 { diff += step >> 1 }
    if nibble & 1 != 0 { diff += step >> 2 }

    let predictor = nibble & 8 != 0 ? status.predictor - diff : status.predictor + diff

    status.predictor = min(max(predictor, -32768), 32767)
    status.stepIndex = stepIndex

    return status.predictor
}

// IMA4 is encoded in chunks of 34 bytes per channel (= 64 samples); channel
// data is interleaved per-chunk.
private func decodeIMA4(_ input: [UInt8], channels: Int) -> [Int16] {
    let bytesPerChunk = 34 * channels
    let chunkCount = input.count / bytesPerChunk
    var output = [Int16](repeating: 0, count: chunkCount * 64 * channels)
    var status = [ADPCMChannelStatus](repeating: ADPCMChannelStatus(), count: channels)

    var inPos = 0
    var outPos = 0
    for _ in 0..<chunkCount {
        for chan in 0..<channels {
            let header = (Int16(input[inPos]) << 8) | Int16(input[inPos + 1])
            var predictor = Int32(header)
            let stepIndex = predictor & 0x7F
            predictor &= ~0x7F
            inPos += 2

            if status[chan].stepIndex == stepIndex {
                let diff = abs(predictor - status[chan].predictor)
                if diff <= 0x7F {
                    status[chan].stepIndex = stepIndex
                    status[chan].predictor = predictor
                }
            } else {
                status[chan].stepIndex = stepIndex
                status[chan].predictor = predictor
            }

            var pos = outPos + chan
            for _ in 0..<32 {
                let byte = Int32(input[inPos])
                inPos += 1
                output[pos] = Int16(adpcmIMAQTExpandNibble(&status[chan], byte & 0x0F))
                pos += channels
                output[pos] = Int16(adpcmIMAQTExpandNibble(&status[chan], byte >> 4))
                pos += channels
            }
        }
        outPos += 64 * channels
    }

    return output
}

// Parses the COMM/SSND chunks of an AIFF or AIFF-C file into PCM samples.
// Handles the compression types actually used by this game's assets:
// 'NONE'/'twos' = big-endian PCM, 'sowt' = little-endian PCM, 'ima4' =
// QuickTime IMA ADPCM (decoded above).
private func decodeAIFF(_ bytes: [UInt8]) throws -> DecodedPCM {
    guard bytes.count >= 12,
          bytes[0...3].elementsEqual("FORM".utf8),
          bytes[8...11].elementsEqual("AIFF".utf8) || bytes[8...11].elementsEqual("AIFC".utf8)
    else {
        throw SoundDecodeError.invalidFormat
    }

    var channels: Int32 = 0
    var sampleRate: Int32 = 0
    var bigEndian = true
    var isIMA4 = false
    var sampleData: ArraySlice<UInt8>?

    var offset = 12
    while offset + 8 <= bytes.count {
        let chunkID = bytes[offset..<(offset + 4)]
        let chunkSize = Int(bytes[offset + 4]) << 24 | Int(bytes[offset + 5]) << 16 | Int(bytes[offset + 6]) << 8 | Int(bytes[offset + 7])
        let dataStart = offset + 8
        guard dataStart + chunkSize <= bytes.count else { break }
        let chunkData = bytes[dataStart..<(dataStart + chunkSize)]

        if chunkID.elementsEqual("COMM".utf8) {
            channels = Int32(bytes[dataStart]) << 8 | Int32(bytes[dataStart + 1])
            sampleRate = Int32(parseIEEEExtended(chunkData[(dataStart + 8)..<(dataStart + 18)]))
            if chunkSize >= 22 {
                let compressionType = chunkData[(dataStart + 18)..<(dataStart + 22)]
                if compressionType.elementsEqual("sowt".utf8) {
                    bigEndian = false
                } else if compressionType.elementsEqual("NONE".utf8) || compressionType.elementsEqual("twos".utf8) {
                    bigEndian = true
                } else if compressionType.elementsEqual("ima4".utf8) {
                    isIMA4 = true
                } else {
                    SwFatal("decodeAIFF: unsupported AIFF-C compression type")
                }
            }
        } else if chunkID.elementsEqual("SSND".utf8) {
            let dataOffset = Int(bytes[dataStart]) << 24 | Int(bytes[dataStart + 1]) << 16 | Int(bytes[dataStart + 2]) << 8 | Int(bytes[dataStart + 3])
            sampleData = chunkData[(dataStart + 8 + dataOffset)...]
        }

        offset = dataStart + chunkSize + (chunkSize % 2) // chunks are padded to even size
    }

    guard channels > 0, sampleRate > 0, let sampleData else {
        throw SoundDecodeError.invalidFormat
    }

    let samples: [Int16]
    if isIMA4 {
        samples = decodeIMA4(Array(sampleData), channels: Int(channels))
    } else {
        var pcm = [Int16](repeating: 0, count: sampleData.count / 2)
        var i = sampleData.startIndex
        var j = 0
        while i + 1 < sampleData.endIndex {
            let hi = UInt16(sampleData[i])
            let lo = UInt16(sampleData[i + 1])
            let raw = bigEndian ? (hi << 8) | lo : (lo << 8) | hi
            pcm[j] = Int16(bitPattern: raw)
            i += 2
            j += 1
        }
        samples = pcm
    }

    return DecodedPCM(samples: samples, channels: channels, sampleRate: sampleRate)
}

// Decodes an entire MP3 file to PCM up front via minimp3 (vendored under
// extern/Pomme/src/SoundFormats/minimp3.h - see sound2.h/minimp3_impl.c).
private func decodeMP3(_ bytes: [UInt8]) -> DecodedPCM {
    var decoder = mp3dec_t()
    mp3dec_init(&decoder)

    var samples: [Int16] = []
    // Rough heuristic (typical MP3 bitrates compress 16-bit stereo PCM
    // ~4-6x) to avoid repeated reallocation/copy while appending - this is
    // the dominant cost in an unoptimized build for a multi-minute song
    // (millions of samples), far more than the decode math itself (which
    // runs through the same compiled minimp3 C function Pomme used).
    samples.reserveCapacity(bytes.count * 5)
    var channels: Int32 = 2
    var sampleRate: Int32 = 44100

    var frameBuffer = [Int16](repeating: 0, count: Int(MINIMP3_MAX_SAMPLES_PER_FRAME))
    var offset = 0

    bytes.withUnsafeBufferPointer { buf in
        frameBuffer.withUnsafeMutableBufferPointer { out in
            while offset < buf.count {
                var info = mp3dec_frame_info_t()
                let samplesDecoded = mp3dec_decode_frame(&decoder, buf.baseAddress! + offset, Int32(buf.count - offset), out.baseAddress, &info)

                if info.frame_bytes == 0 {
                    return // no more valid frames
                }
                offset += Int(info.frame_bytes)

                if samplesDecoded > 0 {
                    channels = Int32(info.channels)
                    sampleRate = Int32(info.hz)
                    samples.append(contentsOf: UnsafeBufferPointer(rebasing: out[0..<Int(samplesDecoded * info.channels)]))
                }
            }
        }
    }

    return DecodedPCM(samples: samples, channels: channels, sampleRate: sampleRate)
}

private func decodePCM(_ bytes: [UInt8], isMP3: Bool) -> DecodedPCM? {
    if isMP3 {
        return decodeMP3(bytes)
    }
    return try? decodeAIFF(bytes)
}

// MARK: - Channel

// One playback slot - either a one-shot effect or the single looping music
// channel. Owns its own SDL_AudioStream bound directly to the default
// output device; SDL mixes all channels' streams together automatically.
final class SwSoundChannel {
    private var stream: OpaquePointer? // SDL_AudioStream*
    private var pcm: [Int16] = []
    private var channels: Int32 = 2
    private var sampleRate: Int32 = 44_100
    private var playhead = 0 // index into `pcm` of the next sample not yet queued
    private var isPlaying = false
    private var leftVolume: Float = 1
    private var rightVolume: Float = 1
    var loop = false

    // Keep only a small amount of decoded-and-scaled audio queued at once
    // (topped up every frame via topUp(), called from MaintainSoundChannels)
    // instead of scaling and queuing an entire song up front. SDL_AudioStream
    // has no live per-stream gain control, so volume changes need a rescale;
    // bounding how much is ever rescaled at once (instead of the whole
    // remaining buffer, which could be minutes of audio) is what keeps
    // PlaySong/UpdateGlobalVolume/etc. cheap regardless of song length. This
    // also means a volume change takes effect within ~1 topped-up chunk
    // (a fraction of a second), not instantly - imperceptible in practice,
    // and how the original Sound Manager's own device-level volumeCmd
    // behaved too (not sample-interpolated).
    private let targetQueuedFrames = 4096

    init() {
        var spec = SDL_AudioSpec()
        spec.format = SDL_AUDIO_S16
        spec.channels = 2
        spec.freq = 44_100
        stream = SDL_OpenAudioDeviceStream(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &spec, nil, nil)
        if stream != nil {
            _ = SDL_ResumeAudioStreamDevice(stream)
        }
    }

    deinit {
        if let stream {
            SDL_DestroyAudioStream(stream)
        }
    }

    var isValid: Bool { stream != nil }

    // Playing anything right now (queued audio not yet fully consumed, or
    // still has unqueued samples left to top up)?
    var isBusy: Bool {
        guard let stream else { return false }
        return isPlaying && (SDL_GetAudioStreamQueued(stream) > 0 || playhead < pcm.count)
    }

    func stop() {
        guard let stream else { return }
        _ = SDL_ClearAudioStream(stream)
        pcm = []
        loop = false
        isPlaying = false
    }

    func pauseDevice() {
        guard let stream else { return }
        _ = SDL_PauseAudioStreamDevice(stream)
    }

    func resumeDevice() {
        guard let stream else { return }
        _ = SDL_ResumeAudioStreamDevice(stream)
    }

    // Assigns and immediately starts playing a fully-decoded PCM buffer.
    // Volume is 0...1 per channel; rateRatio 1.0 = normal speed. Only a
    // small initial chunk is queued here - topUp() feeds the rest.
    func play(_ decoded: DecodedPCMBuffer, leftVolume: Float, rightVolume: Float, rateRatio: Float) {
        guard let stream else { return }
        _ = SDL_ClearAudioStream(stream)
        pcm = decoded.samples
        channels = decoded.channels
        sampleRate = decoded.sampleRate
        self.leftVolume = leftVolume
        self.rightVolume = rightVolume
        playhead = 0
        loop = false
        isPlaying = true
        _ = SDL_SetAudioStreamFrequencyRatio(stream, rateRatio)
        setStreamFormat()
        topUp()
    }

    // Takes effect on the next topped-up chunk (see targetQueuedFrames) -
    // not a full-buffer rescale.
    func setVolume(left: Float, right: Float) {
        leftVolume = left
        rightVolume = right
    }

    func setRateRatio(_ ratio: Float) {
        guard let stream else { return }
        _ = SDL_SetAudioStreamFrequencyRatio(stream, ratio)
    }

    private func setStreamFormat() {
        guard let stream else { return }
        var spec = SDL_AudioSpec()
        spec.format = SDL_AUDIO_S16
        spec.channels = channels
        spec.freq = sampleRate
        _ = SDL_SetAudioStreamFormat(stream, &spec, nil)
    }

    // Called once a frame (see MaintainSoundChannels). Refills the stream's
    // queue up to targetQueuedFrames, applying current volume to only the
    // newly-queued chunk, and handles looping/end-of-buffer incrementally.
    func topUp() {
        guard let stream, isPlaying, !pcm.isEmpty else { return }

        let bytesPerFrame = 2 * Int(channels)
        var framesToQueue = targetQueuedFrames - Int(SDL_GetAudioStreamQueued(stream)) / bytesPerFrame

        while framesToQueue > 0 {
            if playhead >= pcm.count {
                if loop {
                    playhead = 0
                } else {
                    isPlaying = false
                    return
                }
            }

            let framesAvailable = (pcm.count - playhead) / Int(channels)
            let framesThisPass = min(framesToQueue, framesAvailable)
            if framesThisPass <= 0 {
                break
            }

            queueScaled(from: playhead, sampleCount: framesThisPass * Int(channels))
            playhead += framesThisPass * Int(channels)
            framesToQueue -= framesThisPass
        }
    }

    private func queueScaled(from sampleIndex: Int, sampleCount: Int) {
        guard let stream else { return }
        var scaled = [Int16](repeating: 0, count: sampleCount)
        let isStereo = channels >= 2
        let monoGain = (leftVolume + rightVolume) * 0.5
        pcm.withUnsafeBufferPointer { src in
            scaled.withUnsafeMutableBufferPointer { dst in
                var isLeft = true
                for i in 0..<sampleCount {
                    let gain = isStereo ? (isLeft ? leftVolume : rightVolume) : monoGain
                    dst[i] = Int16(clamping: Int32(Float(src[sampleIndex + i]) * gain))
                    isLeft.toggle()
                }
            }
        }
        scaled.withUnsafeBytes { raw in
            _ = SDL_PutAudioStreamData(stream, raw.baseAddress, Int32(raw.count))
        }
    }
}

// Wrapper so `play(_:...)` above doesn't need SwSoundChannel to know about
// the private DecodedPCM type from the file-scope decoders.
struct DecodedPCMBuffer {
    var samples: [Int16]
    var channels: Int32
    var sampleRate: Int32
}

func loadDecodedPCM(_ spec: UnsafeMutablePointer<FSSpec>, isMP3: Bool) -> DecodedPCMBuffer? {
    guard let bytes = readWholeFile(spec) else { return nil }
    guard let decoded = decodePCM(bytes, isMP3: isMP3) else { return nil }
    return DecodedPCMBuffer(samples: decoded.samples, channels: decoded.channels, sampleRate: decoded.sampleRate)
}
