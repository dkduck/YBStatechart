//
//  YBStateAction.m
//  YBStatechart
//
//  Created by Florian on 03.11.12.
//  Copyright (c) 2012 Yobble. All rights reserved.
//

#import "YBStateAction.h"
#import "YBState.h"
#import "YBStatechart+Internal.h"

@implementation YBStateAction

+ (YBStateAction*)stateActionWithType:(YBStateActionType)type forState:(YBState*)state current:(BOOL)current {
    YBStateAction* stateAction = [[YBStateAction alloc] init];
    stateAction.type = type;
    stateAction.state = state;
    stateAction.currentState = current;
    return stateAction;
}

- (void)execute {
    if (_type == YBStateActionExitState) {
        NSLog(@"Exiting state %@", _state);
        [_state.statechart exitState:_state];
    } else {
        NSLog(@"Entering state %@ (current state: %d)", _state, _currentState);
        [_state.statechart enterState:_state isCurrentState:_currentState];
    }
}

@end
