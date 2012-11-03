//
//  YBStatechart.m
//  YBStatechart
//
//  Created by Martijn Thé on 3/26/12.
//  Copyright (c) 2012 Yobble. All rights reserved.
//

#import "YBStatechart.h"
#import "YBStatechart+Internal.h"
#import "YBState.h"
#import "YBState+Internal.h"
#import "YBStateAction.h"
#import <objc/runtime.h>


@interface YBStatechart () {
    NSMutableDictionary* registeredStates;
    NSMutableArray* gotoStateActions;
    NSMutableArray* pendingStateTransitions;
    NSMutableArray* pendingMessages;
    BOOL stateTransitionLock;
    BOOL sendMessageLock;
}
@end


@implementation YBStatechart

- (id)init {
    self = [super init];
    if (self) {
        registeredStates = [NSMutableDictionary dictionary];
        gotoStateActions = [NSMutableArray array];
        pendingStateTransitions = [NSMutableArray array];
        pendingMessages = [NSMutableArray array];
        stateTransitionLock = NO;
        sendMessageLock = NO;
    }
    return self;
}

- (void)setup {
    
}

#if DEBUG
- (BOOL)debugValidate {
    if (_rootState == nil) {
        NSLog(@"No rootState set!");
        return NO;
    }
    return [_rootState debugValidate];
}
#endif

- (void)activate {
    if (_isActive) {
        return;
    }
    [self setup];
    NSAssert(_rootState != nil, @"No rootState set.");
#if DEBUG
    BOOL valid = [self debugValidate];
    if (valid)
#endif
    {
        [_rootState initializeStateRecursively];
        [self gotoState:_rootState fromState:nil useHistory:NO recursive:NO];
        _isActive = YES;
    }
}

- (void)setRootState:(YBState *)rootState {
    if (rootState == _rootState) {
        return;
    }
    _rootState = rootState;
    [_rootState setStatechart:self];
}

- (YBState*)findStateWithName:(NSString*)stateName {
    return [registeredStates objectForKey:stateName];
}



#pragma mark Internal

- (void)gotoState:(YBState*)state fromState:(YBState*)fromState useHistory:(BOOL)useHistory recursive:(BOOL)recursive {
    NSAssert(fromState || !_rootState.currentSubstates.count, @"Attempting state transition without source state.");
    NSAssert(state, @"Attempting state transition without destination state.");

    if (stateTransitionLock) {
        [pendingStateTransitions addObject:@{@"fromState" : fromState, @"targetState" : state, @"useHistory": @(useHistory), @"recursive" : @(recursive)}];
        return;
    }
    
    stateTransitionLock = YES;

    if (useHistory && !recursive && state.historySubstate) {
        state = state.historySubstate;
    }

    NSArray* exitChain = fromState ? [self stateChainToState:fromState] : @[];
    NSArray* enterChain = [self stateChainToState:state];
    YBState* pivotState = [self findPivotStateForExitChain:exitChain enterChain:enterChain];

    NSAssert1(!pivotState.substatesAreOrthogonal, @"Attempted state transition via pivot state %@ with orthogonal substates", pivotState);
    
    // truncate enter chain at pivot state
    NSInteger pivotStateIdx = [enterChain indexOfObject:pivotState];
    if (pivotStateIdx != NSNotFound) {
        enterChain = [enterChain subarrayWithRange:NSMakeRange(0, pivotStateIdx)];
    }
    
    gotoStateActions = [NSMutableArray array];
    [self buildExitActionsFromState:fromState toState:pivotState];
    if (state != pivotState) {
        [self buildEnterActionsForChain:enterChain useHistoryRecursively:recursive];
    } else {
        [self buildExitActionsFromState:pivotState toState:pivotState.superstate];
        [self buildEnterActionsForChain:@[pivotState] useHistoryRecursively:recursive];
    }
    [self executeGotoStateActions];
    stateTransitionLock = NO;
    [self flushPendingStateTransitions];
    [self flushPendingMessages];
}

- (void)flushPendingStateTransitions {
    if (pendingStateTransitions.count) {
        NSDictionary* stateTransition = pendingStateTransitions[0];
        [pendingStateTransitions removeObjectAtIndex:0];
        [self gotoState:stateTransition[@"targetState"]
              fromState:stateTransition[@"fromState"]
             useHistory:(BOOL)stateTransition[@"useHistory"]
              recursive:(BOOL)stateTransition[@"recursive"]];
    }
}

- (NSArray*)stateChainToState:(YBState*)state {
    NSMutableArray* chain = [NSMutableArray array];
    while (state) {
        [chain addObject:state];
        state = state.superstate;
    }
    return chain;
}

- (YBState*)findPivotStateForExitChain:(NSArray*)exitChain enterChain:(NSArray*)enterChain {
    YBState* pivotState = nil;
    NSInteger stateIdx = [exitChain indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [enterChain indexOfObject:obj] != NSNotFound;
    }];
    if (stateIdx != NSNotFound) {
        pivotState = exitChain[stateIdx];
    }
    return pivotState;
}

- (void)buildExitActionsFromState:(YBState*)state toState:(YBState*)stopState {
    if (!state || state == stopState) {
        return;
    }
    
    if (state.substatesAreOrthogonal && state.hasSubstates) {
        [state.currentSubstates enumerateObjectsUsingBlock:^(YBState* substate, BOOL *stop) {
            if (!substate.skipStateInBuildingExitActions) {
                [self buildExitActionsFromState:substate toState:stopState];
            }
        }];
    }
    
    [gotoStateActions addObject:[YBStateAction stateActionWithType:YBStateActionExitState forState:state current:NO]];
    if (state.isCurrentState) {
        state.skipStateInBuildingExitActions = YES;
    }
    [self buildExitActionsFromState:state.superstate toState:stopState];
}

- (void)buildEnterActionsForChain:(NSArray*)enterChain useHistoryRecursively:(BOOL)useHistory {
    YBState* state = enterChain.lastObject;
    enterChain = [enterChain subarrayWithRange:NSMakeRange(0, enterChain.count - 1)];
    if (!state) {
        return;
    }
    
    if (!enterChain.count) {
        YBStateAction* action = [YBStateAction stateActionWithType:YBStateActionEnterState forState:state current:NO];
        [gotoStateActions addObject:action];
        
        if (state.substatesAreOrthogonal) {
            [self buildEnterActionsForOrthogonalStates:state.substates except:nil useHistoryRecursively:useHistory];
        } else if (state.hasSubstates) {
            if (useHistory && state.historySubstate) {
                [self buildEnterActionsForChain:@[state.historySubstate] useHistoryRecursively:useHistory];
            } else {
                NSAssert1(state.initialSubstate, @"Initial substate not defined on state %@", state);
                [self buildEnterActionsForChain:@[state.initialSubstate] useHistoryRecursively:useHistory];
            }
        } else {
            action.currentState = YES;
        }
        
    } else {
        [gotoStateActions addObject:[YBStateAction stateActionWithType:YBStateActionEnterState forState:state current:NO]];
        [self buildEnterActionsForChain:enterChain useHistoryRecursively:useHistory];
        
        if (state.substatesAreOrthogonal) {
            YBState* excludedState = enterChain.lastObject;
            [self buildEnterActionsForOrthogonalStates:state.substates except:excludedState useHistoryRecursively:useHistory];
        }
    }
}

- (void)buildEnterActionsForOrthogonalStates:(NSSet*)states except:(YBState*)excludedState useHistoryRecursively:(BOOL)useHistory {
    [states enumerateObjectsUsingBlock:^(id state, BOOL *stop) {
        if (state != excludedState) {
            [self buildEnterActionsForChain:@[state] useHistoryRecursively:useHistory];
        }
    }];
}

- (void)executeGotoStateActions {
    [gotoStateActions makeObjectsPerformSelector:@selector(execute)];
    gotoStateActions = nil;
}

- (void)exitState:(YBState*)state {
    if ([state.currentSubstates containsObject:state]) {
        YBState* superstate = state;
        while (superstate) {
            [superstate removeCurrentState:state];
            superstate = superstate.superstate;
        }
    }
    
    YBState* superstate = state;
    while (superstate) {
        [superstate removeEnteredState:state];
        superstate = superstate.superstate;
    }

    [state exitState];
    state.skipStateInBuildingExitActions = NO;
}

- (void)enterState:(YBState*)state isCurrentState:(BOOL)isCurrentState {
    YBState* superstate = state.superstate;
    if (superstate && !superstate.substatesAreOrthogonal) {
        superstate.historySubstate = state;
    }
    
    if (isCurrentState) {
        YBState* superstate = state;
        while (superstate) {
            [superstate addCurrentState:state];
            superstate = superstate.superstate;
        }
    }
    
    superstate = state;
    while (superstate) {
        [superstate addEnteredState:state];
        superstate = superstate.superstate;
    }

    [state enterState];
}


- (void)registerState:(YBState *)state {
    NSAssert1([registeredStates objectForKey:state.name] == nil || [registeredStates objectForKey:state.name] == state,
              @"Error while registering state %@: state names need to be unique within one statechart", state);
    [registeredStates setObject:state forKey:state.name];
}


#pragma mark Message forwarding

- (NSInteger)numberOfArgumenstsInSelector:(SEL)selector {
    NSString* selectorString = NSStringFromSelector(selector);
    NSUInteger count = 0, length = [selectorString length];
    NSRange range = NSMakeRange(0, length);
    while(range.location != NSNotFound)
    {
        range = [selectorString rangeOfString: @":" options:0 range:range];
        if(range.location != NSNotFound)
        {
            range = NSMakeRange(range.location + range.length, length - (range.location + range.length));
            count++; 
        }
    }
    return count;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    if ([self respondsToSelector:aSelector]) {
        return [super methodSignatureForSelector:aSelector];
    } else {
        NSInteger numberOfArguments = [self numberOfArgumenstsInSelector:aSelector];
        if (numberOfArguments == 0) { 
            return [NSMethodSignature signatureWithObjCTypes:"v@:"];
        } else if (numberOfArguments == 1) {
            return [NSMethodSignature signatureWithObjCTypes:"v@:@"];
        } else if (numberOfArguments == 2) {
            return [NSMethodSignature signatureWithObjCTypes:"v@:@@"];
        } else {
            return [super methodSignatureForSelector:aSelector];
        }
    }
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    [anInvocation retainArguments];
    [self sendInvocation:anInvocation];
}

- (void)sendInvocation:(NSInvocation*)invocation {
    NSAssert(_rootState != nil, @"No rootState set.");
    if (sendMessageLock || stateTransitionLock) {
        [pendingMessages addObject:invocation];
        return;
    }
    
    sendMessageLock = YES;
    
    NSMutableSet* messageHandledByStates = [NSMutableSet set];
    [_rootState.currentSubstates enumerateObjectsUsingBlock:^(YBState* state, BOOL *stop) {
        YBState* handlerState = state;
        BOOL messageHandled = NO;
        while (!messageHandled && handlerState && ![messageHandledByStates containsObject:handlerState]) {
            messageHandled = [handlerState tryToHandleInvocation:invocation];
            if (!messageHandled) {
                handlerState = handlerState.superstate;
            } else {
                [messageHandledByStates addObject:handlerState];
            }
        }
    }];
    
    sendMessageLock = NO;
    [self flushPendingMessages];

}

- (void)flushPendingMessages {
    if (pendingMessages.count) {
        NSInvocation* invocation = pendingMessages[0];
        [pendingMessages removeObjectAtIndex:0];
        [self sendInvocation:invocation];
    }
}


#pragma mark UIResponder methods

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if ([super canPerformAction:action withSender:sender]) {
        return YES;
    } else if (_rootState) {
        return [_rootState canPerformAction:action];
    }
    return NO;
}

@end


