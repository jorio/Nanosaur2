// Pick.swift - Port of Pick.c to Swift

private let gridSkipRange: Int32 = 2 // how many grid units away to just skip collisions between objects

private let maxSupertiles = (9 * 2 * 9 * 2) * 2 * 2 // MAX_SUPERTILES: (MAX_SUPERTILE_ACTIVE_RANGE*2 * MAX_SUPERTILE_ACTIVE_RANGE*2)*MAX_SPLITSCREENS * 2

@inline(__always) private func emVector3DMemberDot(_ nx: Float, _ ny: Float, _ nz: Float, _ p: OGLPoint3D) -> Float {
    (nx * p.x) + (ny * p.y) + (nz * p.z)
}

@inline(__always) private func emVector3DMemberDot(_ nx: Float, _ ny: Float, _ nz: Float, _ p: OGLVector3D) -> Float {
    (nx * p.x) + (ny * p.y) + (nz * p.z)
}

@inline(__always) private func oglIsZero(_ a: Float) -> Bool {
    (a >= -Float(EPS)) && (a <= Float(EPS))
}

@inline(__always) private func normalized(_ v: OGLVector3D) -> OGLVector3D {
    var input = v
    var output = OGLVector3D()
    withUnsafeMutablePointer(to: &input) { inPtr in
        withUnsafeMutablePointer(to: &output) { outPtr in
            OGLVector3D_Normalize(inPtr, outPtr)
        }
    }
    return output
}

@inline(__always) private func worldMeshesBase(_ n: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<MOVertexArrayData> {
    UnsafeMutableRawPointer(n.pointer(to: \.WorldMeshes)!).assumingMemoryBound(to: MOVertexArrayData.self)
}

@inline(__always) private func worldPlaneEQsBase(_ n: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<UnsafeMutablePointer<OGLPlaneEquation>?> {
    UnsafeMutableRawPointer(n.pointer(to: \.WorldPlaneEQs)!).assumingMemoryBound(to: UnsafeMutablePointer<OGLPlaneEquation>?.self)
}

// MARK: ======= RAY COLLISION ========

// MARK: - OGL: Do ray collision on objnodes

// Checks to see if the input ray hits any eligible and visible objNodes in the scene.
//
// INPUT: 	ray = world-space ray to collide with
//			statusFilter = STATUS_BIT flags used for filtering out objects we don't care about (like hidden or culled objects)
//			cTypes = which objects do we want to collide against?
//
// OUTPUT:  ObjNode of object picked or nil
//			worldHitCoord = world-space coords of the pick intersection
//			hitNormal = normal of the triangle we hit (or nil)
//			ray->distance = distance from ray origin to the intersection point
@c @implementation
public func OGL_DoRayCollision_ObjNodes(_ rayOpt: UnsafeMutablePointer<OGLRay>?, _ statusFilter: UInt32, _ cTypes: UInt32, _ worldHitCoord: UnsafeMutablePointer<OGLPoint3D>?, _ hitNormal: UnsafeMutablePointer<OGLVector3D>?) -> UnsafeMutablePointer<ObjNode>? {
    let ray = rayOpt!
    var bestObj: UnsafeMutablePointer<ObjNode>?
    var bestDist: Float = 1_000_000
    var hitPt = OGLPoint3D()
    var normal = OGLVector3D()

    var thisNodePtr = gFirstNodePtr

    while true {
        guard let thisNode = thisNodePtr else { break }

        // VERIFY NODE

        if thisNode.pointee.Slot >= UInt16(SLOT_OF_DUMB) { // stop here
            break
        }

        if thisNode.pointee.CType == UInt32(INVALID_NODE_FLAG) { // make sure the node is even valid
            thisNodePtr = thisNode.pointee.NextNode
            continue
        }
        if thisNode.pointee.StatusBits & statusFilter != 0 { // used to optionally filter out hidden stuff, etc.
            thisNodePtr = thisNode.pointee.NextNode
            continue
        }

        if thisNode.pointee.CType & cTypes != 0 { // only if pickable
            // IF THE PICK RAY HITS THE OBJECT'S BOUNDING SPHERE THEN SEE IF WE HIT THE GEOMETRY

            if OGL_DoesRayIntersectSphere(ray, &thisNode.pointee.Coord, Double(thisNode.pointee.BoundingSphereRadius), nil) {
                // NOW PARSE THE OBJNODE AND DO RAY-TRIANGLE TESTS TO SEE WHERE WE HIT

                switch Int(thisNode.pointee.Genre) {
                case SKELETON_GENRE:
                    if OGL_RayGetHitInfo_Skeleton(ray, thisNode, &hitPt, &normal) { // does ray intersect skeleton?
                        if ray.pointee.distance < bestDist { // is this the best hit so far?
                            bestDist = ray.pointee.distance
                            bestObj = thisNode
                            if let worldHitCoord {
                                worldHitCoord.pointee = hitPt
                            }
                            if let hitNormal {
                                hitNormal.pointee = normal
                            }
                        }
                    }

                case DISPLAY_GROUP_GENRE:
                    if OGL_RayGetHitInfo_DisplayGroup(ray, thisNode, &hitPt, &normal) != 0 { // does ray hit display group geometry?
                        if ray.pointee.distance < bestDist { // is this the best hit so far?
                            bestDist = ray.pointee.distance
                            bestObj = thisNode
                            if let worldHitCoord {
                                worldHitCoord.pointee = hitPt
                            }
                            if let hitNormal {
                                hitNormal.pointee = normal
                            }
                        }
                    }

                case CUSTOM_GENRE: // ignore this or do custom handling
                    break

                default:
                    SwFatal("OGL_DoRayCollision: unsupported genre")
                }
            }
        }

        thisNodePtr = thisNode.pointee.NextNode // next node
    }

    ray.pointee.distance = bestDist // return the best distance in the ray

    return bestObj
}

// MARK: - OGL: Do ray collision on terrain

// Determines if the input ray intersects any terrain geometry
//
// OUTPUT:
//			ray->distance = distance from ray origin to the intersection point
@c @implementation
public func OGL_DoRayCollision_Terrain(_ rayOpt: UnsafeMutablePointer<OGLRay>?, _ worldHitCoord: UnsafeMutablePointer<OGLPoint3D>?, _ terrainNormal: UnsafeMutablePointer<OGLVector3D>?) -> UInt8 {
    let ray = rayOpt!
    var returnTrue = false
    var hitCoord = OGLPoint3D()
    var hitNormalV = OGLVector3D()
    var bestDist: Float = 1_000_000

    let radius = Double(gTerrainSuperTileUnitSize * 0.5) // set the bounding sphere radius for all supertiles

    for i in 0..<maxSupertiles {
        let supertile = GetSuperTileMemoryEntry(Int32(i))!
        if supertile.pointee.mode == UInt8(SUPERTILE_MODE_FREE) { // look for used / active supertiles
            continue
        }

        // DOES RAY INTERSECT THIS SUPERTILE'S BOUNDING SPEHRE?

        var origin = OGLPoint3D() // get b-sphere coords
        origin.x = supertile.pointee.x
        origin.y = supertile.pointee.y
        origin.z = supertile.pointee.z

        var sphereHitPt = OGLPoint3D()
        if OGL_DoesRayIntersectSphere(ray, &origin, radius, &sphereHitPt) { // see if ray hits sphere
            // SEE IF RAY HIT ANY SUPERTILE TRIANGLES

            let mesh = supertile.pointee.meshData! // get ptr to supertile's mesh data

            if OGL_DoesRayIntersectMesh(ray, mesh, &hitCoord, &hitNormalV) {
                // IS THIS THE CLOSEST HIT?

                if ray.pointee.distance < bestDist {
                    // REMEMBER THIS HIT AS THE BEST SO FAR

                    bestDist = ray.pointee.distance
                    worldHitCoord?.pointee = hitCoord
                    terrainNormal?.pointee = hitNormalV
                    returnTrue = true
                }
            }
        }
    }

    if returnTrue {
        ray.pointee.distance = bestDist // return the distance to the best hit
    }

    return returnTrue ? 1 : 0
}

// MARK: - Is object in front of ray

@c @implementation
public func OGL_IsObjectInFrontOfRay(_ theNodeOpt: UnsafeMutablePointer<ObjNode>?, _ rayOpt: UnsafeMutablePointer<OGLRay>?) -> UInt8 {
    let theNode = theNodeOpt!
    let ray = rayOpt!
    var v = OGLVector3D()

    let x = theNode.pointee.Coord.x
    let y = theNode.pointee.Coord.y
    let z = theNode.pointee.Coord.z

    // FIRST JUST SEE IF THE OBJECT'S COORDS ARE IN FRONT

    v.x = x - ray.pointee.origin.x // calc vector from origin to object coords
    v.y = y - ray.pointee.origin.y
    v.z = z - ray.pointee.origin.z
    v = normalized(v)

    var dot = OGLVector3D_Dot(&v, &ray.pointee.direction) // calc angle between vectors
    if dot < 0.0 {
        return 1
    }

    // NOW SEE IF BOUNDING SPHERE IS ALSO IN FRONT OR NOT

    let r = theNode.pointee.BoundingSphereRadius
    var pt = OGLPoint3D()
    pt.x = x - (v.x * r) // calc point on bounding sphere
    pt.y = y - (v.y * r)
    pt.z = z - (v.z * r)

    v.x = pt.x - ray.pointee.origin.x // calc vector from origin to sphere coords
    v.y = pt.y - ray.pointee.origin.y
    v.z = pt.z - ray.pointee.origin.z
    v = normalized(v)

    dot = OGLVector3D_Dot(&v, &ray.pointee.direction) // calc angle between vectors
    if dot < 0.0 {
        return 1
    }

    return 0
}

// MARK: - OGL: Does ray intersect sphere

// Returns TRUE if the input ray intersects the input sphere.
// also returns the intersect point if intersectPt != nil
//
//			ray->distance = distance from ray origin to the intersection point
@discardableResult
private func OGL_DoesRayIntersectSphere(_ ray: UnsafeMutablePointer<OGLRay>, _ sphereCenter: UnsafeMutablePointer<OGLPoint3D>, _ sphereRadius: Double, _ intersectPt: UnsafeMutablePointer<OGLPoint3D>?) -> Bool {
    var sphereToRay = OGLVector3D()

    // Prepare to intersect
    //
    // First calculate the vector from the sphere to the ray origin, its
    // length squared, the projection of this vector onto the ray direction,
    // and the squared radius of the sphere.

    OGLPoint3D_Subtract(sphereCenter, &ray.pointee.origin, &sphereToRay)
    let l2 = OGLVector3D_Dot_NoPinDouble(&sphereToRay, &sphereToRay) // the dot of itself gives us the length squared
    let d = OGLVector3D_Dot_NoPinDouble(&sphereToRay, &ray.pointee.direction)
    let r2 = sphereRadius * sphereRadius

    // If the sphere is behind the ray origin, they don't intersect

    if (d < 0.0) && (l2 > r2) {
        return false
    }

    // Calculate the squared distance from the sphere center to the projection.
    // If it's greater than the radius then they don't intersect.

    let m2 = (l2 - (d * d))
    if m2 > r2 {
        return false
    }

    if let intersectPt {
        // Calculate the distance along the ray to the intersection point
        let q = (r2 - m2).squareRoot()
        let t: Double
        if l2 > r2 {
            t = d - q
        } else {
            t = d + q
        }

        // Calculate the intersection point
        intersectPt.pointee.x = ray.pointee.origin.x + ray.pointee.direction.x * Float(t)
        intersectPt.pointee.y = ray.pointee.origin.y + ray.pointee.direction.y * Float(t)
        intersectPt.pointee.z = ray.pointee.origin.z + ray.pointee.direction.z * Float(t)
    }

    return true
}

// MARK: - OGL: Ray get hit info: skeleton

// Called from above when we know we've picked a Skeleton objNode.
// Now we just need to parse thru all of the Skeleton's triangles and see if our pick ray hits any.
// Then we keep track of the closest hit coord and that's what we'll return.
@discardableResult
private func OGL_RayGetHitInfo_Skeleton(_ ray: UnsafeMutablePointer<OGLRay>, _ theNode: UnsafeMutablePointer<ObjNode>, _ worldHitCoord: UnsafeMutablePointer<OGLPoint3D>, _ hitNormal: UnsafeMutablePointer<OGLVector3D>?) -> Bool {
    var where_ = OGLPoint3D()
    var normal = OGLVector3D()
    var bestDist: Float = 1_000_000
    var gotHit = false

    // GET SKELETON DATA

    let skeleton = theNode.pointee.Skeleton!
    let numTriMeshes = Int(skeleton.pointee.skeletonDefinition!.pointee.numDecomposedTriMeshes)

    let buffNum = Int(gGameViewInfoPtr!.pointee.frameCount & 1)

    let deformedMeshesBase = UnsafeMutableRawPointer(skeleton.pointer(to: \.deformedMeshes)!).assumingMemoryBound(to: MOVertexArrayData.self)
    let deformedMeshesStride = Int(MAX_DECOMPOSED_TRIMESHES)

    // CHECK EACH MESH IN THE SKELETON

    for i in 0..<numTriMeshes {
        let mesh = deformedMeshesBase + (buffNum * deformedMeshesStride + i)
        if OGL_DoesRayIntersectMesh(ray, mesh, &where_, &normal) {
            // IS THIS INTERSECTION PT THE BEST ONE?

            if ray.pointee.distance < bestDist {
                bestDist = ray.pointee.distance
                worldHitCoord.pointee = where_ // pass back the intersection point since it's the best one we've found so far.
                hitNormal?.pointee = normal // pass back the triangle normal
            }

            gotHit = true
        }
    }

    ray.pointee.distance = bestDist // pass back the best dist too
    return gotHit
}

// MARK: - OGL: Does ray intersect mesh

// ASSUMES THE MESH IS IN WORLD COORDINATES ALREADY!!!
//
// Determines if the input ray intersects any of the triangles in the input mesh,
// and returns the closest intersection coordinate if so.  We also return the
// distance to the intersection point.
@discardableResult
private func OGL_DoesRayIntersectMesh(_ ray: UnsafeMutablePointer<OGLRay>, _ mesh: UnsafeMutablePointer<MOVertexArrayData>, _ intersectionPt: UnsafeMutablePointer<OGLPoint3D>, _ triangleNormal: UnsafeMutablePointer<OGLVector3D>?) -> Bool {
    let numTriangles = Int(mesh.pointee.numTriangles)
    var triPts = [OGLPoint3D](repeating: OGLPoint3D(), count: 3)
    var thisCoord = OGLPoint3D()
    var thisNormal = OGLVector3D()
    var gotHit = false
    var bestDist: Float = 1_000_000

    // SCAN THRU ALL TRIANGLES

    for t in 0..<numTriangles {
        // GET TRIANGLE POINTS

        let tri = mesh.pointee.triangles![t]
        triPts[0] = mesh.pointee.points![Int(tri.vertexIndices.0)]
        triPts[1] = mesh.pointee.points![Int(tri.vertexIndices.1)]
        triPts[2] = mesh.pointee.points![Int(tri.vertexIndices.2)]

        // DOES OUR RAY HIT IT?

        if OGL_RayIntersectsTriangle(&triPts, ray, &thisCoord, &thisNormal) != 0 {
            if ray.pointee.distance < bestDist { // is this hit closer than any previous hit?
                bestDist = ray.pointee.distance
                intersectionPt.pointee = thisCoord // pass back this intersection point since it's the best so far
                triangleNormal?.pointee = thisNormal // pass back the normal
            }
            gotHit = true
        }
    }

    if gotHit {
        ray.pointee.distance = bestDist // pass back the best distance
    }

    return gotHit
}

// MARK: - OGL: Ray get hit info: display group

// Called from above when we know we've picked a Display Group genre objNode.
// Now we just need to see if our pick ray hits anything.
// Then we keep track of the closest hit coord and that's what we'll return.
@c @implementation
public func OGL_RayGetHitInfo_DisplayGroup(_ rayOpt: UnsafeMutablePointer<OGLRay>?, _ theNodeOpt: UnsafeMutablePointer<ObjNode>?, _ worldHitCoord: UnsafeMutablePointer<OGLPoint3D>?, _ hitNormal: UnsafeMutablePointer<OGLVector3D>?) -> UInt8 {
    let ray = rayOpt!
    let theNode = theNodeOpt!
    var bestDist: Float = 1_000_000
    var point = OGLPoint3D()
    var normal = OGLVector3D()
    var gotHit = false

    // MAKE SURE WE HAVE WORLD-SPACE DATA FOR THIS OBJNODE

    if theNode.pointee.HasWorldPoints == 0 {
        CalcDisplayGroupWorldPoints(theNode)
    }

    // SCAN THRU OBJNODE'S WORLD-SPACE DATA FOR A HIT

    let worldMeshes = worldMeshesBase(theNode)
    for i in 0..<Int(MAX_MESHES_IN_MODEL) {
        if worldMeshes[i].points != nil { // does this mesh exist?
            if OGL_DoesRayIntersectMesh(ray, worldMeshes + i, &point, &normal) { // does the ray hit this mesh?
                if ray.pointee.distance < bestDist { // is this the closest hit so far?
                    bestDist = ray.pointee.distance // remember some info about this hit
                    worldHitCoord?.pointee = point // pass back hit pt
                    hitNormal?.pointee = normal // pass back hit normal
                    gotHit = true
                }
            }
        }
    }

    if gotHit {
        ray.pointee.distance = bestDist // pass back the best dist in the ray
        return 1
    }

    return 0
}

// MARK: -

// MARK: - OGL: Get world ray at screen point

// Used for picking, this function returns the world-space ray at the screenCoord.
// screenCoord is in grafPort coordinates.
@c @implementation
public func OGL_GetWorldRayAtScreenPoint(_ screenCoordOpt: UnsafeMutablePointer<OGLPoint2D>?, _ rayOpt: UnsafeMutablePointer<OGLRay>?) {
    let screenCoord = screenCoordOpt!
    let ray = rayOpt!

    // GET 3D COORDINATES @ BACK PLANE

    let realy = Float(gGameWindowHeight) - screenCoord.pointee.y - 1.0 // flip Y ([3] is the height value)

    let winPt = OGLPoint3D(x: screenCoord.pointee.x, y: realy, z: 1.0)
    let vpSize = OGLVector2D(x: Float(gGameWindowWidth), y: Float(gGameWindowHeight))
    let vpOffset = OGLPoint2D(x: 0, y: 0)
    var result = OGLPoint3D(x: 0, y: 0, z: 0)

    withUnsafePointer(to: winPt) { winPtPtr in
        withUnsafePointer(to: vpOffset) { vpOffsetPtr in
            withUnsafePointer(to: vpSize) { vpSizePtr in
                OGL_GluUnProject(
                    winPtPtr,
                    &gWorldToViewMatrix, // modelview
                    &gViewToFrustumMatrix, // projection
                    vpOffsetPtr,
                    vpSizePtr,
                    &result
                )
            }
        }
    }

    // CONVERT TO RAY

    ray.pointee.origin = gGameViewInfoPtr!.pointee.cameraPlacement.0.cameraLocation // ray origin @ camera location
    ray.pointee.direction.x = result.x - ray.pointee.origin.x // calc vector of ray
    ray.pointee.direction.y = result.y - ray.pointee.origin.y
    ray.pointee.direction.z = result.z - ray.pointee.origin.z
    OGLVector3D_Normalize(&ray.pointee.direction, &ray.pointee.direction) // normalize the ray vector
}

// MARK: - OGL: Ray intersects triangle

@c @implementation
public func OGL_RayIntersectsTriangle(_ trianglePoints: UnsafeMutablePointer<OGLPoint3D>?, _ rayOpt: UnsafeMutablePointer<OGLRay>?, _ intersectPt: UnsafeMutablePointer<OGLPoint3D>?, _ triangleNormal: UnsafeMutablePointer<OGLVector3D>?) -> UInt8 {
    let ray = rayOpt!
    let intersectPt = intersectPt!
    let triangleNormal = triangleNormal!
    var planeEquation = OGLPlaneEquation()

    // SEE IF RAY INTERSECTS THE TRIANGLE'S PLANE

    if OGL_DoesRayIntersectTrianglePlane(trianglePoints, ray, &planeEquation) != 0 {
        // CALC INTERSECTION POINT ON PLANE

        let distance = ray.pointee.distance
        intersectPt.pointee.x = ray.pointee.origin.x + ray.pointee.direction.x * distance
        intersectPt.pointee.y = ray.pointee.origin.y + ray.pointee.direction.y * distance
        intersectPt.pointee.z = ray.pointee.origin.z + ray.pointee.direction.z * distance

        // IS THE INTERSECTION PT INSIDE THE TRIANGLE?

        if OGLPoint3D_InsideTriangle3D(intersectPt, trianglePoints, &planeEquation.normal) != 0 {
            triangleNormal.pointee = planeEquation.normal // pass back the triangle's normal
            return 1
        }
    }

    return 0
}

// MARK: - OGL: Does ray intersect triangle plane

// Returns true if the input ray intersects the plane of the triangle.
@c @implementation
public func OGL_DoesRayIntersectTrianglePlane(_ triWorldPoints: UnsafePointer<OGLPoint3D>?, _ rayOpt: UnsafeMutablePointer<OGLRay>?, _ planeEquation: UnsafeMutablePointer<OGLPlaneEquation>?) -> UInt8 {
    let ray = rayOpt!
    let planeEquation = planeEquation!

    OGL_ComputeTrianglePlaneEquation(triWorldPoints, planeEquation)

    let nx = planeEquation.pointee.normal.x
    let ny = planeEquation.pointee.normal.y
    let nz = planeEquation.pointee.normal.z

    let nDotD = emVector3DMemberDot(nx, ny, nz, ray.pointee.direction)

    if oglIsZero(nDotD) { // is ray parallel to plane?
        return 0
    }

    let nDotO = emVector3DMemberDot(nx, ny, nz, ray.pointee.origin)

    let t = -(planeEquation.pointee.constant + nDotO) / nDotD
    if t < 0.0 {
        return 0
    }

    ray.pointee.distance = t

    return 1
}

// MARK: - OGL Point3D: Inside triangle 3D

// Is the point which lies on the triangle plane insdie the triangle?
@c @implementation
public func OGLPoint3D_InsideTriangle3D(_ point3D: UnsafePointer<OGLPoint3D>?, _ trianglePoints: UnsafePointer<OGLPoint3D>?, _ triangleNormal: UnsafePointer<OGLVector3D>?) -> UInt8 {
    var point2D = OGLPoint2D()
    var verts = [OGLPoint2D](repeating: OGLPoint2D(), count: 3)
    var intersects = false
    var alpha: Float, beta: Float

    OGLTriangle_3D2DComponentProjectionPoints(triangleNormal, point3D, trianglePoints, &point2D, &verts)

    let u0 = point2D.x - verts[0].x
    let v0 = point2D.y - verts[0].y
    let u1 = verts[1].x - verts[0].x
    let v1 = verts[1].y - verts[0].y
    let u2 = verts[2].x - verts[0].x
    let v2 = verts[2].y - verts[0].y

    if oglIsZero(u1) {
        beta = u0 / u2

        if (-Float(EPS) <= beta) && (beta <= (1.0 + Float(EPS))) { // Test if 0.0 <= beta <= 1.0
            alpha = (v0 - beta * v2) / v1
            intersects = (alpha >= -Float(EPS)) && ((alpha + beta) <= (1.0 + Float(EPS)))
        }
    } else {
        beta = (v0 * u1 - u0 * v1) / (v2 * u1 - u2 * v1)

        if (-Float(EPS) <= beta) && (beta <= (1.0 + Float(EPS))) { // Test if  0.0 <= beta <= 1.0
            alpha = (u0 - beta * u2) / u1

            intersects = (alpha >= -Float(EPS)) && ((alpha + beta) <= (1.0 + Float(EPS)))
        }
    }

    return intersects ? 1 : 0
}

// MARK: - OGL triangle 3D3D component projection points

private func OGLTriangle_3D2DComponentProjectionPoints(_ triangleNormal: UnsafePointer<OGLVector3D>!, _ point3D: UnsafePointer<OGLPoint3D>!, _ triPoints: UnsafePointer<OGLPoint3D>!, _ point2D: UnsafeMutablePointer<OGLPoint2D>!, _ verts2D: inout [OGLPoint2D]) {
    let xComp = fabsf(triangleNormal.pointee.x)
    let yComp = fabsf(triangleNormal.pointee.y)
    let zComp = fabsf(triangleNormal.pointee.z)

    if xComp > yComp {
        if xComp > zComp {
            // Maximal X
            point2D.pointee.x = point3D.pointee.y
            point2D.pointee.y = point3D.pointee.z

            verts2D[0].x = triPoints[0].y
            verts2D[0].y = triPoints[0].z

            verts2D[1].x = triPoints[1].y
            verts2D[1].y = triPoints[1].z

            verts2D[2].x = triPoints[2].y
            verts2D[2].y = triPoints[2].z
        } else {
            // Maximal Z
            point2D.pointee.x = point3D.pointee.x
            point2D.pointee.y = point3D.pointee.y

            verts2D[0].x = triPoints[0].x
            verts2D[0].y = triPoints[0].y

            verts2D[1].x = triPoints[1].x
            verts2D[1].y = triPoints[1].y

            verts2D[2].x = triPoints[2].x
            verts2D[2].y = triPoints[2].y
        }
    } else {
        if yComp > zComp {
            // Maximal Y
            point2D.pointee.x = point3D.pointee.z
            point2D.pointee.y = point3D.pointee.x

            verts2D[0].x = triPoints[0].z
            verts2D[0].y = triPoints[0].x

            verts2D[1].x = triPoints[1].z
            verts2D[1].y = triPoints[1].x

            verts2D[2].x = triPoints[2].z
            verts2D[2].y = triPoints[2].x
        } else {
            // Maximal Z
            point2D.pointee.x = point3D.pointee.x
            point2D.pointee.y = point3D.pointee.y

            verts2D[0].x = triPoints[0].x
            verts2D[0].y = triPoints[0].y

            verts2D[1].x = triPoints[1].x
            verts2D[1].y = triPoints[1].y

            verts2D[2].x = triPoints[2].x
            verts2D[2].y = triPoints[2].y
        }
    }
}

// MARK: -
// MARK: ==== LINE SEG COLLISION =====

// MARK: - OGL: Do line segment collision on objnodes

// Checks to see if the input line segment hits any eligible and visible objNodes in the scene.
//
// INPUT: 	p1/p2 = world-space line seg to collide with
//			cTypes = which objects do we want to collide against?
//
// OUTPUT:  ObjNode of object picked or nil
//			worldHitCoord = world-space coords of the pick intersection
//			ray->distance = distance from ray origin to the intersection point
@c @implementation
public func OGL_DoLineSegmentCollision_ObjNodes(_ lineSegOpt: UnsafePointer<OGLLineSegment>?, _ statusFilter: UInt32, _ cTypes: UInt32, _ worldHitCoord: UnsafeMutablePointer<OGLPoint3D>?, _ worldHitFaceNormal: UnsafeMutablePointer<OGLVector3D>?, _ distToHit: UnsafeMutablePointer<Float>?, _ allowBBoxTests: UInt8) -> UnsafeMutablePointer<ObjNode>? {
    let lineSeg = lineSegOpt!
    var bestObj: UnsafeMutablePointer<ObjNode>?
    var bestDist: Float = 10_000_000
    var hitPt = OGLPoint3D()
    var hitNormal = OGLVector3D()
    var hitDist: Float = 0

    // CALC GRID COORDS OF ENDPOINTS
    //
    // If we're allowing the estimated bbox tests then let's assume the line segment
    // is fairly short.  Therefore, we can do this grid test to quickly
    // eliminate objects which are not within grid range.
    //
    // Otherwise, if we're not allowing bbox tests (using sphere tests instead),
    // then the line segment might be very large, so don't do the grid test.

    let gridX1 = Int32(lineSeg.pointee.p1.x) / Int32(GRID_SIZE)
    let gridY1 = Int32(lineSeg.pointee.p1.y) / Int32(GRID_SIZE)
    let gridZ1 = Int32(lineSeg.pointee.p1.z) / Int32(GRID_SIZE)

    let gridX2 = Int32(lineSeg.pointee.p2.x) / Int32(GRID_SIZE)
    let gridY2 = Int32(lineSeg.pointee.p2.y) / Int32(GRID_SIZE)
    let gridZ2 = Int32(lineSeg.pointee.p2.z) / Int32(GRID_SIZE)

    // CALCULATE THE LINE SEGMENT VECTOR

    var segVec = OGLVector3D()
    segVec.x = lineSeg.pointee.p2.x - lineSeg.pointee.p1.x
    segVec.y = lineSeg.pointee.p2.y - lineSeg.pointee.p1.y
    segVec.z = lineSeg.pointee.p2.z - lineSeg.pointee.p1.z
    segVec = normalized(segVec)

    // TEST LINE SEGMENT AGAINST ALL OBJNODES

    var thisNodePtr = gFirstNodePtr

    while true {
        guard let thisNode = thisNodePtr else { break }

        // VERIFY NODE

        if thisNode.pointee.Slot >= UInt16(SLOT_OF_DUMB) { // stop here
            break
        }

        if thisNode.pointee.CType == UInt32(INVALID_NODE_FLAG) { // make sure the node is even valid
            thisNodePtr = thisNode.pointee.NextNode
            continue
        }

        if thisNode.pointee.StatusBits & statusFilter != 0 { // skip it if hidden
            thisNodePtr = thisNode.pointee.NextNode
            continue
        }

        if thisNode.pointee.CType & cTypes != 0 { // only if pickable
            // CHECK THE GRID TO SEE IF CLOSE ENOUGH

            if allowBBoxTests != 0 {
                if (abs(thisNode.pointee.GridX - gridX1) > gridSkipRange) && // either endpoint must be within n grid units
                    (abs(thisNode.pointee.GridX - gridX2) > gridSkipRange) {
                    thisNodePtr = thisNode.pointee.NextNode
                    continue
                }

                if (abs(thisNode.pointee.GridY - gridY1) > gridSkipRange) &&
                    (abs(thisNode.pointee.GridY - gridY2) > gridSkipRange) {
                    thisNodePtr = thisNode.pointee.NextNode
                    continue
                }

                if (abs(thisNode.pointee.GridZ - gridZ1) > gridSkipRange) &&
                    (abs(thisNode.pointee.GridZ - gridZ2) > gridSkipRange) {
                    thisNodePtr = thisNode.pointee.NextNode
                    continue
                }
            }

            // HANDLE SKELETONS, MODELS, & CUSTOM

            switch Int(thisNode.pointee.Genre) {
            case SKELETON_GENRE:
                var hit: Bool
                if allowBBoxTests != 0 {
                    hit = OGL_DoesLineSegmentIntersectBBox_Approx(lineSeg, &thisNode.pointee.WorldBBox) // skeletons have world-space bboxes which we can use for fast approx line->bbox tests
                } else {
                    hit = OGL_DoesLineSegmentIntersectSphere(lineSeg, &segVec, &thisNode.pointee.Coord, thisNode.pointee.BoundingSphereRadius, nil) != 0
                }

                if hit {
                    if OGL_LineSegGetHitInfo_Skeleton(lineSeg, thisNode, &hitPt, &hitNormal, &hitDist) { // does ray intersect skeleton?
                        if hitDist < bestDist { // is this the best hit so far?
                            bestDist = hitDist
                            bestObj = thisNode
                            worldHitCoord?.pointee = hitPt
                            worldHitFaceNormal?.pointee = hitNormal
                        }
                    }
                }

            case DISPLAY_GROUP_GENRE:
                if OGL_DoesLineSegmentIntersectSphere(lineSeg, &segVec, &thisNode.pointee.Coord, thisNode.pointee.BoundingSphereRadius, nil) != 0 {
                    if OGL_LineSegGetHitInfo_DisplayGroup(lineSeg, thisNode, &hitPt, &hitNormal, &hitDist) { // does line seg hit display group geometry?
                        if hitDist < bestDist { // is this the best hit so far?
                            bestDist = hitDist
                            bestObj = thisNode
                            worldHitCoord?.pointee = hitPt
                            worldHitFaceNormal?.pointee = hitNormal
                        }
                    }
                }

            case CUSTOM_GENRE: // ignore this or do custom handling
                break

            default:
                SwFatal("OGL_DoLineSegmentCollision: unsupported genre")
            }
        }

        thisNodePtr = thisNode.pointee.NextNode // next node
    }

    distToHit?.pointee = bestDist

    return bestObj
}

// MARK: - OGL: Line segment collision on terrain

// Determines if the input line segment intersects any terrain geometry
@c @implementation
public func OGL_LineSegmentCollision_Terrain(_ lineSegOpt: UnsafePointer<OGLLineSegment>?, _ worldHitCoord: UnsafeMutablePointer<OGLPoint3D>?, _ terrainNormal: UnsafeMutablePointer<OGLVector3D>?, _ distToHit: UnsafeMutablePointer<Float>?) -> UInt8 {
    let lineSeg = lineSegOpt!
    var hit = false
    var hitCoord = OGLPoint3D()
    var hitNormal = OGLVector3D()
    var dist: Float = 0
    var bestDist: Float = 10_000_000

    // CALCULATE THE LINE SEGMENT VECTOR

    var segVec = OGLVector3D()
    segVec.x = lineSeg.pointee.p2.x - lineSeg.pointee.p1.x
    segVec.y = lineSeg.pointee.p2.y - lineSeg.pointee.p1.y
    segVec.z = lineSeg.pointee.p2.z - lineSeg.pointee.p1.z
    segVec = normalized(segVec)

    // TEST AGAINST ALL SUPERTILES

    for i in 0..<maxSupertiles {
        let supertile = GetSuperTileMemoryEntry(Int32(i))!

        if supertile.pointee.mode == UInt8(SUPERTILE_MODE_FREE) { // look for used / active supertiles
            continue
        }

        // SEE IF LINE SEGMENT INTERSECTS THE BBOX
        //
        // Remember tha the bbox test is approximate and can give false positives!

        if !OGL_DoesLineSegmentIntersectBBox_Approx(lineSeg, &supertile.pointee.bBox) {
            continue
        }

        // SEE IF RAY HIT ANY SUPERTILE TRIANGLES

        let mesh = supertile.pointee.meshData! // get ptr to supertile's mesh data

        if !OGL_DoesLineSegIntersectMesh(lineSeg, &segVec, mesh, &hitCoord, &hitNormal, &dist) {
            continue
        }

        if dist < bestDist { // is this the closest hit so far?
            // REMEMBER THIS HIT AS THE BEST SO FAR

            bestDist = dist
            worldHitCoord?.pointee = hitCoord
            terrainNormal?.pointee = hitNormal

            hit = true
        }
    }

    distToHit?.pointee = bestDist // return the distance to the best hit

    return hit ? 1 : 0
}

// MARK: - OGL: Line segment collision on fences

// Determines if the input line segment intersects any fence geometry
@c @implementation
public func OGL_LineSegmentCollision_Fence(_ lineSegOpt: UnsafePointer<OGLLineSegment>?, _ worldHitCoord: UnsafeMutablePointer<OGLPoint3D>?, _ hitNormal: UnsafeMutablePointer<OGLVector3D>?, _ distToHit: UnsafeMutablePointer<Float>?) -> UInt8 {
    let lineSeg = lineSegOpt!
    var hit = false
    var hitCoord = OGLPoint3D()
    var normal = OGLVector3D()
    var dist: Float = 0
    var bestDist: Float = 10_000_000
    var bestNormal = OGLVector3D()

    gPickAllTrianglesAsDoubleSided = 1 // we want to allow backfaces to get hit

    // CALCULATE THE LINE SEGMENT VECTOR

    var segVec = OGLVector3D()
    segVec.x = lineSeg.pointee.p2.x - lineSeg.pointee.p1.x
    segVec.y = lineSeg.pointee.p2.y - lineSeg.pointee.p1.y
    segVec.z = lineSeg.pointee.p2.z - lineSeg.pointee.p1.z
    segVec = normalized(segVec)

    // TEST AGAINST ALL FENCES

    for i in 0..<Int(gNumFences) {
        // SKIP FENCE_TYPE_INVISIBLEBLOCKENEMY
        //
        // Nano2 source port HACK: Only projectiles (Turrets, Blaster, HeatSeeker, Bomb)
        // ever call this function, and we DON'T want them to explode when colliding with
        // an invisible fence.

        if gFenceList[i].type == UInt16(FENCE_TYPE_INVISIBLEBLOCKENEMY) {
            continue
        }

        // SEE IF LINE SEGMENT INTERSECTS THE BBOX
        //
        // Remember tha the bbox test is approximate and can give false positives!

        if !OGL_DoesLineSegmentIntersectBBox_Approx(lineSeg, &gFenceList[i].bBox) {
            continue
        }

        // SEE IF LINE HIT ANY FENCE TRIANGLES

        if !OGL_DoesLineSegIntersectMesh(lineSeg, &segVec, GetFenceTriMeshDataEntry(Int32(i), 0), &hitCoord, &normal, &dist) {
            continue
        }

        if dist < bestDist { // is this the closest hit so far?
            // REMEMBER THIS HIT AS THE BEST SO FAR

            bestDist = dist
            worldHitCoord?.pointee = hitCoord
            bestNormal = normal
            hit = true
        }
    }

    // SINCE FENCES DO DOUBLE-SIDED COLLISION WE NEED TO FIX THE NORMAL
    //
    //	When a backface is hit the normal is actually going to be facing away from the direction of our line segment.
    //	This might cause problems for certain hit functions, so we need to flip the normal to make sure it is always
    // 	facing the line segment vector (p1 -> p2).

    gPickAllTrianglesAsDoubleSided = 0 // always set this to FALSE when exiting!

    if let hitNormal { // only bother if we're returning the normal
        if OGLVector3D_Dot_NoPin(&segVec, &bestNormal) > 0.0 { // if normal is facing away then flip it
            bestNormal.x = -bestNormal.x
            bestNormal.y = -bestNormal.y
            bestNormal.z = -bestNormal.z
        }
        hitNormal.pointee = bestNormal // pass back the normal
    }

    // RETURN

    distToHit?.pointee = bestDist // return the distance to the best hit

    return hit ? 1 : 0
}

// MARK: - OGL: Line segment collision on water

// Determines if the input line segment intersects any water geometry
@c @implementation
public func OGL_LineSegmentCollision_Water(_ lineSegOpt: UnsafePointer<OGLLineSegment>?, _ worldHitCoord: UnsafeMutablePointer<OGLPoint3D>?, _ hitNormal: UnsafeMutablePointer<OGLVector3D>?, _ distToHit: UnsafeMutablePointer<Float>?) -> UInt8 {
    let lineSeg = lineSegOpt!
    var hit = false
    var hitCoord = OGLPoint3D()
    var normal = OGLVector3D()
    var dist: Float = 0
    var bestDist: Float = 10_000_000
    var bestNormal = OGLVector3D()

    gPickAllTrianglesAsDoubleSided = 1 // we want to allow backfaces to get hit

    // CALCULATE THE LINE SEGMENT VECTOR

    var segVec = OGLVector3D()
    segVec.x = lineSeg.pointee.p2.x - lineSeg.pointee.p1.x
    segVec.y = lineSeg.pointee.p2.y - lineSeg.pointee.p1.y
    segVec.z = lineSeg.pointee.p2.z - lineSeg.pointee.p1.z
    segVec = normalized(segVec)

    // TEST AGAINST ALL FENCES

    for i in 0..<Int(gNumWaterPatches) {
        // SEE IF LINE SEGMENT INTERSECTS THE BBOX
        //
        // Remember tha the bbox test is approximate and can give false positives!

        if !OGL_DoesLineSegmentIntersectBBox_Approx(lineSeg, GetWaterBBoxEntry(Int32(i))) {
            continue
        }

        // SEE IF LINE HIT ANY FENCE TRIANGLES

        if !OGL_DoesLineSegIntersectMesh(lineSeg, &segVec, GetWaterTriMeshDataEntry(Int32(i)), &hitCoord, &normal, &dist) {
            continue
        }

        if dist < bestDist { // is this the closest hit so far?
            // REMEMBER THIS HIT AS THE BEST SO FAR

            bestDist = dist
            worldHitCoord?.pointee = hitCoord
            bestNormal = normal
            hit = true
        }
    }

    // SINCE WATER DO DOUBLE-SIDED COLLISION WE NEED TO FIX THE NORMAL
    //
    //	When a backface is hit the normal is actually going to be facing away from the direction of our line segment.
    //	This might cause problems for certain hit functions, so we need to flip the normal to make sure it is always
    // 	facing the line segment vector (p1 -> p2).

    gPickAllTrianglesAsDoubleSided = 0 // always set this to FALSE when exiting!

    if let hitNormal { // only bother if we're returning the normal
        if OGLVector3D_Dot_NoPin(&segVec, &bestNormal) > 0.0 { // if normal is facing away then flip it
            bestNormal.x = -bestNormal.x
            bestNormal.y = -bestNormal.y
            bestNormal.z = -bestNormal.z
        }
        hitNormal.pointee = bestNormal // pass back the normal
    }

    // RETURN

    distToHit?.pointee = bestDist // return the distance to the best hit

    return hit ? 1 : 0
}

// MARK: - OGL: Pick and get hit info: display group

// Called from above when we know we've picked a Display Group genre objNode.
// Now we just need to traverse the Base Group, transform the data to world-space, and and see if our pick ray hits anything.
// Then we keep track of the closest hit coord and that's what we'll return.
@discardableResult
private func OGL_LineSegGetHitInfo_DisplayGroup(_ lineSeg: UnsafePointer<OGLLineSegment>, _ theNode: UnsafeMutablePointer<ObjNode>, _ worldHitCoord: UnsafeMutablePointer<OGLPoint3D>, _ hitNormal: UnsafeMutablePointer<OGLVector3D>?, _ distToHit: UnsafeMutablePointer<Float>) -> Bool {
    let bestDistInit: Float = 10_000_000
    var bestDist = bestDistInit
    var dist = bestDist
    var gotHit = false

    // CREATE A GLOBAL RAY

    var lineVec = OGLVector3D()
    lineVec.x = lineSeg.pointee.p2.x - lineSeg.pointee.p1.x
    lineVec.y = lineSeg.pointee.p2.y - lineSeg.pointee.p1.y
    lineVec.z = lineSeg.pointee.p2.z - lineSeg.pointee.p1.z
    lineVec = normalized(lineVec)

    // MAKE SURE WE HAVE WORLD-SPACE DATA FOR THIS OBJNODE

    if theNode.pointee.HasWorldPoints == 0 {
        CalcDisplayGroupWorldPoints(theNode)
    }

    // SCAN THRU OBJNODE'S WORLD-SPACE DATA FOR A HIT

    let worldMeshes = worldMeshesBase(theNode)
    let worldPlaneEQs = worldPlaneEQsBase(theNode)
    for i in 0..<Int(MAX_MESHES_IN_MODEL) {
        if worldMeshes[i].points != nil { // does this mesh exist?
            var coord = OGLPoint3D()
            var normal = OGLVector3D()
            if OGL_DoesLineSegIntersectMesh2(lineSeg, &lineVec, worldPlaneEQs[i], worldMeshes + i,
                                              &coord, &normal, &dist) { // does the line segment hit this mesh?
                if dist < bestDist { // is this the closest hit so far?
                    bestDist = dist // remember some info about this hit
                    worldHitCoord.pointee = coord
                    hitNormal?.pointee = normal
                    gotHit = true
                }
            }
        }
    }

    if gotHit {
        distToHit.pointee = bestDist
        return true
    }

    return false
}

// MARK: - OGL: Does line segment intersect sphere

// Returns TRUE if the input line seg intersects the input sphere.
// also returns the intersect point if intersectPt != nil
//
// This is actually a variant of the Ray intersect function above.  A line segment
// is actually 2 opposite rays.
@c @implementation
public func OGL_DoesLineSegmentIntersectSphere(_ lineSegOpt: UnsafePointer<OGLLineSegment>?, _ segVector: UnsafePointer<OGLVector3D>?, _ sphereCenter: UnsafeMutablePointer<OGLPoint3D>?, _ sphereRadius: Float, _ intersectPt: UnsafeMutablePointer<OGLPoint3D>?) -> UInt8 {
    let lineSeg = lineSegOpt!
    let sphereCenter = sphereCenter!
    var sphereToEndpoint = OGLVector3D()
    var rayDir = OGLVector3D()

    // DO THE USUAL RAY->SPHERE INTERSECT TEST WITH ONE OF THE ENDPOINTS

    // create a ray vector from p1 -> p2

    if let segVector {
        rayDir = segVector.pointee
    } else {
        rayDir.x = lineSeg.pointee.p2.x - lineSeg.pointee.p1.x
        rayDir.y = lineSeg.pointee.p2.y - lineSeg.pointee.p1.y
        rayDir.z = lineSeg.pointee.p2.z - lineSeg.pointee.p1.z
        rayDir = normalized(rayDir)
    }

    // Calculate the vector from the sphere to the p1 endpoint, its
    // length squared, the projection of this vector onto the ray direction,
    // and the squared radius of the sphere.

    withUnsafePointer(to: lineSeg.pointee.p1) { OGLPoint3D_Subtract(sphereCenter, $0, &sphereToEndpoint) }
    let l2 = OGLVector3D_Dot_NoPinDouble(&sphereToEndpoint, &sphereToEndpoint) // the dot of itself gives us the length squared
    let d = OGLVector3D_Dot_NoPinDouble(&sphereToEndpoint, &rayDir)
    let r2 = Double(sphereRadius) * Double(sphereRadius)

    // If the sphere is behind the endpoint, they don't intersect
    if d < 0.0 && l2 > r2 {
        return 0
    }

    // Calculate the squared distance from the sphere center to the projection.
    // If it's greater than the radius then they don't intersect.
    let m2 = (l2 - (d * d))
    if m2 > r2 {
        return 0
    }

    // NOW CHECK THE 2ND ENDPOINT
    //
    // We now know that the ray from p1->p2 does intersect
    // the sphere, so if p2 is also good then we have a line seg hit

    rayDir.x = -rayDir.x // negate the ray direction
    rayDir.y = -rayDir.y
    rayDir.z = -rayDir.z

    withUnsafePointer(to: lineSeg.pointee.p2) { OGLPoint3D_Subtract(sphereCenter, $0, &sphereToEndpoint) }
    let l2b = OGLVector3D_Dot_NoPinDouble(&sphereToEndpoint, &sphereToEndpoint) // the dot of itself gives us the length squared
    let db = OGLVector3D_Dot_NoPinDouble(&sphereToEndpoint, &rayDir)

    if db < 0.0 && l2b > r2 { // If the sphere is behind the endpoint, they don't intersect
        return 0
    }

    // WE HAVE A HIT

    if let intersectPt {
        let q = (r2 - m2).squareRoot() // Calculate the distance along the p1 ray to the intersection point
        let t: Double
        if l2 > r2 {
            t = d - q
        } else {
            t = d + q
        }

        // Calculate the intersection point
        intersectPt.pointee.x = lineSeg.pointee.p1.x + rayDir.x * Float(t)
        intersectPt.pointee.y = lineSeg.pointee.p1.y + rayDir.y * Float(t)
        intersectPt.pointee.z = lineSeg.pointee.p1.z + rayDir.z * Float(t)
    }

    return 1
}

// MARK: - OGL: Does line segment intersect bounding box (approx)

// IMPORTANT:  This function can return false positives!  In the case where a line segment crosses 2 planes
//				of any side of the bbox it will return TRUE when this might not actually be a hit.
//
//	So, this function should only be used when we know the line segments are relatively short.  This way any false
//	positives will not be a big deal;  the collision will proceed to do polygon-level tests which will throw out any
//	non-hits anyway.
private func OGL_DoesLineSegmentIntersectBBox_Approx(_ lineSeg: UnsafePointer<OGLLineSegment>, _ bbox: UnsafePointer<OGLBoundingBox>) -> Bool {
    let p1 = lineSeg.pointee.p1
    let p2 = lineSeg.pointee.p2

    if (p1.x < bbox.pointee.min.x) && (p2.x < bbox.pointee.min.x) { // if both endpoints are to the left of the bbox...
        return false
    }
    if (p1.x > bbox.pointee.max.x) && (p2.x > bbox.pointee.max.x) { // if both endpoints are to the right of the bbox...
        return false
    }

    if (p1.z < bbox.pointee.min.z) && (p2.z < bbox.pointee.min.z) { // if both endpoints are in back of the bbox...
        return false
    }
    if (p1.z > bbox.pointee.max.z) && (p2.z > bbox.pointee.max.z) { // if both endpoints are in front of the bbox...
        return false
    }

    if (p1.y < bbox.pointee.min.y) && (p2.y < bbox.pointee.min.y) { // if both endpoints are in under the bbox...
        return false
    }
    if (p1.y > bbox.pointee.max.y) && (p2.y > bbox.pointee.max.y) { // if both endpoints are in above the bbox...
        return false
    }

    return true
}

// MARK: - OGL: Does line segment intersect mesh

// ASSUMES THE MESH IS IN WORLD COORDINATES ALREADY!!!
//
// Determines if the global seg intersects any of the triangles in the input mesh,
// and returns the closest intersection coordinate if so.  We also return the
// distance to the intersection point.
@discardableResult
private func OGL_DoesLineSegIntersectMesh(_ lineSeg: UnsafePointer<OGLLineSegment>, _ lineVec: UnsafeMutablePointer<OGLVector3D>, _ mesh: UnsafeMutablePointer<MOVertexArrayData>, _ intersectionPt: UnsafeMutablePointer<OGLPoint3D>, _ hitNormal: UnsafeMutablePointer<OGLVector3D>?, _ distToIntersection: UnsafeMutablePointer<Float>) -> Bool {
    let numTriangles = Int(mesh.pointee.numTriangles)
    var triPts = [OGLPoint3D](repeating: OGLPoint3D(), count: 3)
    var thisCoord = OGLPoint3D()
    var gotHit = false
    var bestDist: Float = 10_000_000
    var distFromP1ToPlane: Float = 0
    var normal = OGLVector3D()

    // SCAN THRU ALL TRIANGLES

    for t in 0..<numTriangles {
        // GET TRIANGLE POINTS

        let tri = mesh.pointee.triangles![t]
        triPts[0] = mesh.pointee.points![Int(tri.vertexIndices.0)]
        triPts[1] = mesh.pointee.points![Int(tri.vertexIndices.1)]
        triPts[2] = mesh.pointee.points![Int(tri.vertexIndices.2)]

        // DOES OUR LINE HIT IT?

        if OGL_LineSegIntersectsTriangle(lineSeg, lineVec, &triPts, &thisCoord, &normal, &distFromP1ToPlane) {
            if distFromP1ToPlane < bestDist { // is this hit closer than any previous hit?
                bestDist = distFromP1ToPlane
                hitNormal?.pointee = normal // keep the best face normal that we've hit
                intersectionPt.pointee = thisCoord // pass back this intersection point since it's the best so far
            }
            gotHit = true
        }
    }

    distToIntersection.pointee = bestDist // pass back the best distance that we found (if any)
    return gotHit
}

// MARK: - OGL: Does line segment intersect mesh 2

// Same as above, but also takes an PlaneEQ array
@discardableResult
private func OGL_DoesLineSegIntersectMesh2(_ lineSeg: UnsafePointer<OGLLineSegment>, _ lineVec: UnsafeMutablePointer<OGLVector3D>, _ planeEQ: UnsafeMutablePointer<OGLPlaneEquation>?, _ mesh: UnsafeMutablePointer<MOVertexArrayData>, _ intersectionPt: UnsafeMutablePointer<OGLPoint3D>, _ hitNormal: UnsafeMutablePointer<OGLVector3D>?, _ distToIntersection: UnsafeMutablePointer<Float>) -> Bool {
    let planeEQ = planeEQ!
    let numTriangles = Int(mesh.pointee.numTriangles)
    var triPts = [OGLPoint3D](repeating: OGLPoint3D(), count: 3)
    var thisCoord = OGLPoint3D()
    var gotHit = false
    var bestDist: Float = 10_000_000
    var distFromP1ToPlane: Float = 0

    // SCAN THRU ALL TRIANGLES

    for t in 0..<numTriangles {
        // GET TRIANGLE POINTS

        let tri = mesh.pointee.triangles![t]
        triPts[0] = mesh.pointee.points![Int(tri.vertexIndices.0)]
        triPts[1] = mesh.pointee.points![Int(tri.vertexIndices.1)]
        triPts[2] = mesh.pointee.points![Int(tri.vertexIndices.2)]

        // DOES OUR RAY HIT IT?

        if OGL_LineSegIntersectsTriangle2(lineSeg, lineVec, planeEQ + t, &triPts, &thisCoord, &distFromP1ToPlane) {
            if distFromP1ToPlane < bestDist { // is this hit closer than any previous hit?
                bestDist = distFromP1ToPlane
                hitNormal?.pointee = planeEQ[t].normal // keep the best face normal that we've hit
                intersectionPt.pointee = thisCoord // pass back this intersection point since it's the best so far
            }
            gotHit = true
        }
    }

    distToIntersection.pointee = bestDist // pass back the best distance that we found (if any)
    return gotHit
}

// MARK: - OGL: Line segment intersects triangle

@discardableResult
private func OGL_LineSegIntersectsTriangle(_ lineSeg: UnsafePointer<OGLLineSegment>, _ lineVector: UnsafeMutablePointer<OGLVector3D>, _ trianglePoints: UnsafeMutablePointer<OGLPoint3D>, _ intersectPt: UnsafeMutablePointer<OGLPoint3D>, _ hitNormal: UnsafeMutablePointer<OGLVector3D>, _ distFromP1ToPlane: UnsafeMutablePointer<Float>) -> Bool {
    // SEE IF LINE SEG INTERSECTS THE TRIANGLE'S PLANE
    //
    // Calling this also computes the plane's normal and passes it back in hitNormal

    if OGL_DoesLineSegIntersectTrianglePlane(lineSeg, lineVector, trianglePoints, distFromP1ToPlane, hitNormal) {
        // CALC INTERSECTION POINT ON PLANE

        intersectPt.pointee.x = lineSeg.pointee.p1.x + lineVector.pointee.x * distFromP1ToPlane.pointee
        intersectPt.pointee.y = lineSeg.pointee.p1.y + lineVector.pointee.y * distFromP1ToPlane.pointee
        intersectPt.pointee.z = lineSeg.pointee.p1.z + lineVector.pointee.z * distFromP1ToPlane.pointee

        // IS THE INTERSECTION PT INSIDE THE TRIANGLE?

        if OGLPoint3D_InsideTriangle3D(intersectPt, trianglePoints, hitNormal) != 0 {
            return true
        }
    }

    return false
}

// MARK: - OGL: Line segment intersects triangle 2

// This version is passed the plane EQ
@discardableResult
private func OGL_LineSegIntersectsTriangle2(_ lineSeg: UnsafePointer<OGLLineSegment>, _ lineVector: UnsafeMutablePointer<OGLVector3D>, _ planeEQ: UnsafeMutablePointer<OGLPlaneEquation>, _ trianglePoints: UnsafeMutablePointer<OGLPoint3D>, _ intersectPt: UnsafeMutablePointer<OGLPoint3D>, _ distFromP1ToPlane: UnsafeMutablePointer<Float>) -> Bool {
    // SEE IF RAY INTERSECTS THE TRIANGLE'S PLANE

    if OGL_DoesLineSegIntersectTrianglePlane2(lineSeg, lineVector, planeEQ, distFromP1ToPlane) {
        // CALC INTERSECTION POINT ON PLANE

        intersectPt.pointee.x = lineSeg.pointee.p1.x + lineVector.pointee.x * distFromP1ToPlane.pointee
        intersectPt.pointee.y = lineSeg.pointee.p1.y + lineVector.pointee.y * distFromP1ToPlane.pointee
        intersectPt.pointee.z = lineSeg.pointee.p1.z + lineVector.pointee.z * distFromP1ToPlane.pointee

        // IS THE INTERSECTION PT INSIDE THE TRIANGLE?

        if OGLPoint3D_InsideTriangle3D(intersectPt, trianglePoints, &planeEQ.pointee.normal) != 0 {
            return true
        }
    }

    return false
}

// MARK: - OGL: Does line segment intersect triangle plane

// Returns true if the global line data intersects the plane of the triangle.
//
// NOTE:  this only works for DIRECTIONAL line segments!!!  Line segments which go from P1 to P2.
//		Line segments which intersect from P2 to P1 will not return a valid hit.
@discardableResult
private func OGL_DoesLineSegIntersectTrianglePlane(_ lineSeg: UnsafePointer<OGLLineSegment>, _ lineVec: UnsafeMutablePointer<OGLVector3D>, _ triWorldPoints: UnsafeMutablePointer<OGLPoint3D>, _ distFromP1ToPlane: UnsafeMutablePointer<Float>, _ planeNormal: UnsafeMutablePointer<OGLVector3D>?) -> Bool {
    var planeEQ = OGLPlaneEquation()

    // GET TRIANGLE NORMAL

    OGL_ComputeTrianglePlaneEquation(triWorldPoints, &planeEQ)
    let nx = planeEQ.normal.x
    let ny = planeEQ.normal.y
    let nz = planeEQ.normal.z

    planeNormal?.pointee = planeEQ.normal // pass the normal back

    // IS PARALLEL TO OR BEHIND PLANE?

    let nDotD = emVector3DMemberDot(nx, ny, nz, lineVec.pointee) // calc dot between normal and the line ray

    if !(gPickAllTrianglesAsDoubleSided != 0) { // do we want to allow backface hits?
        if nDotD >= Float(EPS) { // if ray is pointing away from plane then bail since we're not interested in rays hitting the triangle from behind
            return false
        }
    }

    let oneOverDotD = -1.0 / nDotD // let's calculate the -1/d since we use it twice

    // SEE IF RAY FROM P1 HITS IT

    var nDotO = emVector3DMemberDot(nx, ny, nz, lineSeg.pointee.p1)
    var t = (planeEQ.constant + nDotO) * oneOverDotD
    if t < 0.0 {
        return false
    }

    distFromP1ToPlane.pointee = t

    // IF P2 ALSO HITS THEN BOTH PTS ARE ON SAME SIDE OF PLANE, THUS NO INTERSECT
    //
    // We know that the vector from p1 intersects the plane, but if the same vector from p2
    // also hits the plane then both endpoints were in front of the plane.  The line segment
    // can only be intersecting the plane if each endpoint is on opposite sides.

    nDotO = emVector3DMemberDot(nx, ny, nz, lineSeg.pointee.p2)
    t = (planeEQ.constant + nDotO) * oneOverDotD
    if t >= 0.0 {
        return false
    }

    return true
}

// MARK: - OGL: Does line segment intersect triangle plane 2

// Returns true if the global line data intersects the plane of the triangle.
//
// NOTE:  this only works for DIRECTIONAL line segments!!!  Line segments which go from P1 to P2.
//		Line segments which intersect from P2 to P1 will not return a valid hit.
@discardableResult
private func OGL_DoesLineSegIntersectTrianglePlane2(_ lineSeg: UnsafePointer<OGLLineSegment>, _ lineVec: UnsafeMutablePointer<OGLVector3D>, _ planeEQ: UnsafeMutablePointer<OGLPlaneEquation>, _ distFromP1ToPlane: UnsafeMutablePointer<Float>) -> Bool {
    let nx = planeEQ.pointee.normal.x
    let ny = planeEQ.pointee.normal.y
    let nz = planeEQ.pointee.normal.z

    // IS PARALLEL TO OR BEHIND PLANE?

    let nDotD = emVector3DMemberDot(nx, ny, nz, lineVec.pointee) // calc dot between normal and the line ray
    if !(gPickAllTrianglesAsDoubleSided != 0) { // do we want to allow backface hits?
        if nDotD >= Float(EPS) { // if ray is pointing away from plane then bail since we're not interested in rays hitting the triangle from behind
            return false
        }
    }

    let oneOverDotD = -1.0 / nDotD // let's calculate the -1/d since we use it twice

    // SEE IF RAY FROM P1 HITS IT

    var nDotO = emVector3DMemberDot(nx, ny, nz, lineSeg.pointee.p1)
    var t = (planeEQ.pointee.constant + nDotO) * oneOverDotD
    if t < 0.0 {
        return false
    }

    distFromP1ToPlane.pointee = t

    // IF P2 ALSO HITS THEN BOTH PTS ARE ON SAME SIDE OF PLANE, THUS NO INTERSECT
    //
    // We know that the vector from p1 intersects the plane, but if the same vector from p2
    // also hits the plane then both endpoints were in front of the plane.  The line segment
    // can only be intersecting the plane if each endpoint is on opposite sides.

    nDotO = emVector3DMemberDot(nx, ny, nz, lineSeg.pointee.p2)
    t = (planeEQ.pointee.constant + nDotO) * oneOverDotD
    if t >= 0.0 {
        return false
    }

    return true
}

// MARK: - OGL: Line segment get hit info: skeleton

// Called from above when we know we've picked a Skeleton objNode.
// Now we just need to parse thru all of the Skeleton's triangles and see if our line seg hits any.
// Then we keep track of the closest hit coord and that's what we'll return.
@discardableResult
private func OGL_LineSegGetHitInfo_Skeleton(_ lineSeg: UnsafePointer<OGLLineSegment>, _ theNode: UnsafeMutablePointer<ObjNode>, _ worldHitCoord: UnsafeMutablePointer<OGLPoint3D>, _ hitNormal: UnsafeMutablePointer<OGLVector3D>?, _ hitDist: UnsafeMutablePointer<Float>) -> Bool {
    var where_ = OGLPoint3D()
    var thisDist: Float = 0
    var bestDist: Float = 100_000_000
    var gotHit = false
    var thisNormal = OGLVector3D()
    var lineVec = OGLVector3D()

    // CREATE A GLOBAL RAY

    lineVec.x = lineSeg.pointee.p2.x - lineSeg.pointee.p1.x
    lineVec.y = lineSeg.pointee.p2.y - lineSeg.pointee.p1.y
    lineVec.z = lineSeg.pointee.p2.z - lineSeg.pointee.p1.z
    lineVec = normalized(lineVec)

    // GET SKELETON DATA

    let skeleton = theNode.pointee.Skeleton!
    let numTriMeshes = Int(skeleton.pointee.skeletonDefinition!.pointee.numDecomposedTriMeshes)

    let buffNum = Int(gGameViewInfoPtr!.pointee.frameCount & 1)

    let deformedMeshesBase = UnsafeMutableRawPointer(skeleton.pointer(to: \.deformedMeshes)!).assumingMemoryBound(to: MOVertexArrayData.self)
    let deformedMeshesStride = Int(MAX_DECOMPOSED_TRIMESHES)

    // CHECK EACH MESH IN THE SKELETON

    for i in 0..<numTriMeshes {
        let mesh = deformedMeshesBase + (buffNum * deformedMeshesStride + i)
        if OGL_DoesLineSegIntersectMesh(lineSeg, &lineVec, mesh, &where_, &thisNormal, &thisDist) {
            // IS THIS INTERSECTION PT THE BEST ONE?

            if thisDist < bestDist {
                bestDist = thisDist
                worldHitCoord.pointee = where_ // pass back the intersection point since it's the best one we've found so far.
                hitNormal?.pointee = thisNormal
            }

            gotHit = true
        }
    }

    hitDist.pointee = bestDist

    return gotHit
}

// MARK: -
// MARK: ====== SPHERE COLLISION =======

// MARK: - OGL: Do sphere collision on objnodes

// Checks to see if the input bounding sphere hits any eligible objNodes in the scene.
@c @implementation
public func OGL_DoSphereCollision_ObjNodes(_ sphereOpt: UnsafePointer<OGLBoundingSphere>?, _ statusFilter: UInt32, _ cTypes: UInt32) -> UnsafeMutablePointer<ObjNode>? {
    let sphere = sphereOpt!
    var sphere2 = OGLBoundingSphere()

    // CALC GRID COORDS OF ENDPOINTS

    let gridX = Int32(sphere.pointee.origin.x) / Int32(GRID_SIZE)
    let gridY = Int32(sphere.pointee.origin.y) / Int32(GRID_SIZE)
    let gridZ = Int32(sphere.pointee.origin.z) / Int32(GRID_SIZE)

    // TEST SPHERE SEGMENT AGAINST ALL OBJNODES

    var thisNodePtr = gFirstNodePtr

    while true {
        guard let thisNode = thisNodePtr else { break }

        // VERIFY NODE

        if thisNode.pointee.Slot >= UInt16(SLOT_OF_DUMB) { // stop here
            break
        }

        if thisNode.pointee.CType == UInt32(INVALID_NODE_FLAG) { // make sure the node is even valid
            thisNodePtr = thisNode.pointee.NextNode
            continue
        }

        if thisNode.pointee.StatusBits & statusFilter != 0 { // skip it if hidden
            thisNodePtr = thisNode.pointee.NextNode
            continue
        }

        if thisNode.pointee.CType & cTypes != 0 { // only if pickable
            // CHECK THE GRID TO SEE IF CLOSE ENOUGH

            if abs(thisNode.pointee.GridX - gridX) > gridSkipRange { // sphere origin must be within grid range of object's center
                thisNodePtr = thisNode.pointee.NextNode
                continue
            }

            if abs(thisNode.pointee.GridY - gridY) > gridSkipRange {
                thisNodePtr = thisNode.pointee.NextNode
                continue
            }

            if abs(thisNode.pointee.GridZ - gridZ) > gridSkipRange {
                thisNodePtr = thisNode.pointee.NextNode
                continue
            }

            // DO THE BOUNDING SPHERES INTERSECT?

            sphere2.radius = thisNode.pointee.BoundingSphereRadius // build a sphere for the target node
            sphere2.origin = thisNode.pointee.Coord

            if OGL_DoesSphereIntersectSphere(sphere, &sphere2) {
                // HANDLE SKELETONS, MODELS, & CUSTOM

                switch Int(thisNode.pointee.Genre) {
                case SKELETON_GENRE:
                    if OGL_DoesSkeletonIntersectSphere(sphere, thisNode) { // does sphere intersect skeleton?
                        return thisNode
                    }

                case DISPLAY_GROUP_GENRE:
                    if OGL_DoesDisplayGroupIntersectSphere(sphere, thisNode) { // does sphere hit display group geometry?
                        return thisNode
                    }

                case CUSTOM_GENRE: // ignore this or do custom handling
                    break

                default:
                    SwFatal("OGL_DoSphereCollision_ObjNodes: unsupported genre")
                }
            }
        }

        thisNodePtr = thisNode.pointee.NextNode // next node
    }

    return nil
}

// MARK: - OGL: Does skeleton intersect sphere

private func OGL_DoesSkeletonIntersectSphere(_ sphere: UnsafePointer<OGLBoundingSphere>, _ theNode: UnsafeMutablePointer<ObjNode>) -> Bool {
    // GET SKELETON DATA

    let skeleton = theNode.pointee.Skeleton!
    let numTriMeshes = Int(skeleton.pointee.skeletonDefinition!.pointee.numDecomposedTriMeshes)
    let buffNum = Int(gGameViewInfoPtr!.pointee.frameCount & 1)

    let deformedMeshesBase = UnsafeMutableRawPointer(skeleton.pointer(to: \.deformedMeshes)!).assumingMemoryBound(to: MOVertexArrayData.self)
    let deformedMeshesStride = Int(MAX_DECOMPOSED_TRIMESHES)

    // CHECK EACH MESH IN THE SKELETON

    for i in 0..<numTriMeshes {
        let mesh = deformedMeshesBase + (buffNum * deformedMeshesStride + i)
        if OGL_DoesSphereIntersectMesh(sphere, mesh) {
            return true
        }
    }

    return false
}

// MARK: - OGL: Does display group intersect sphere

private func OGL_DoesDisplayGroupIntersectSphere(_ sphere: UnsafePointer<OGLBoundingSphere>, _ theNode: UnsafeMutablePointer<ObjNode>) -> Bool {
    // MAKE SURE WE HAVE WORLD-SPACE DATA FOR THIS OBJNODE

    if theNode.pointee.HasWorldPoints == 0 {
        CalcDisplayGroupWorldPoints(theNode)
    }

    // SCAN THRU OBJNODE'S WORLD-SPACE DATA FOR A HIT

    let worldMeshes = worldMeshesBase(theNode)
    for i in 0..<Int(MAX_MESHES_IN_MODEL) {
        if worldMeshes[i].points != nil { // does this mesh exist?
            if OGL_DoesSphereIntersectMesh(sphere, worldMeshes + i) { // does the sphere hit this mesh?
                return true
            }
        }
    }

    return false
}

// MARK: - OGL: Does sphere intersect mesh

// ASSUMES THE MESH IS IN WORLD COORDINATES ALREADY!!!
private func OGL_DoesSphereIntersectMesh(_ sphere: UnsafePointer<OGLBoundingSphere>, _ mesh: UnsafeMutablePointer<MOVertexArrayData>) -> Bool {
    let numPoints = Int(mesh.pointee.numPoints)

    // SCAN THRU ALL POINTS

    for p in 0..<numPoints {
        // IS THE POINT IN THE SPHERE?

        if OGL_IsPointInSphere(&mesh.pointee.points![p], sphere) {
            return true
        }
    }

    return false
}

// MARK: - OGL: Does sphere intersect sphere

private func OGL_DoesSphereIntersectSphere(_ sphere1: UnsafePointer<OGLBoundingSphere>, _ sphere2: UnsafePointer<OGLBoundingSphere>) -> Bool {
    var v = OGLVector3D()

    v.x = sphere1.pointee.origin.x - sphere2.pointee.origin.x // calc vector between origins
    v.y = sphere1.pointee.origin.y - sphere2.pointee.origin.y
    v.z = sphere1.pointee.origin.z - sphere2.pointee.origin.z
    let d2 = (v.x * v.x) + (v.y * v.y) + (v.z * v.z) // calculate distance squared between origins

    var rd = sphere1.pointee.radius + sphere2.pointee.radius // calc lenght of both radii
    rd *= rd // square it

    return d2 < rd // is distance between origins less than sum of radii?
}

// MARK: - OGL: Is point in sphere

private func OGL_IsPointInSphere(_ p: UnsafePointer<OGLPoint3D>, _ sphere: UnsafePointer<OGLBoundingSphere>) -> Bool {
    var v = OGLVector3D()

    v.x = sphere.pointee.origin.x - p.pointee.x // calc vector between points
    v.y = sphere.pointee.origin.y - p.pointee.y
    v.z = sphere.pointee.origin.z - p.pointee.z

    let d2 = (v.x * v.x) + (v.y * v.y) + (v.z * v.z) // calculate distance squared

    let r2 = sphere.pointee.radius * sphere.pointee.radius // calc radius squared

    return d2 < r2
}
