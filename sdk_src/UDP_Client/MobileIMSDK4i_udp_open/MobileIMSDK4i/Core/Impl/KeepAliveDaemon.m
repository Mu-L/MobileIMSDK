//  ----------------------------------------------------------------------
//  Copyright (C) 2021  即时通讯网(52im.net) & Jack Jiang.
//  The MobileIMSDK_UDP (MobileIMSDK v6.x UDP版) Project.
//  All rights reserved.
//
//  > Github地址: https://github.com/JackJiang2011/MobileIMSDK
//  > 文档地址:    http://www.52im.net/forum-89-1.html
//  > 技术社区：   http://www.52im.net/
//  > 技术交流群： 215477170 (http://www.52im.net/topic-qqgroup.html)
//  > 作者公众号： “即时通讯技术圈】”，欢迎关注！
//  > 联系作者：   http://www.52im.net/thread-2792-1-1.html
//
//  "即时通讯网(52im.net) - 即时通讯开发者社区!" 推荐开源工程。
//  ----------------------------------------------------------------------

#import "KeepAliveDaemon.h"
#import "ToolKits.h"
#import "LocalDataSender.h"
#import "ClientCoreSDK.h"


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 静态全局类变量
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static int NETWORK_CONNECTION_TIME_OUT = 10 * 1000;
static int KEEP_ALIVE_INTERVAL = 3000;


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface KeepAliveDaemon ()

@property (nonatomic, assign) BOOL keepAliveRunning;
@property (nonatomic, assign) long lastGetKeepAliveResponseFromServerTimstamp;
@property (nonatomic, copy) ObserverCompletion networkConnectionLostObserver_;
@property (nonatomic, copy) ObserverCompletion debugObserver_;
@property (nonatomic, assign) BOOL _excuting;
@property (nonatomic, retain) NSTimer *timer;

@end


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation KeepAliveDaemon

static KeepAliveDaemon *instance = nil;


//-----------------------------------------------------------------------------------
#pragma mark - 外部可调用的静态方法

+ (KeepAliveDaemon *)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[super allocWithZone:NULL] init];
    });
    return instance;
}

+ (void) setKEEP_ALIVE_INTERVAL:(int)keepAliveTimeWithMils
{
    KEEP_ALIVE_INTERVAL = keepAliveTimeWithMils;
}
+ (int) getKEEP_ALIVE_INTERVAL
{
    return KEEP_ALIVE_INTERVAL;
}

+ (void) setNETWORK_CONNECTION_TIME_OUT:(int)networkConnectionTimeout
{
    NETWORK_CONNECTION_TIME_OUT = networkConnectionTimeout;
}
+ (int) getNETWORK_CONNECTION_TIME_OUT
{
    return NETWORK_CONNECTION_TIME_OUT;
}


//-----------------------------------------------------------------------------------
#pragma mark - 仅内部可调用的方法

- (id)init
{
    if (![super init])
        return nil;
    
    NSLog(@"KeepAliveDaemon已经init了！");
    
    self.keepAliveRunning = NO;
    self.lastGetKeepAliveResponseFromServerTimstamp = 0;
    self._excuting = NO;
    
    return self;
}

- (void) run
{
    if(!self._excuting)
    {
        BOOL willStop = NO;
        self._excuting = true;
        if([ClientCoreSDK isENABLED_DEBUG])
            NSLog(@"【IMCORE-UDP】心跳线程执行中...");
        int code = [[LocalDataSender sharedInstance] sendKeepAlive];
        
        // form DEBUG
        if(self.debugObserver_ != nil)
            self.debugObserver_(nil, [NSNumber numberWithInt:2]);
        
        BOOL isInitialedForKeepAlive = (self.lastGetKeepAliveResponseFromServerTimstamp == 0);
        //## Bug FIX 20190513 v4.0.1 START
        if(self.lastGetKeepAliveResponseFromServerTimstamp == 0)
            self.lastGetKeepAliveResponseFromServerTimstamp = [ToolKits getTimeStampWithMillisecond_l];
        //## Bug FIX 20190513 v4.0.1 END
        
        if(!isInitialedForKeepAlive)
        {
            long now = [ToolKits getTimeStampWithMillisecond_l];
            if(now - self.lastGetKeepAliveResponseFromServerTimstamp >= NETWORK_CONNECTION_TIME_OUT)
            {
                [self stop];
                if(self.networkConnectionLostObserver_ != nil)
                    self.networkConnectionLostObserver_(nil, nil);
                
                willStop = YES;
            }
        }
        
        self._excuting = NO;
        if(!willStop)
        {
            ;
        }
        else
        {
            [self stop];
        }
    }
}

- (void) stop
{
    if(self.timer != nil)
    {
        if([self.timer isValid])
            [self.timer invalidate];
        
        self.timer = nil;
    }
    self.keepAliveRunning = NO;
    self.lastGetKeepAliveResponseFromServerTimstamp = 0;
    
    // for DEBUG
    if(self.debugObserver_ != nil)
        self.debugObserver_(nil, [NSNumber numberWithInt:0]);
}

- (void) start:(BOOL)immediately
{
    [self stop];
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:KEEP_ALIVE_INTERVAL / 1000 target:self selector:@selector(run) userInfo:nil repeats:YES];
    if(immediately)
       [self.timer fire];
    self.keepAliveRunning = YES;
    
    // form DEBUG
    if(self.debugObserver_ != nil)
        self.debugObserver_(nil, [NSNumber numberWithInt:1]);
}

- (BOOL) isKeepAliveRunning
{
    return self.keepAliveRunning;
}

- (void) updateGetKeepAliveResponseFromServerTimstamp
{
    self.lastGetKeepAliveResponseFromServerTimstamp = [ToolKits getTimeStampWithMillisecond_l];
}

- (void) setNetworkConnectionLostObserver:(ObserverCompletion)networkConnLostObserver
{
    self.networkConnectionLostObserver_ = networkConnLostObserver;
}

- (void) setDebugObserver:(ObserverCompletion)debugObserver
{
    self.debugObserver_ = debugObserver;
}

@end
