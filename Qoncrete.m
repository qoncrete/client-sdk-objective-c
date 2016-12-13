//
// Qoncrete.m
// Version 0.0.1
// Created by 罗文奇 on 2016/12/12.
//

#import "Qoncrete.h"

#define HOST @"https://log.qoncrete.com"

// ErrorCode
#define INVALID_BODY @"ErrorCode.INVALID_BODY"
#define TIMEDOUT @"ErrorCode.TIMEDOUT"
#define CLIENT_ERROR @"ErrorCode.CLIENT_ERROR"
#define SERVER_ERROR @"ErrorCode.SERVER_ERROR"
#define NETWORK_ERROR @"ErrorCode.NETWORK_ERROR"
#define DEFAULT_ERROR @"ErrorCode.ERROR"

@interface NSString (BeeExtension)

- (BOOL)isUUID;

@end

@implementation NSString (BeeExtension)

- (BOOL)isUUID {
    NSString *regex = @"[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}";
    NSPredicate* pred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    return [pred evaluateWithObject:self];
}

@end

typedef void (^result)(NSDictionary *err);

@interface Qoncrete () {
    NSOperationQueue *operationQueue;
}

@property (nonatomic, copy) NSString *sendLogEndpoint;
@property (nonatomic, copy) NSString *sendBatchLogEndpoint;
@property (nonatomic, strong) NSDictionary *keepAliveAgent;
@property (nonatomic, strong) NSMutableArray *logPool;
@end

@implementation Qoncrete

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        self.errorLogger = ^(NSDictionary *err){};
        self.cacheDNS = YES;
        
        self.timeoutAfter = 15.0;
        self.retryOnTimeout = 1;
        
        self.autoBatch = true;
        self.batchSize = 1000;
        self.autoSendAfter = 2;
        self.concurrency = 200;
        
    }
    return self;
}

static Qoncrete *shareSingleton;

+ (instancetype)sharedSingleton {
    static dispatch_once_t onceToken;
    dispatch_once ( &onceToken, ^ {
        shareSingleton = [[Qoncrete alloc] init];
    });
    return shareSingleton;
}

- (void)endConfig {

    [self validateQoncreteClientWithSourceID:self.sourceID apiToken:self.apiToken];
    
    [self validateQoncreteClientWithBatchSize:self.batchSize];

    operationQueue = [[NSOperationQueue alloc]init];
    operationQueue.maxConcurrentOperationCount = self.concurrency;
    
    self.sendLogEndpoint = [NSString stringWithFormat:@"%@/%@?token=%@", HOST, self.sourceID,self.apiToken];
    self.sendBatchLogEndpoint = [NSString stringWithFormat:@"%@/%@/batch?token=%@", HOST, self.sourceID,self.apiToken];
    self.keepAliveAgent = @{
                            @"keepAlive": @YES,
                            @"keepAliveMsec": @5000,
                            @"maxSockets": @NSIntegerMax,
                            @"maxFreeSocket": @512
                            };
    // TODO: 待翻译
    //    require('dnscache')({ enable: !!cacheDNS, ttl: 300, cachesize: 1000 })
    
    self.logPool = [NSMutableArray array];
    if (self.autoBatch) {
        [self performSelector:@selector(autoSendBatch) withObject:@"autoSendBatch" afterDelay:self.autoSendAfter];
    }
}

- (void)initAutoSendBatch {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(autoSendBatch) object:@"autoSendBatch"];
    [self performSelector:@selector(autoSendBatch) withObject:@"autoSendBatch" afterDelay:self.autoSendAfter];
}

- (void)autoSendBatch {
    if (self.logPool.count) {
        NSInteger length = MIN(self.batchSize, self.logPool.count);
        NSArray *batch = [self.logPool subarrayWithRange:NSMakeRange(0, length)];
        [self.logPool removeObjectsInRange:NSMakeRange(0, length)];
        
        [operationQueue addOperationWithBlock:^{
            [self sendNowWithBatch:batch retryOnTimeout:self.retryOnTimeout callback:^(NSDictionary *err) {
                if (err) self.errorLogger(err);
            }];
        }];
    }
    [self performSelector:@selector(autoSendBatch) withObject:@"autoSendBatch" afterDelay:self.autoSendAfter];
}

- (void)send:(NSDictionary *)data {
    if (!data) {
        return self.errorLogger(@{@"code": CLIENT_ERROR, @"message": @"`data` must be valid."});
    }
    [self.logPool addObject:data];
    
    if (!self.autoBatch || self.logPool.count >= self.batchSize) {
        NSInteger length = MIN(self.batchSize, self.logPool.count);
        NSArray *batch = [self.logPool subarrayWithRange:NSMakeRange(0, length)];
        [self.logPool removeObjectsInRange:NSMakeRange(0, length)];

        [operationQueue addOperationWithBlock:^{
            [self sendNowWithBatch:batch retryOnTimeout:self.retryOnTimeout callback:^(NSDictionary *err) {
                if (err) self.errorLogger(err);
            }];
        }];
        [self initAutoSendBatch];
    }
}

- (void)sendNowWithBatch:(NSArray*)batch retryOnTimeout:(NSInteger)retryOnTimeout callback:(result)callback {
    NSString *endpoint = self.sendBatchLogEndpoint;
    NSArray *postJson = batch;
    
    if (batch.count == 1) {
        endpoint = self.sendLogEndpoint;
        postJson = batch[0];
    }

    
    NSURL *url = [NSURL URLWithString:endpoint];
    NSMutableURLRequest *request =[NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setTimeoutInterval:self.timeoutAfter];
    
    // NOTE: 待翻译
//    pool(this.keepAliveAgent).
    NSData *postBody = [NSJSONSerialization dataWithJSONObject:postJson options:NSJSONWritingPrettyPrinted error:nil];
    [request setHTTPBody:postBody];
    
    __weak Qoncrete *weakSelf = self;
    __block NSInteger weakRetryOnTimeout = retryOnTimeout;
    
    [NSURLConnection sendAsynchronousRequest:request queue:operationQueue completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        if (httpResponse.statusCode == 204) {
            return callback(nil);
        }
        
        if (connectionError && !data) {
            if (connectionError.code == NSURLErrorTimedOut) {
                return callback(@{@"code": NETWORK_ERROR, @"message": connectionError.localizedDescription});
            }
            
            // retry
            if (weakRetryOnTimeout > 0) {
                weakRetryOnTimeout -= 1;
                return [weakSelf sendNowWithBatch:batch retryOnTimeout:weakRetryOnTimeout callback:^(NSDictionary *err) {
                    if (err) weakSelf.errorLogger(err);
                }];
            }
            
            return callback(@{@"code": TIMEDOUT, @"message": @"The request took too long time."});
        }

        if (!connectionError && data) {
            NSString *resultString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            return callback(@{@"code": DEFAULT_ERROR, @"message": resultString});
        }
    }];
    
#ifdef __IPHONE_9_0
#else
#endif

}

- (void)validateQoncreteClientWithSourceID:(NSString *)sourceID apiToken:(NSString *)apiToken {
    
    if (!(sourceID && apiToken)) {
        
        NSException *e = [NSException
                          exceptionWithName: CLIENT_ERROR
                          reason: @"`sourceID` and `apiToken` must be specified."
                          userInfo: nil];
        @throw e;
    }

    sourceID = [sourceID lowercaseString];
    apiToken = [apiToken lowercaseString];
    
    if (!([sourceID isUUID] && [apiToken isUUID])) {
        
        NSException *e = [NSException
                          exceptionWithName: CLIENT_ERROR
                          reason: @"`sourceID` and `apiToken` must be valid UUIDs."
                          userInfo: nil];
        @throw e;
    }
    
    self.sourceID = sourceID;
    self.apiToken = apiToken;
}

- (void)validateQoncreteClientWithBatchSize:(NSInteger)batchSize {
    if (batchSize <= 0 || batchSize > 1000) {
        NSException *e = [NSException
                          exceptionWithName: CLIENT_ERROR
                          reason: @"batchSize must be included between 1 and 1000"
                          userInfo: nil];
        @throw e;
    }

}

@end
