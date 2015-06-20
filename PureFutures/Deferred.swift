//
//  Deferred.swift
//  PureFutures
//
//  Created by Victor Shamanov on 2/11/15.
//  Copyright (c) 2015 Victor Shamanov. All rights reserved.
//

import Foundation

// MARK:- deferred creation functions

/**

    Creates a new Deferred<T> whose value become
    result of execution `block` on background thread

    :param: block function, which result become value of Deferred

    :returns: a new Deferred<T>
    
*/
public func deferred<T>(block: () -> T) -> Deferred<T> {
    return deferred(ExecutionContext.DefaultPureOperationContext, block)
}

/**

    Creates a new Deferred<T> whose value become
    result of execution `block` on `ec` execution context

    :param: ec execution context of block
    :param: block function, which result become value of Deferred

    :returns: a new Deferred<T>
    
*/
public func deferred<T>(ec: ExecutionContextType, block: () -> T) -> Deferred<T> {
    let p = PurePromise<T>()
    
    ec.execute {
        p.complete(block())
    }
    
    return p.deferred
}

// MARK:- Deferred

/// Represents a value that will be available in the future.
public final class Deferred<T>: DeferredType {
    
    // MARK:- Type declarations
    
    public typealias Callback = T -> Void
    
    // MARK:- Private properties
    
    private var callbacks: [Callback] = []
    private let callbacksManagingQueue = dispatch_queue_create("com.wiruzx.PureFutures.Deferred.callbacksManaging", DISPATCH_QUEUE_SERIAL)
    
    // MARK:- Public properties
    
    /// Value of Deferred
    public private(set) var value: T?
    
    /// Shows if Deferred is completed
    public var isCompleted: Bool {
        return value != nil
    }
    
    // MARK:- Initialization
    
    internal init() {
    }
    
    public init<D: DeferredType where D.Element == T>(deferred: D) {
        deferred.onComplete(ExecutionContext.DefaultPureOperationContext, setValue)
    }
    
    /// Creates immediately completed Deferred with given value
    public static func completed(x: T) -> Deferred {
        let d = Deferred()
        d.setValue(x)
        return d
    }
    
    // MARK:- DeferredType methods
    
    /**
    
        Register an callback which will be called when Deferred completed
    
        :param: ec execution context of callback
        :param: c callback
    
        :returns: Returns itself for chaining operations
        
    */
    public func onComplete(ec: ExecutionContextType, _ c: Callback) -> Deferred {
        
        let callbackInContext = { result in
            ec.execute {
                c(result)
            }
        }
        
        dispatch_async(callbacksManagingQueue) {
            if let result = self.value {
                callbackInContext(result)
            } else {
                self.callbacks.append(callbackInContext)
            }
        }
        
        return self
    }
    
    // MARK:- Convenience methods
    
    /**
    
        Register an callback which will be called on main thread when Deferred completed
    
        :param: c callback
    
        :returns: Returns itself for chaining operations
        
    */
    public func onComplete(c: Callback) -> Deferred {
        return onComplete(ExecutionContext.DefaultSideEffectsContext, c)
    }

    // MARK:- Internal methods

    internal func setValue(value: T) {
        assert(self.value == nil, "Value can be set only once")
        
        dispatch_sync(callbacksManagingQueue) {
            
            self.value = value
            
            for callback in self.callbacks {
                callback(value)
            }
            
            self.callbacks.removeAll()
        }

    }

}

public extension Deferred {
    
    // MARK:- andThen
    
    /**

        Applies the side-effecting function that will be executed on main thread
        to the result of this deferred, and returns a new deferred with the result of this deferred

        :param: f side-effecting function that will be applied to result of deferred

        :returns: a new Deferred

    */
    func andThen(f: T -> Void) -> Deferred {
        #if os(iOS)
        return PureFutures.andThen(f)(self)
        #else
        return PureFuturesOSX.andThen(f)(self)
        #endif
    }
    
    /**

        Applies the side-effecting function to the result of this deferred,
        and returns a new deferred with the result of this deferred

        :param: ec execution context of `f` function
        :param: f side-effecting function that will be applied to result of deferred

        :returns: a new Deferred

    */
    func andThen(ec: ExecutionContextType, _ f: T -> Void) -> Deferred {
        #if os(iOS)
        return PureFutures.andThen(f, ec)(self)
        #else
        return PureFuturesOSX.andThen(f, ec)(self)
        #endif
    }
    
    // MARK:- forced
    
    /**

        Stops the current thread, until value of deferred becomes available

        :returns: value of deferred

    */
    func forced() -> T {
        #if os(iOS)
        return PureFutures.forced(self)
        #else
        return PureFuturesOSX.forced(self)
        #endif
    }
    
    
    /**

        Stops the currend thread, and wait for `inverval` seconds until value of deferred becoms available

        :param: inverval number of seconds to wait

        :returns: Value of deferred or nil if it hasn't become available yet

    */
    func forced(interval: NSTimeInterval) -> T? {
        #if os(iOS)
        return PureFutures.forced(interval)(self)
        #else
        return PureFuturesOSX.forced(interval)(self)
        #endif
    }
    
    // MARK:- map
    
    /**

        Creates a new deferred by applying a function `f` that 
        will be executed on global queue to the result of this deferred.
    
        Do not put any UI-related code into `f` function

        :param: f Function that will be applied to result of deferred

        :returns: a new Deferred

    */
    func map<U>(f: T -> U) -> Deferred<U> {
        #if os(iOS)
        return PureFutures.map(f)(self)
        #else
        return PureFuturesOSX.map(f)(self)
        #endif
    }
    
    /**

        Creates a new deferred by applying a function `f` to the result of this deferred.

        :param: ec Execution context of `f`
        :param: f Function that will be applied to result of deferred

        :returns: a new Deferred

    */
    func map<U>(ec: ExecutionContextType, _ f: T -> U) -> Deferred<U> {
        #if os(iOS)
        return PureFutures.map(f, ec)(self)
        #else
        return PureFuturesOSX.map(f, ec)(self)
        #endif
    }
    
    // MARK:- flatMap
    
    /**

        Creates a new deferred by applying a function that will be executed on global queue
        to the result of this deferred, and returns the result of the function as the new deferred.
    
        Do not put any UI-related code into `f` function

        :param: f Funcion that will be applied to result of deferred

        :returns: a new Deferred

    */
    func flatMap<U>(f: T -> Deferred<U>) -> Deferred<U> {
        #if os(iOS)
        return PureFutures.flatMap(f)(self)
        #else
        return PureFuturesOSX.flatMap(f)(self)
        #endif
    }

    /**

        Creates a new deferred by applying a function to the result of this deferred, 
        and returns the result of the function as the new deferred.

        :param: ec Execution context of `f`
        :param: f Funcion that will be applied to result of deferred

        :returns: a new Deferred

    */
    func flatMap<U>(ec: ExecutionContextType, _ f: T -> Deferred<U>) -> Deferred<U> {
        #if os(iOS)
        return PureFutures.flatMap(f, ec)(self)
        #else
        return PureFuturesOSX.flatMap(f, ec)(self)
        #endif
    }
    
    // MARK:- flatten
    
    /**

        Removes one level of nesting of Deferred

        :param: dx Deferred

        :returns: flattened Deferred

    */
    class func flatten(dx: Deferred<Deferred<T>>) -> Deferred<T> {
        #if os(iOS)
        return PureFutures.flatten(dx)
        #else
        return PureFuturesOSX.flatten(dx)
        #endif
    }
    
    // MARK:- filter

    /**

        Creates a new Deferred by filtering the value of the current Deferred 
        with a predicate `p` which will be executed on global queue

        Do not put any UI-related code into `p` function

        :param: ec Execution context of `p`
        :param: p Predicate function

        :returns: A new Deferred with value or nil

    */
    func filter(p: T -> Bool) -> Deferred<T?> {
        #if os(iOS)
        return PureFutures.filter(p)(self)
        #else
        return PureFuturesOSX.filter(p)(self)
        #endif
    }
    
    /**

        Creates a new Deferred by filtering the value of the current Deferred with a predicate `p`

        :param: ec Execution context of `p`
        :param: p Predicate function

        :returns: A new Deferred with value or nil

    */
    func filter(ec: ExecutionContextType, _ p: T -> Bool) -> Deferred<T?> {
        #if os(iOS)
        return PureFutures.filter(p, ec)(self)
        #else
        return PureFuturesOSX.filter(p, ec)(self)
        #endif
    }
    
    // MARK:- zip
    
    /**

        Zips two deferred together and returns a new Deferred which contains a tuple of two elements

        :param: dx Another deferred

        :returns: Deferred with resuls of two deferreds

    */
    func zip<U>(dx: Deferred<U>) -> Deferred<(T, U)> {
        #if os(iOS)
        return PureFutures.zip(self)(dx)
        #else
        return PureFuturesOSX.zip(self)(dx)
        #endif
    }
    
    // MARK:- reduce
    
    /**

        Reduces the elements of sequence of deferreds using the specified reducing function `combine`
        which will be executed on global queue

        Do not put any UI-related code into `combine` function

        :param: dxs Sequence of Deferred
        :param: initial Initial value that will be passed as first argument in `combine` function
        :param: combine reducing function

        :returns: Deferred which will contain result of reducing sequence of deferreds

    */
    class func reduce<U>(dxs: [Deferred], _ initial: U, _ combine: (U, T) -> U) -> Deferred<U> {
        #if os(iOS)
        return PureFutures.reduce(combine, initial)(dxs)
        #else
        return PureFuturesOSX.reduce(initial, combine)(dxs)
        #endif
    }
    
    /**

        Reduces the elements of sequence of deferreds using the specified reducing function `combine`

        :param: ec Execution context of `combine`
        :param: dxs Sequence of Deferred
        :param: initial Initial value that will be passed as first argument in `combine` function
        :param: combine reducing function

        :returns: Deferred which will contain result of reducing sequence of deferreds

    */
    class func reduce<U>(ec: ExecutionContextType, _ dxs: [Deferred], _ initial: U, _ combine: (U, T) -> U) -> Deferred<U> {
        #if os(iOS)
        return PureFutures.reduce(combine, initial, ec)(dxs)
        #else
        return PureFuturesOSX.reduce(initial, combine, ec)(dxs)
        #endif
    }
    
    // MARK:- traverse
    
    /**

        Transforms a sequence of values into Deferred of array of this values using the provided function `f`
        which will be executed on global queue

        Do not put any UI-related code into `f` function

        :param: xs Sequence of values
        :param: f Function for transformation values into Deferred

        :returns: a new Deferred

    */
    class func traverse<U>(xs: [T], _ f: T -> Deferred<U>) -> Deferred<[U]> {
        #if os(iOS)
        return PureFutures.traverse(f)(xs)
        #else
        return PureFuturesOSX.traverse(f)(xs)
        #endif
    }
    
    /**

        Transforms a sequence of values into Deferred of array of this values using the provided function `f`

        :param: ec Execution context of `f`
        :param: xs Sequence of values
        :param: f Function for transformation values into Deferred

        :returns: a new Deferred

    */
    class func traverse<U>(ec: ExecutionContextType, _ xs: [T], _ f: T -> Deferred<U>) -> Deferred<[U]> {
        #if os(iOS)
        return PureFutures.traverse(f, ec)(xs)
        #else
        return PureFuturesOSX.traverse(f, ec)(xs)
        #endif
    }
    
    // MARK:- sequence
    
    /**

        Transforms a sequnce of Deferreds into Deferred of array of values:

        :param: dxs Sequence of Deferreds

        :returns: Deferred with array of values

    */
    class func sequence(dxs: [Deferred]) -> Deferred<[T]> {
        #if os(iOS)
        return PureFutures.sequence(dxs)
        #else
        return PureFuturesOSX.sequence(dxs)
        #endif
    }
    
    // MARK:- toFuture
    
    /**

        Transforms Deferred into Future

        :param: dx Deferred

        :returns: a new Future with result of Deferred

    */
    class func toFuture<E>(dx: Deferred<Result<T, E>>) -> Future<T, E> {
        #if os(iOS)
        return PureFutures.toFuture(dx)
        #else
        return PureFuturesOSX.toFuture(dx)
        #endif
    }
    
}
