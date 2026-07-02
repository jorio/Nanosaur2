#pragma once

#pragma clang assume_nonnull begin

ObjNode* MakeQuadMeshObject(NewObjectDefinitionType* newObjDef, int maxNumQuads, MOMaterialObject* _Nullable material);
void ReallocateQuadMesh(MOVertexArrayData* mesh, int numQuads);
MOVertexArrayData* GetQuadMeshWithin(ObjNode* theNode);

#pragma clang assume_nonnull end
