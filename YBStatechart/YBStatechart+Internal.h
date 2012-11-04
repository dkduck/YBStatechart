//
//  YBStatechart+Internal.h
//  YBStatechart
//
//  Created by Florian on 02.11.12.
//  Copyright (c) 2012 Yobble. All rights reserved.
//

#import "YBStatechart.h"

@interface YBStatechart ()

- (void)registerState:(YBState *)state;
- (void)gotoState:(YBState*)state fromState:(YBState*)fromState useHistory:(BOOL)useHistory recursive:(BOOL)recursive context:(id)context;
- (void)exitState:(YBState*)state withContext:(id)context;
- (void)enterState:(YBState*)state withContext:(id)context isCurrentState:(BOOL)isCurrentState;

@end
