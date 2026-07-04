// MiscEffects.swift - Port of MiscEffects.c to Swift

private let cMoveShockwaveRing: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNode in
    guard let theNode = theNode else { return }
    let fps = gFramesPerSecondFrac
    let speed = theNode.pointee.SpecialF.0

    // FADE OUT
    theNode.pointee.ColorFilter.a -= fps * 1.5 * speed
    if theNode.pointee.ColorFilter.a <= 0.0 {
        DeleteObject(theNode)
        return
    }

    // SCALE
    theNode.pointee.Scale.z += fps * 15.0 * speed
    theNode.pointee.Scale.y = theNode.pointee.Scale.z
    theNode.pointee.Scale.x = theNode.pointee.Scale.z

    UpdateObjectTransforms(theNode)
}

func InitEffects() {
    InitParticleSystem()
    InitConfettiManager()
    InitShardSystem()

    // SET SPRITE BLENDING FLAGS
    BlendASprite(Int32(SPRITE_GROUP_PARTICLES), Int32(PARTICLE_SObjType_Splash))
}

func MakeShockwaveRing(_ coord: UnsafeMutablePointer<OGLPoint3D>, _ scale: Float) -> UnsafeMutablePointer<ObjNode> {
    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_GLOBAL)
    def.type = UInt8(GLOBAL_ObjType_ShockwaveRing)
    def.scale = scale
    def.coord = coord.pointee
    def.flags = UInt32(STATUS_BIT_GLOW | STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOTEXTUREWRAP | STATUS_BIT_NOZWRITES)
    def.slot = Int16(SLOT_OF_DUMB + 20)
    def.moveCall = cMoveShockwaveRing
    def.rot = RandomFloat() * SwPI2

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.Rot.x = RandomFloat() * SwPI2
    newObj.pointee.Rot.z = RandomFloat() * SwPI2
    UpdateObjectTransforms(newObj)

    newObj.pointee.ColorFilter.a = 1.5

    newObj.pointee.SpecialF.0 = 1.0 + RandomFloat()

    return newObj
}
