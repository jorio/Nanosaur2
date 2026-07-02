#pragma once

// Lookup-table accessors for LoadLevel.swift. The tables themselves stay
// in LoadLevel.c: they're sparse designated-initializer arrays indexed by
// enum, which Swift has no literal syntax for.

Biome GetLevelBiome(int levelNum);
const char* GetLevelName(int levelNum);
const char* GetBiomeName(Biome biomeNum);
