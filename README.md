
## 利用C++ 设计缓存队列实现高效传输相机数据

### --------------------------------------------------------

## 需求：
#####  在做例如直播功能，有时我们可能要对相机捕获的图像数据做一些额外操作(Crop, Scale, 美颜等)但由于某些操作算法本身很耗时，以fps为30为例，如果某一帧处理较慢将可能会掉帧，所以设计一个缓冲队列先将捕获到的相机数据放入空闲队列中，随后程序中如果需要使用到相机数据则从工作队列中取出需要的数据。

### --------------------------------------------------------

#### 适用情况
- 在相机回调中对每一帧图像进行耗时操作(Crop, Scale...)
- 提升处理图像的效率
- 高效处理其他大数据量工作

#### 注意：本例通过设计使用C++ 队列来实现相机SampleBuffer的缓存工作，需要使用Objective-C 与 C++混编。

### --------------------------------------------------------

#### GitHub地址(附代码) : [C++缓存队列](https://github.com/ChengyangLi/WorkQueue_FreeQueue_HandleSampleBuffer)
#### 简书地址   : [C++缓存队列](https://www.jianshu.com/p/d6cd32acdc71)
#### 博客地址   : [C++缓存队列](https://chengyangli.github.io/2018/02/24/ios_cacheQueue/)
#### 掘金地址   : [C++缓存队列](https://juejin.im/post/5a91315c6fb9a063395c8944)

### --------------------------------------------------------

## 总体流程：
- 设置始终横屏，初始化相机参数设置代理
- 在捕捉相机数据的回调中将samplebuffer放入空闲队列
- 开启一条线程每隔10ms从工作队列中取出samplebuffer可在此对数据处理，处理完后将结点放回空闲队列

### --------------------------------------------------------

## 队列实现及解析

##### 1.原理
初始化固定数量的结点装入空闲队列，当相机回调产生数据后，从空闲队列头部取出一个结点将产生的每一帧图像buffer装入，然后入队到工作队列的尾部，处理buffer的线程从工作队列的头部取出一个结点中的Buffer进行处理，处理完成后会将装有次buffer的结点中data置空并重新放入空闲队列的头部以供下次使用。

![原理.png](http://upload-images.jianshu.io/upload_images/5086522-c9f1f354c1654de7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

> 解析
- 我们将空闲队列设计为头进头出，影响不大，因为我们每次只需要从空闲队列中取出一个空结点以供我们装入相机数据，所以没必要按照尾进头出的方式保证结点的顺序。
- 我们将工作队列设计为尾进头出，因为我们要确保从相机中捕获的数据是连续的，以便后期我们播放出来的画面也是连续的，所以工作队列必须保证尾进头出。
- 这样做我们相当于实现了用空闲队列当做缓冲队列，在正常情况下(fps=30,即每秒产生30帧数据，大约每33ms产生一帧数据)，如果在33ms内对数据进行的操作可以正常完成，则工作队列会保持始终为0或1，但是如果长期工作或遇到某一帧数据处理较慢的情况(即处理时间大于33ms)则工作队列的长度会增加，而正因为我们使用了这样的队列会保护那一帧处理慢的数据在仍然能够正常处理完。

##### 注意：这种情景仅用于短时间内仅有几帧数据处理较慢，如果比如1s内有20几帧数据都处理很慢则可能导致工作队列太长，则提现不出此队列的优势。

##### 2.结构
- 结点
```
typedef struct XDXCustomQueueNode {
    void    *data;
    size_t  size;  // data size
    long    index;
    struct  XDXCustomQueueNode *next;
} XDXCustomQueueNode;
```
结点中使用void *类型的data存放我们需要的sampleBuffer,使用index记录当前装入结点的sampleBuffer的索引，以便我们在取出结点时比较是否是按照顺序取出，结点中还装着同类型下一个结点的元素。

- 队列类型
```
typedef struct XDXCustomQueue {
    int size;
    XDXCustomQueueType type;
    XDXCustomQueueNode *front;
    XDXCustomQueueNode *rear;
} XDXCustomQueue;
```
队列中即为我们装载的结点数量，因为我们采用的是预先分配固定内存，所以工作队列与空闲队列的和始终不变(因为结点中的元素不在工作队列就在空闲队列)

- 类的设计
```
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
```
因为涉及到异步操作，所以需要对结点的操作加锁，使用时需要先初始化队列，然后定义了入队，出队，清除队列中元素，释放结点，重置空闲队列等操作。

##### 3.实现

- 初始化队列
```
const int XDXCustomQueueSize = 3;
XDXCustomQueueProcess::XDXCustomQueueProcess() {
    m_free_queue = (XDXCustomQueue *)malloc(sizeof(struct XDXCustomQueue));
    m_work_queue = (XDXCustomQueue *)malloc(sizeof(struct XDXCustomQueue));
    
    InitQueue(m_free_queue, XDXCustomFreeQueue);
    InitQueue(m_work_queue, XDXCustomWorkQueue);
    
    for (int i = 0; i < XDXCustomQueueSize; i++) {
        XDXCustomQueueNode *node = (XDXCustomQueueNode *)malloc(sizeof(struct XDXCustomQueueNode));
        node->data = NULL;
        node->size = 0;
        node->index= 0;
        this->EnQueue(m_free_queue, node);
    }
    
    pthread_mutex_init(&free_queue_mutex, NULL);
    pthread_mutex_init(&work_queue_mutex, NULL);
    
    NSLog(@"XDXCustomQueueProcess Init finish !");
}
```

假设空闲队列结点总数为3.首先为工作队列与空闲队列分配内存，其次对其分别进行初始化操作，具体过程可参考Demo,然后根据结点总数来为每个结点初始化分配内存，并将分配好内存的结点入队到空闲队列中。

##### 注意：结点的重用，我们仅仅初始化几个固定数量的结点，因为处理数据量较大，没有必要让程序始终做malloc与free，为了优化我们这里的队列相当于一个静态链表，即结点的复用，因为当结点在工作队列中使用完成后会将其中的数据置空并重新入队到空闲队列中，所以结点的总数始终保持不变。

- 入队Enqueue
```
void XDXCustomQueueProcess::EnQueue(XDXCustomQueue *queue, XDXCustomQueueNode *node) {
    if (queue == NULL) {
        NSLog(@"XDXCustomQueueProcess Enqueue : current queue is NULL");
        return;
    }
    
    if (node==NULL) {
        NSLog(@"XDXCustomQueueProcess Enqueue : current node is NULL");
        return;
    }
    
    node->next = NULL;
    
    if (XDXCustomFreeQueue == queue->type) {
        pthread_mutex_lock(&free_queue_mutex);
        
        if (queue->front == NULL) {
            queue->front = node;
            queue->rear  = node;
        }else {
            /*
             // tail in,head out
             freeQueue->rear->next = node;
             freeQueue->rear = node;
             */
            
            // head in,head out
            node->next = queue->front;
            queue->front = node;
        }
        queue->size += 1;
        NSLog(@"XDXCustomQueueProcess Enqueue : free queue size=%d",queue->size);
        pthread_mutex_unlock(&free_queue_mutex);
    }
    
    if (XDXCustomWorkQueue == queue->type) {
        pthread_mutex_lock(&work_queue_mutex);
        //TODO
        static long nodeIndex = 0;
        node->index=(++nodeIndex);
        if (queue->front == NULL) {
            queue->front = node;
            queue->rear  = node;
        }else {
            queue->rear->next   = node;
            queue->rear         = node;
        }
        queue->size += 1;
        NSLog(@"XDXCustomQueueProcess Enqueue : work queue size=%d",queue->size);
        pthread_mutex_unlock(&work_queue_mutex);
    }
}
```
如上所述，入队操作如果是空闲队列，则使用头进的方式，即始终让入队的结点在队列的头部，具体代码实现即让当前结点的next指向空闲队列的头结点，然后将当前结点变为空闲队列的头结点；如果入队操作是工作队列，则使用尾进的方式，并对结点的index赋值，以便我们在取出结点时可以打印Index是否连续，如果连续则说明入队时始终保持顺序入队。

> 这里使用了简单的数据结构中的知识，如有不懂可上网进行简单查阅

- 出队
```
XDXCustomQueueNode* XDXCustomQueueProcess::DeQueue(XDXCustomQueue *queue) {
    if (queue == NULL) {
        NSLog(@"XDXCustomQueueProcess DeQueue : current queue is NULL");
        return NULL;
    }
    
    const char *type = queue->type == XDXCustomWorkQueue ? "work queue" : "free queue";
    pthread_mutex_t *queue_mutex = ((queue->type == XDXCustomWorkQueue) ? &work_queue_mutex : &free_queue_mutex);
    XDXCustomQueueNode *element = NULL;
    
    pthread_mutex_lock(queue_mutex);
    element = queue->front;
    if(element == NULL) {
        pthread_mutex_unlock(queue_mutex);
        NSLog(@"XDXCustomQueueProcess DeQueue : The node is NULL");
        return NULL;
    }
    
    queue->front = queue->front->next;
    queue->size -= 1;
    pthread_mutex_unlock(queue_mutex);
    
    NSLog(@"XDXCustomQueueProcess DeQueue : %s size=%d",type,queue->size);
    return element;
}
```
出队操作无论空闲队列还是工作队列都是从头出，即取出当前队列头结点中的数据。

##### 注意：该结点为空与该结点中的数据为空不可混为一谈，如果该结点为空则说明没有从队列中取出结点，即空结点没有内存地址，而结点中的数据则为node->data,在本Demo中为相机产生的每一帧sampleBuffer数据。

- 重置空闲队列数据
```
void XDXCustomQueueProcess::ResetFreeQueue(XDXCustomQueue *workQueue, XDXCustomQueue *freeQueue) {
    if (workQueue == NULL) {
        NSLog(@"XDXCustomQueueProcess ResetFreeQueue : The WorkQueue is NULL");
        return;
    }
    
    if (freeQueue == NULL) {
        NSLog(@"XDXCustomQueueProcess ResetFreeQueue : The FreeQueue is NULL");
        return;
    }
    
    int workQueueSize = workQueue->size;
    if (workQueueSize > 0) {
        for (int i = 0; i < workQueueSize; i++) {
            XDXCustomQueueNode *node = DeQueue(workQueue);
            CFRelease(node->data);
            node->data = NULL;
            EnQueue(freeQueue, node);
        }
    }
    NSLog(@"XDXCustomQueueProcess ResetFreeQueue : The work queue size is %d, free queue size is %d",workQueue->size, freeQueue->size);
}
```
当我们将执行一些中断操作，例如从本View跳转到其他View，或进入后台等操作，我们需要将工作队列中的结点均置空然后重新放回空闲队列，这样可以保证我们最初申请的结点还均有效可用，保证结点不会丢失。

### --------------------------------------------------------

## 流程

##### 1.初始化相机相关参数
常规流程，Demo中有实现，在此不复述

##### 2.将samplebuffer放入空闲队列
设置相机代理后，在 `- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection` 方法中将samplebuffer装入空闲队列

```
- (void)addBufferToWorkQueueWithSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    XDXCustomQueueNode *node = _captureBufferQueue->DeQueue(_captureBufferQueue->m_free_queue);
    if (node == NULL) {
        NSLog(@"XDXCustomQueueProcess addBufferToWorkQueueWithSampleBuffer : Data in , the node is NULL !");
        return;
    }
    CFRetain(sampleBuffer);
    node->data = sampleBuffer;
    _captureBufferQueue->EnQueue(_captureBufferQueue->m_work_queue, node);

    NSLog(@"XDXCustomQueueProcess addBufferToWorkQueueWithSampleBuffer : Data in ,  work size = %d, free size = %d !",_captureBufferQueue->m_work_queue->size, _captureBufferQueue->m_free_queue->size);
}

```

> 注意：因为相机回调中捕捉的sampleBuffer是有生命周期的所以需要手动CFRetain一下使我们队列中的结点持有它。

##### 3.开启一条线程处理队列中的Buffer
使用pthread创建一条线程，每隔10ms取一次数据,我们可以在此对取到的数据进行我们想要的操作，操作完成后再将清空释放sampleBuffer再将其装入空闲队列供我们循环使用。

```
- (void)handleCacheThread {
    while (true) {
        // 从队列取出在相机回调中放入队列的线程
        XDXCustomQueueNode *node = _captureBufferQueue->DeQueue(_captureBufferQueue->m_work_queue);
        if (node == NULL) {
            NSLog(@"Crop handleCropThread : Data node is NULL");
            usleep(10*1000);
            continue;
        }
        
        CMSampleBufferRef sampleBuffer     = (CMSampleBufferRef)node->data;
        // 打印结点的index，如果连续则说明在相机回调中放入的samplebuffer是连续的
        NSLog(@"Test index : %ld",node->index);
        
        /* 可在此处理从队列中拿到的Buffer，用完后记得释放内存并将结点重新放回空闲队列
         * ........
         */
        
        CFRelease(sampleBuffer);
        node->data = NULL;
        _captureBufferQueue->EnQueue(_captureBufferQueue->m_free_queue, node);
    }
}
```
