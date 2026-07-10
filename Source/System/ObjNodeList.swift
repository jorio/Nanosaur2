// ObjNodeList.swift - Swift Sequence over the master object linked list
// (gEngine.objects.firstNodePtr -> NextNode), replacing the hand-rolled C-style
// `var thisNodePtr = gEngine.objects.firstNodePtr; while ... { ... thisNodePtr =
// node.pointee.NextNode }` walks that appeared at ~20 call sites.
//
// FOR READ-ONLY WALKS ONLY. Loop bodies must not delete nodes (directly or
// through callbacks that might). Two reasons:
//
// 1. Deleting the CURRENT node is memory-safe here (the iterator snapshots
//    NextNode before yielding, and deleted nodes stay readable until
//    FlushObjectDeleteQueue anyway) - but it CHANGES traversal semantics
//    versus the legacy C-style loops this replaces: those read
//    `node.pointee.NextNode` AFTER the body, and DeleteObject ->
//    DetachObject nulls the deleted node's own NextNode ("seal links"), so
//    a legacy walk STOPS after a body deletes its current node, whereas
//    this iterator would keep going. Preserving that quirk is why
//    CauseBombShockwaveDamage (whose HitByWeaponHandler callbacks can
//    delete the hit node) keeps its raw loop.
// 2. Deleting OTHER nodes (including the snapshotted next one) needs the
//    gEngine.objects.nextNode-global fixup machinery that only MoveObjects has
//    (DetachObject patches gEngine.objects.nextNode when the pending next node is the one
//    being deleted). MoveObjects and DrawObjects therefore keep their
//    bespoke loops.
//
// NextNode is the MASTER list linkage (all active objects, sorted by Slot).
// It is unrelated to ChainNode (per-object attachment chains, walked by
// HideObjectChain etc.) - this type intentionally does not cover those.

struct ObjNodeList: Sequence, IteratorProtocol {
    private var nextUp: UnsafeMutablePointer<ObjNode>?
    private let stopAtDumbSlot: Bool

    fileprivate init(from first: UnsafeMutablePointer<ObjNode>?, stopAtDumbSlot: Bool) {
        self.nextUp = first
        self.stopAtDumbSlot = stopAtDumbSlot
    }

    mutating func next() -> UnsafeMutablePointer<ObjNode>? {
        guard let node = nextUp else { return nil }
        if stopAtDumbSlot, node.pointee.Slot >= UInt16(SLOT_OF_DUMB) {
            nextUp = nil
            return nil
        }
        nextUp = node.pointee.NextNode // snapshot BEFORE yielding: body may delete `node`
        return node
    }
}

/// Every active object in the master list, in slot order.
var allObjectNodes: ObjNodeList {
    ObjNodeList(from: gEngine.objects.firstNodePtr, stopAtDumbSlot: false)
}

/// The "usable" prefix of the master list: stops before the first node with
/// `Slot >= SLOT_OF_DUMB` (the sentinel slot separating gameplay objects
/// from HUD/overlay/system nodes) - the standard bound for gameplay scans
/// (collision, targeting, ray picking).
var usableObjectNodes: ObjNodeList {
    ObjNodeList(from: gEngine.objects.firstNodePtr, stopAtDumbSlot: true)
}
