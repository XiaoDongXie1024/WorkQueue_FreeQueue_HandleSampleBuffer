//
//  XDXQueueProcess.h
//  CacheSampleBuffer
//
//  Created by 小东邪 on 08/01/2018.
//  Copyright © 2018 小东邪. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    XDXCustomWorkQueue,
    XDXCustomFreeQueue
} XDXCustomQueueType;

typedef struct XDXCustomQueueNode {
    void    *data;
    size_t  size;  // data size
    long    index;
    struct  XDXCustomQueueNode *next;
} XDXCustomQueueNode;

typedef struct XDXCustomQueue {
    int size;
    XDXCustomQueueType type;
    XDXCustomQueueNode *front;
    XDXCustomQueueNode *rear;
} XDXCustomQueue;

class XDXCustomQueueProcess {
    
private:
    pthread_mutex_t free_queue_mutex;
    pthread_mutex_t work_queue_mutex;
    
public:
    XDXCustomQueue *m_free_queue;
    XDXCustomQueue *m_work_queue;
    
    XDXCustomQueueProcess();
    ~XDXCustomQueueProcess();
    
    // Queue Operation
    void InitQueue(XDXCustomQueue *queue,
                   XDXCustomQueueType type);
    void EnQueue(XDXCustomQueue *queue,
                 XDXCustomQueueNode *node);
    XDXCustomQueueNode *DeQueue(XDXCustomQueue *queue);
    void ClearXDXCustomQueue(XDXCustomQueue *queue);
    void FreeNode(XDXCustomQueueNode* node);
    void ResetFreeQueue(XDXCustomQueue *workQueue, XDXCustomQueue *FreeQueue);
};


