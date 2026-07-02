//
// shards.h
//

#ifndef __SHARDS_H
#define __SHARDS_H

typedef enum SWIFT_FLAG_ENUM ShardMode
{
	SHARD_MODE_UPTHRUST SWIFT_NAME(upthrust) = 1,
	SHARD_MODE_HEAVYGRAVITY SWIFT_NAME(heavyGravity) = (1<<1),
	SHARD_MODE_BOUNCE SWIFT_NAME(bounce) = (1<<2),
	SHARD_MODE_FROMORIGIN SWIFT_NAME(fromOrigin) = (1<<3)

} ShardMode;



void InitShardSystem(void);
void ExplodeGeometry(ObjNode *theNode, float boomForce, ShardMode particleMode, long particleDensity, float particleDecaySpeed);


#endif