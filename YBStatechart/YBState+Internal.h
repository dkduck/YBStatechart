//
//  YBState+Internal.h
//  YBStatechart
//
//  Created by Florian on 02.11.12.
//  Copyright (c) 2012 Yobble. All rights reserved.
//

#import "YBState.h"

@interface YBState ()

@property (nonatomic) BOOL skipStateInBuildingExitActions;
@property (nonatomic, readwrite, assign) YBState *historySubstate;

- (void)initializeStateRecursively;
- (void)setStatechart:(YBStatechart*)statechart;
- (BOOL)canPerformAction:(SEL)action;
- (BOOL)tryToHandleInvocation:(NSInvocation*)anInvocation;
- (void)removeCurrentState:(YBState*)state;
- (void)addCurrentState:(YBState*)state;
- (void)removeEnteredState:(YBState*)state;
- (void)addEnteredState:(YBState*)state;

@end
