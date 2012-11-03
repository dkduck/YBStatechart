//
//  YBStatechart.h
//  YBStatechart
//
//  Created by Martijn Thé on 3/26/12.
//  Copyright (c) 2012 Yobble. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class YBState;


/**
 Statecharts are represented using instances of YBStatechart.
 For more information on statecharts, see David Harel's white paper from 1986:
 http://www.wisdom.weizmann.ac.il/~harel/SCANNED.PAPERS/Statecharts.pdf
 
 A statechart object contains one rootState, which acts as an encapsulation for other substates (which can in turn have other substates
 as well). A YBStatechart instance plays the central role of activating a particular state and ensuring the appropriate sibling-,
 sub- and super- states get activated and deactivated.

 The statechart is a UIResponder subclass, so it can be hooked into the responder chain.
 Any unknown selector with zero to two arguments will be dispatched to the currently active states.
 */
@interface YBStatechart : UIResponder

/**
 The top-level state that encapsulates every other state inside the statechart.
 Setting the rootState will automatically associate all the states with the statechart.
 */
@property (nonatomic, strong, readwrite) YBState *rootState;

/**
 Override this method to do your custom statechart setup like e.g. setting the root state.
 This method gets called when you call -activate on the statechart.
 */
- (void)setup;

/**
 Attemps to find the state with given name in all the states that are currently associated with the statechart.
 @param stateName - The name of the state to look for
 @returns - The found state or nil if no state could be found
 */
- (YBState*)findStateWithName:(NSString*)stateName;

/**
 Activates the statechart. All initial and/or history substates will be entered/activated.
 @see isActive
 */
- (void)activate;

/**
 Returns YES if the statechart is active or NO is it is inactive.
 */
@property (nonatomic, assign, readonly) BOOL isActive;

@end


#if DEBUG
@interface YBStatechart (Debugging)
/**
 Validates if the statechart is fully-defined. Prints the parameters that need to be defined in order to make the statechart fully-defined (e.g. missing `initialSubstate` values).
 @returns YES if the statechart is fully-defined, or NO if there are parameters missing.
 */
- (BOOL)debugValidate;
@end
#endif






