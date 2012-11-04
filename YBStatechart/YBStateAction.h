//
//  YBStateAction.h
//  YBStatechart
//
//  Created by Florian on 03.11.12.
//  Copyright (c) 2012 Yobble. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    YBStateActionExitState = 1,
    YBStateActionEnterState = 2
} YBStateActionType;

@class YBState;

@interface YBStateAction : NSObject

@property (nonatomic) YBStateActionType type;
@property (weak,nonatomic) YBState* state;
@property (nonatomic) BOOL currentState;

+ (YBStateAction*)stateActionWithType:(YBStateActionType)type forState:(YBState*)state current:(BOOL)current;
- (void)execute;

@end
