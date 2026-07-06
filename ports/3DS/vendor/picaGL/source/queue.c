#include "internal.h"

void _queueWaitAndClear()
{
	gxCmdQueueWait (&pglState->gxQueue, -1);
	gxCmdQueueStop (&pglState->gxQueue);
	gxCmdQueueClear(&pglState->gxQueue);
}

void _queueRun(bool async)
{
	gxCmdQueueRun(&pglState->gxQueue);
	
	if(!async)
		_queueWaitAndClear();
}