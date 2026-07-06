#include <stdio.h>
#include <stdlib.h>
#include "hashtable.h"

#define HASH(k) ((k) % HASH_SIZE)

void *hashTableGet(const HashTable* table, unsigned long key)
{
	HashEntry *entry;

	if(key > table->maxKey)
		return NULL;

	for(entry = table->buckets[HASH(key)]; entry != NULL; entry= entry->next)
	{
		if(entry->key == key)
			return entry->data;
	}

	return NULL;
}

void hashTableInsert(HashTable *table, unsigned long key, void *value)
{
	HashEntry *entry;

	if(key <= table->maxKey)
	{
		for(entry=table->buckets[HASH(key)]; entry != NULL; entry=entry->next)
		{
			if(entry->key == key)
				entry->data = value;
		}
	}

	entry = malloc(sizeof(HashEntry));

	if(entry == NULL)
		return;

	entry->key = key;
	entry->data = value;
	entry->next = table->buckets[HASH(key)];
	table->buckets[HASH(key)] = entry;

	if(key > table->maxKey)
		table->maxKey = key;
}

void *hashTableRemove(HashTable *table, unsigned long key)
{
	HashEntry **entry_ptr;

	for (entry_ptr=&table->buckets[HASH(key)]; *entry_ptr!=NULL; entry_ptr=&(*entry_ptr)->next)
	{
		HashEntry *entry = *entry_ptr;

		if (entry->key == key) {
			void *ret = entry->data;
			*entry_ptr = entry->next;
			free(entry);
			return ret;
		}
	}

	return NULL;
}

unsigned long hashTableUniqueKey(const HashTable *table)
{
	return table->maxKey + 1;
}