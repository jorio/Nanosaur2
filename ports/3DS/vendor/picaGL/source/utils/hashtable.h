#ifndef __HASHTABLE_H__
#define __HASHTABLE_H__

#define HASH_SIZE 32

typedef struct HashEntry_s {
	unsigned long key;
	void *data;
	struct HashEntry_s *next;
} HashEntry;

typedef struct HashTable_s {
	HashEntry *buckets[HASH_SIZE];
	unsigned long maxKey;
} HashTable;

void *hashTableGet(const HashTable *table, unsigned long key);
void hashTableInsert(HashTable *table, unsigned long key, void *value);
void *hashTableRemove(HashTable *table, unsigned long key);

unsigned long hashTableUniqueKey(const HashTable *table);

#endif