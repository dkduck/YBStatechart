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

/**
 Accessors for the last active substate. This is automatically set when the active state is changed using e.g. the -[YBStatechart activateState...] methods.
 @see useHistory
 @see -[YBStatechart activateState:]
 */
@property (nonatomic, readwrite, assign) YBState *historySubstate;

/**
 Set this property to YES if the receiver should store the active substate as it gets actived and make the stored substate
 active again as initial substate the next time the receiver becomes active. If no previously active substate has been stored,
 the initialSubstate property will be used. If substatesAreConcurrent is set to YES, this property is ignored.
 */
//@property (nonatomic, assign, readwrite) BOOL useHistory;


- (void)initializeStateRecursively;
- (void)setStatechart:(YBStatechart*)statechart;
//- (void)activate;
//- (void)activateDefaultSubstatesRecursive:(BOOL)recursive saveToHistory:(BOOL)saveToHistory;
//- (void)activateSubstate:(YBState*)substate saveToHistory:(BOOL)saveToHistory;
//- (void)deactivate;
//- (void)deactivateSubstatesExcept:(YBState*)exceptSubstate recursive:(BOOL)recursive;
- (void)handleInvocationAndDispatchToActiveSubstates:(NSInvocation*)anInvocation;
- (BOOL)canPerformAction:(SEL)action;
- (void)removeCurrentState:(YBState*)state;
- (void)addCurrentState:(YBState*)state;
- (void)removeEnteredState:(YBState*)state;
- (void)addEnteredState:(YBState*)state;

@end
