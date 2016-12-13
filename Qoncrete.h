//
// Qoncrete.h
// Version 0.0.1
// Created by 罗文奇 on 2016/12/12.
//

#import <Foundation/Foundation.h>

typedef void (^errorLogger)(NSDictionary *err);

@interface Qoncrete : NSObject

@property (nonatomic, copy) NSString *sourceID; // MANDATORY: The source ID. (Once logged-in, can be found at https://qoncrete.com/account/#!/source)
@property (nonatomic, copy) NSString *apiToken; // MANDATORY: The api token. (Once logged-in, can be found at https://qoncrete.com/account/#!/token)

@property (nonatomic, copy) errorLogger errorLogger; // A function called on error. Default: ^(NSDictionary *err){}
@property (nonatomic, assign) BOOL cacheDNS; // Active userland dns cache. Default: true"

@property (nonatomic, assign) NSTimeInterval timeoutAfter; // Abort the query on timeout. Default: 15s
@property (nonatomic, assign) NSInteger retryOnTimeout; // Number of times to resend the log on timeout. Default: 1 (on timeout, it will retry one more time)

// batch
@property (nonatomic, assign) BOOL autoBatch; // Try to send log by batch instead of sending them one by one. Default: true
@property (nonatomic, assign) NSInteger batchSize; // Only matters if autoBatch is True. Number of logs to send in a batch. Default: 1000, Max: 1000
@property (nonatomic, assign) NSTimeInterval autoSendAfter; // Only matters if autoBatch is True. Time after the logs will be sent if the batch is not full. Default: 2s

@property (nonatomic, assign) NSInteger concurrency; // Number of simultaneous queries that can be made, can be set lower or higher depending your server configuration. Default: 200



+ (instancetype)sharedSingleton;

- (void)endConfig;
- (void)send:(NSDictionary *)data;

@end
