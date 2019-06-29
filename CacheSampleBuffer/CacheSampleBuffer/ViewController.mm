//
//  ViewController.m
//  CacheSampleBuffer
//
//  Created by 小东邪 on 08/01/2018.
//  Copyright © 2018 小东邪. All rights reserved.
//

/*******************************************************************************************************************

    本例需求：将相机回调产生的数据放入高效的队列中，然后异步开启一条线程专门处理从相机回调装入队列的Buffer，实现高效处理每一帧数据(如进行crop,scale...)
 
    验证：可查看Log,如果控制台打印的Test : index 是连续的，则说明装入队列是按顺序的成功。
 
    注意：关于C++队列实现可直接在XDXCustomQueueProcess.h XDXCustomQueueProcess.mm文件中直接看到。

    具体详细解析请参考简书或者博客，如果喜欢记得在GitHub里， 简书里给个星星，给个赞，Thanks
    简书地址：
 
    博客地址：
 
    GitHub地址：https://github.com/ChengyangLi/WorkQueueAndFreeQueue_HandleData

********************************************************************************************************************/

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "XDXQueueProcess.h"
#import <pthread.h>
#include "log4cplus.h"

#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height

#define currentResolutionW 1920
#define currentResolutionH 1080
#define currentResolution AVCaptureSessionPreset1920x1080

const static char *kModuleName = "MainVC";

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    XDXCustomQueueProcess   *_captureBufferQueue;   // 控制队列实例
    pthread_t                _cacheThread;          // 从队列中取出sampleBuffer的线程
}

@property (nonatomic, strong) AVCaptureSession              *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer    *captureVideoPreviewLayer;
@property (nonatomic, assign) BOOL                          isOpenGPU;

@end

@implementation ViewController

#pragma mark - 处理Samplebuffer的线程
- (void)handleCacheThread {
    while (true) {
        // 从队列取出在相机回调中放入队列的线程
        XDXCustomQueueNode *node = _captureBufferQueue->DeQueue(_captureBufferQueue->m_work_queue);
        if (node == NULL) {
            log4cplus_debug(kModuleName, "Data node is NULL");
            usleep(10*1000);
            continue;
        }
        
        CMSampleBufferRef sampleBuffer     = (CMSampleBufferRef)node->data;
        // 打印结点的index，如果连续则说明在相机回调中放入的samplebuffer是连续的
        log4cplus_debug(kModuleName, "Test index : %ld",node->index);
        
        /* 可在此处理从队列中拿到的Buffer，用完后记得释放内存并将结点重新放回空闲队列
         * ........
         */
        
        CFRelease(sampleBuffer);
        node->data = NULL;
        _captureBufferQueue->EnQueue(_captureBufferQueue->m_free_queue, node);
    }
}

void * startCropTask(void *param) {
    pthread_setname_np("TVUCropThread");
    ViewController *obj = (__bridge_transfer UIViewController *)param;
    [obj handleCacheThread];
    
    return NULL;
}

#pragma mark - Init
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 设置始终横屏
    [self setScreenCross];
    
    // 初始化相机Preview相关参数
    [self initCapture];
    
    // 初始化队列，异步开启取samplebuffer的线程
    _captureBufferQueue = new XDXCustomQueueProcess();
    pthread_create(&_cacheThread, NULL, startCropTask, (__bridge_retained void *)self);
}

- (void)setScreenCross {
    if([[UIDevice currentDevice] respondsToSelector:@selector(setOrientation:)]) {
        SEL selector = NSSelectorFromString(@"setOrientation:");
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[UIDevice instanceMethodSignatureForSelector:selector]];
        [invocation setSelector:selector];
        [invocation setTarget:[UIDevice currentDevice]];
        int val = UIInterfaceOrientationLandscapeLeft;//横屏
        [invocation setArgument:&val atIndex:2];
        [invocation invoke];
    }
}

- (void)initCapture {
    // 获取后置摄像头设备
    AVCaptureDevice *inputDevice            = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    // 创建输入数据对象
    AVCaptureDeviceInput *captureInput      = [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:nil];
    if (!captureInput) return;
    
    // 创建一个视频输出对象
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    [captureOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    NSString     *key           = (NSString *)kCVPixelBufferPixelFormatTypeKey;
    NSNumber     *value         = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    
    [captureOutput setVideoSettings:videoSettings];
    
    
    self.captureSession = [[AVCaptureSession alloc] init];
    NSString *preset;
    
#warning 注意，iPhone 6s以上设备可以设置为4K，若测试设备为6S以下则需要降低分辨率
    if (!preset) preset = AVCaptureSessionPreset1920x1080;
    
    if ([_captureSession canSetSessionPreset:preset]) {
        self.captureSession.sessionPreset = preset;
    }else {
        self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    }
    
    if ([self.captureSession canAddInput:captureInput]) {
        [self.captureSession addInput:captureInput];
    }
    if ([self.captureSession canAddOutput:captureOutput]) {
        [self.captureSession addOutput:captureOutput];
    }
    
    // 创建视频预览图层
    if (!self.captureVideoPreviewLayer) {
        self.captureVideoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    }
    
    self.captureVideoPreviewLayer.frame         = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
    self.captureVideoPreviewLayer.videoGravity  = AVLayerVideoGravityResizeAspectFill;
    if([[self.captureVideoPreviewLayer connection] isVideoOrientationSupported])
    {
        [self.captureVideoPreviewLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
    }
    
    [self.view.layer     addSublayer:self.captureVideoPreviewLayer];
    [self.captureSession startRunning];
}

#pragma mark ------------------AVCaptureVideoDataOutputSampleBufferDelegate--------------------------------
// Called whenever an AVCaptureVideoDataOutput instance outputs a new video frame. 每产生一帧视频帧时调用一次
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
//    if(!CMSampleBufferDataIsReady(sampleBuffer)) {
//        NSLog( @"sample buffer is not ready. Skipping sample" );
//        return;
//    }
    
//     将相机产生的Samplebuffer入队
    [self addBufferToWorkQueueWithSampleBuffer:sampleBuffer];

}

- (void)addBufferToWorkQueueWithSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    XDXCustomQueueNode *node = _captureBufferQueue->DeQueue(_captureBufferQueue->m_free_queue);
    if (node == NULL) {
        log4cplus_debug(kModuleName, "Data in , the node is NULL !");
        return;
    }
    CFRetain(sampleBuffer);
    node->data = sampleBuffer;
    _captureBufferQueue->EnQueue(_captureBufferQueue->m_work_queue, node);

    log4cplus_debug(kModuleName, "Data in ,  work size = %d, free size = %d !",_captureBufferQueue->m_work_queue->size, _captureBufferQueue->m_free_queue->size);
}

@end
