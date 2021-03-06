//
//  LDBatchRequest.m
//  LDNetworking
//
//  Created by YueHui on 17/1/16.
//  Copyright © 2017年 LeapDing. All rights reserved.
//

#import "LDBatchRequest.h"
#import "LDNetworkPrivate.h"
#import "LDBatchRequestAgent.h"
#import "LDBaseRequest.h"

@interface LDBatchRequest() <LDBaseRequestCallBackDelegate>

@property (nonatomic) NSInteger finishedCount;

@end

@implementation LDBatchRequest

- (void)dealloc {
    [self clearRequest];
}

- (instancetype)initWithRequestArray:(NSArray<LDBaseRequest *> *)requestArray {
    self = [super init];
    if (self) {
        _requestArray = [requestArray copy];
        _finishedCount = 0;
        for (LDRequest * req in _requestArray) {
            if (![req isKindOfClass:[LDRequest class]]) {
                LDLog(@"Error, request item must be LDRequest instance.");
                return nil;
            }
        }
    }
    return self;
}

- (void)loadData {
    if (_finishedCount > 0) {
        LDLog(@"Error! Batch request has already started.");
        return;
    }
    _failedRequest = nil;
    [[LDBatchRequestAgent sharedInstance] addBatchRequest:self];
    [self toggleAccessoriesWillStartCallBack];
    for (LDRequest * req in _requestArray) {
        req.delegate = self;
        [req clearCompletionBlock];
        [req loadData];
    }
}

- (void)cancel {
    [self toggleAccessoriesWillStopCallBack];
    _delegate = nil;
    [self clearRequest];
    [self toggleAccessoriesDidStopCallBack];
    [[LDBatchRequestAgent sharedInstance] removeBatchRequest:self];
}

- (void)loadDataWithCompletionBlockWithSuccess:(void (^)(LDBatchRequest *))success failure:(void (^)(LDBatchRequest *))failure {
    [self setCompletionBlockWithSuccess:success failure:failure];
    [self loadData];
}

- (void)setCompletionBlockWithSuccess:(void (^)(LDBatchRequest *batchRequest))success
                              failure:(void (^)(LDBatchRequest *batchRequest))failure {
    self.successCompletionBlock = success;
    self.failureCompletionBlock = failure;
}

- (void)clearCompletionBlock {
    // nil out to break the retain cycle.
    self.successCompletionBlock = nil;
    self.failureCompletionBlock = nil;
}

- (BOOL)isDataFromCache {
    BOOL result = YES;
    for (LDRequest *request in _requestArray) {
        if (!request.isDataFromCache) {
            result = NO;
        }
    }
    return result;
}

#pragma mark - Network Request Delegate

- (void)requestDidSuccess:(LDRequest *)request {
    _finishedCount++;
    if (_finishedCount == _requestArray.count) {
        [self toggleAccessoriesWillStopCallBack];
        if ([_delegate respondsToSelector:@selector(batchRequestDidSuccess:)]) {
            [_delegate batchRequestDidSuccess:self];
        }
        if (_successCompletionBlock) {
            _successCompletionBlock(self);
        }
        [self clearCompletionBlock];
        [self toggleAccessoriesDidStopCallBack];
        [[LDBatchRequestAgent sharedInstance] removeBatchRequest:self];
    }
}

- (void)requestDidFailed:(LDRequest *)request {
    _failedRequest = request;
    [self toggleAccessoriesWillStopCallBack];
    
    // Cancel
    for (LDRequest *req in _requestArray) {
        [req cancel];
    }
    
    // Callback
    if ([_delegate respondsToSelector:@selector(batchRequestDidFailed:)]) {
        [_delegate batchRequestDidFailed:self];
    }
    if (_failureCompletionBlock) {
        _failureCompletionBlock(self);
    }
    //Clear
    [self clearCompletionBlock];
    [self toggleAccessoriesDidStopCallBack];
    
    [[LDBatchRequestAgent sharedInstance] removeBatchRequest:self];
}

- (void)clearRequest {
    for (LDRequest * req in _requestArray) {
        [req cancel];
    }
    [self clearCompletionBlock];
}

#pragma mark - Request Accessoies

- (void)addAccessory:(id<LDRequestAccessory>)accessory {
    if (!self.requestAccessories) {
        self.requestAccessories = [NSMutableArray array];
    }
    [self.requestAccessories addObject:accessory];
}


@end
