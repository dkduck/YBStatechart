//
//  YBState.m
//  YBStatechart
//
//  Created by Florian on 02.11.12.
//  Copyright (c) 2012 Yobble. All rights reserved.
//

#import "YBState.h"
#import "YBState+Internal.h"
#import "YBStatechart.h"
#import "YBStatechart+Internal.h"

@interface YBState () {
    NSString* historyKey;
    BOOL isSetup;
}
@end



@implementation YBState

+ (id)stateWithName:(NSString*)name {
    return [[self alloc] initWithName:name];
}

- (id)initWithName:(NSString*)name {
    NSAssert(name.length != 0, @"Cannot create state without a name");
    NSAssert([name rangeOfString:@"."].length == 0, @"Cannot create a state name containing a dot character (.)");
    self = [super init];
    if (self) {
        _name = name;
        _substates = [NSSet set];
        _currentSubstates = [NSMutableSet set];
        _enteredSubstates = [NSMutableSet set];
        isSetup = NO;
        historyKey = [@"YBStateHistory_" stringByAppendingString:_name];
        self.skipStateInBuildingExitActions = NO;
    }
    return self;
}

- (void)initializeStateRecursively {
    [self setup];
    [_substates makeObjectsPerformSelector:@selector(initializeStateRecursively)];
}

- (void)setup {
}

#if DEBUG
- (BOOL)debugValidate {
    if ([_substates count] > 1) {
        __block BOOL validates = YES;
        if (_substatesAreOrthogonal == NO && _initialSubstate == nil) {
            NSLog(@"No initial substate is set for state `%@` while there are multiple non-orthogonal substates.", _name);
            validates = NO;
        }
        [_substates enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(YBState *substate, BOOL *stop) {
            if ([substate debugValidate] == NO) {
                validates = NO;
            }
        }];
        return validates;
    } else if ([_substates count] == 1) {
        NSLog(@"There is only one substate for state `%@`. You might want to consider merging `%@` with it's superstate `%@`", _name, [[_substates anyObject] name], _name);
        return [[_substates anyObject] debugValidate];
    }
    return YES;
}
#endif

- (YBState*)addSubstate:(YBState*)substate {
    if (substate == self) {
        // can't do recursion!
        return self;
    }
    if (substate->_superstate) {
        if (substate->_superstate != self) {
            // state is already a substate of another state
            [NSException raise:@"State is already a substate of another state" format:@"Superstate: %@", [substate->_superstate name]];
        }
        return self;
    }
    _substates = [_substates setByAddingObject:substate];
    substate->_superstate = self;
    [substate setStatechart:self.statechart];
    return self;
}

- (YBState*)addSubstates:(YBState *)substates, ... {
    va_list list;
    va_start(list, substates);
    YBState *substate = substates;
    do {
        [self addSubstate:substate];
        substate = va_arg(list, YBState*);
    } while (substate);
    va_end(list);
    return self;
}

- (NSString*)path {
    if (_superstate == nil) {
        return _name;
    } else {
        // todo: maybe cache this if called a lot
        return [[[_superstate path] stringByAppendingString:@"."] stringByAppendingString:_name];
    }
}

- (YBState*)substateWithName:(NSString*)stateName {
    __block YBState *foundSubstate = nil;
    [_substates enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(YBState *substate, BOOL *stop) {
        if ([[substate name] isEqualToString:stateName]) {
            foundSubstate = substate;
            *stop = YES;
        }
    }];
    return foundSubstate;
}

- (void)setInitialSubstate:(YBState *)initialSubstate {
    if (initialSubstate == self) {
        // can't do recursion!
        return;
    }
    // Add implicitely to self.substates if not already added:
    if (initialSubstate != nil && [_substates containsObject:initialSubstate] == NO) {
        [self addSubstate:initialSubstate];
    }
    _initialSubstate = initialSubstate;
}

- (void)gotoState:(id)state {
    [self gotoState:state useHistory:NO recursive:NO];
}

- (void)gotoHistoryState:(id)state recursive:(BOOL)recursive {
    [self gotoState:state useHistory:YES recursive:recursive];
}

- (void)gotoState:(id)state useHistory:(BOOL)useHistory recursive:(BOOL)recursive {
    if ([state isKindOfClass:[NSString class]]) {
        state = [self.statechart findStateWithName:state];
    }
    NSAssert1(state, @"No known target state %@", state);
    state = (YBState*)state;
    
    YBState* fromState = self;
    if (!fromState.isCurrentState) {
        fromState = _currentSubstates.anyObject;
    }
    NSAssert1(fromState, @"Attempted to transition to state %@ but could not determine source state", state);
    
    [self.statechart gotoState:state fromState:fromState useHistory:useHistory recursive:recursive];
}

- (void)enterState {
}

- (void)exitState {
}

- (BOOL)isCurrentState {
    return [_currentSubstates containsObject:self];
}

- (BOOL)isEnteredState {
    return [_enteredSubstates containsObject:self];
}

- (BOOL)hasSubstates {
    return _substates.count > 0;
}

- (BOOL)hasCurrentSubstates {
    return _currentSubstates.count > 0;
}


#pragma mark Internal

- (void)setStatechart:(YBStatechart*)statechart {
    _statechart = statechart;
    [_statechart registerState:self];
    [_substates enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(YBState *substate, BOOL *stop) {
        [substate setStatechart:_statechart];
    }];
}

- (BOOL)tryToHandleInvocation:(NSInvocation*)anInvocation {
    if ([self respondsToSelector:anInvocation.selector]) {
        NSLog(@"Handling invocation: %@", NSStringFromSelector(anInvocation.selector));
        [anInvocation invokeWithTarget:self];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)canPerformAction:(SEL)action {
    __block BOOL substateCanPerformAction = NO;
    [_enteredSubstates enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(YBState* substate, BOOL *stop) {
        substateCanPerformAction = YES;
        *stop = YES;
    }];
    return substateCanPerformAction;
}

- (void)removeCurrentState:(YBState*)state {
    if ([_currentSubstates containsObject:state]) {
        [_currentSubstates removeObject:state];
    }
}

- (void)addCurrentState:(YBState*)state {
    [_currentSubstates addObject:state];
}

- (void)removeEnteredState:(YBState*)state {
    if ([_enteredSubstates containsObject:state]) {
        [_enteredSubstates removeObject:state];
    }
}

- (void)addEnteredState:(YBState*)state {
    [_enteredSubstates addObject:state];
}


- (NSString*)description {
    return [NSString stringWithFormat:@"<%@ %p: `%@` (%@, %@), path=%@>", [self class], self, _name,
            self.isEnteredState ? @"entered" : @"not entered", self.isCurrentState ? @"current" : @"not current", [self path]];
}

@end










