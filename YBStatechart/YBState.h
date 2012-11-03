//
//  YBState.h
//  YBStatechart
//
//  Created by Florian on 02.11.12.
//  Copyright (c) 2012 Yobble. All rights reserved.
//

#import <Foundation/Foundation.h>

@class YBStatechart;

@interface YBState : NSObject

/**
 Designated initializer to set up a new state object.
 @param name - The name of the state. State names in a statechart need to be unique.
 @returns - The initialized, inactive state object
 */
- (id)initWithName:(NSString*)name;

/**
 Convenience factory method to allocate and set up a new state object.
 @param name - The name of the state. State names in a statechart need to be unique.
 @returns The initialized, inactive state object
 */
+ (id)stateWithName:(NSString*)name;

/**
 Override this method to setup the state and potential substates.
 This method gets called when you call -activate on the statechart.
 */
- (void)setup;

/**
 @returns The path of states from the receiver up to the rootState, as a keyPath-style string (e.g. `rootState.substate1.substate2`)
 */
- (NSString*)path;

/**
 Makes the given state a substate of the receiver. This will automatically make the receiver the superstate of the given state.
 @param substate - the state to add to as substate
 @return Returns the receiver, to enable chaining-style programming
 */
- (YBState*)addSubstate:(YBState*)substate;

/**
 Convenience method to add multiple substates. Supply a nil terminated comma separated list of substates.
 @see -addSubstate:
 @return Returns the receiver, to enable chaining-style programming
 */
- (YBState*)addSubstates:(YBState *)substates, ... NS_REQUIRES_NIL_TERMINATION;

/**
 Initiates a state transition from the current state to the specified target state.
 @param state - The name of the target state or the target state object itself
 */
- (void)gotoState:(id)state;

/**
 Initiates a state transition from the current state to the specified target state using the target state's state history
 @param state - The name of the target state or the target state object itself
 @param recursive - Enters history state recursively if YES, stops after the first history state if NO
 */
- (void)gotoHistoryState:(id)state recursive:(BOOL)recursive;

/**
 This method gets called every time this states becomes active. 
 Override this to perform custom state setup.
 */
- (void)enterState;

/**
 This method gets called every time this state becomes inactive.
 Override this to perform custom state teardown.
 */
- (void)exitState;

/**
 The name of the receiver as set in -initWithName: or +stateWithName:
 */
@property (nonatomic, readonly) NSString *name;

/**
 YES if the state is currently active, NO if it is not.
 @see -[YBStatechart activateState:]
 */
//@property (nonatomic, readonly) BOOL isActive;

/**
 The statechart that is associated with the receiver. It is automatically set when a rootState is assigned to the statechart, or when
 substates are added thereafter using -[YBState addSubstate:]
 @see -[YBStatechart setRootState:]
 @see -[YBState addSubstate:]
 */
@property (nonatomic, readonly, weak) YBStatechart *statechart;

/**
 The superstate of the receiver. Will be nil if the state is the root state or if the receiver has
 not been added as substate yet.
 @see -[YBState addSubstate:]
 */
@property (nonatomic, readonly, weak) YBState *superstate;

/**
 The initialSubstate is the substate that will be activated when the receiver is activated. In case there are no or one substates,
 this value has no effect. In case there are more than one substates, this value is required before the statechart that the receiver
 is part of can be activated. Setting initialSubstate will implicitely add the assigned state as a substate if has not been added
 using -addSubstate: before.
 In case the useHistory propery is set to YES, historySubstate will be used to decide which substate will be made active, unless
 there is no previous substate (history) known.
 */
@property (nonatomic) YBState *initialSubstate;

/**
 If substates are orthogonal (substatesAreOrthogonal is set to YES), they can be active/inactive independent of one another.
 If they are not orthogonal (substatesAreOrthonogal is set to NO), only one of the substates is active at a time and the others
 will be inactive. Default to NO.
 @see -[YBStatechart activateState:] to activate a state in the statechart.
 */
@property (nonatomic, assign) BOOL substatesAreOrthogonal;

/**
 The direct substates of the receiver that have been added.
 @see -[YBState addSubstate:]
 */
@property (nonatomic, readonly) NSSet *substates;

/**
 Set containing all current substates of this state
 */
@property (nonatomic, readonly) NSMutableSet *currentSubstates;

/**
 Set containing all currently entered substates of this state
 */
@property (nonatomic, readonly) NSMutableSet *enteredSubstates;

/**
 @return YES if the receiver is the current state
 */
- (BOOL)isCurrentState;

/**
 @return YES if the receiver is currently entered
 */
- (BOOL)isEnteredState;

/**
 @return YES if the receiver has substates
 */
- (BOOL)hasSubstates;

@end


#if DEBUG
@interface YBState (Debugging)

- (BOOL)debugValidate;

@end
#endif









