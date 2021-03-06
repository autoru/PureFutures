//
//  DeferredTypeFunctions.swift
//  PureFutures
//
//  Created by Victor Shamanov on 2/24/15.
//  Copyright (c) 2015 Victor Shamanov. All rights reserved.
//

import typealias Foundation.NSTimeInterval

extension DeferredType {
    
    /**

        Applies the side-effecting function to the result of this deferred,
        and returns a new deferred with the result of this deferred

        - parameter ec: execution context of `f` function. By default is main queue
        - parameter f: side-effecting function that will be applied to result of `dx`

        - returns: a new Deferred

    */
    public func andThen(ec: ExecutionContextType = SideEffects, f: Value -> Void) -> Deferred<Value> {
        let p = PurePromise<Value>()
        
        onComplete(ec) { value in
            p.complete(value)
            f(value)
        }
        
        return p.deferred
    }
    
    /**

        Blocks the current thread, until value of `dx` becomes available

        - returns: value of deferred

    */
    public func forced() -> Value {
        return forced(NSTimeInterval.infinity)!
    }
    
    /**

        Blocks the currend thread, and wait for `inverval` seconds until value of `dx` becoms available

        - parameter inverval: number of seconds to wait

        - returns: Value of deferred or nil if it hasn't become available yet

    */
    public func forced(interval: NSTimeInterval) -> Value? {
        return await(interval) { completion in
            self.onComplete(Pure, completion)
            return
        }
    }
    
    /**

        Creates a new deferred by applying a function `f` to the result of this deferred.

        - parameter ec: Execution context of `f`. By defalut is global queue
        - parameter f: Function that will be applied to result of `dx`

        - returns: a new Deferred

    */
    public func map<T>(ec: ExecutionContextType = Pure, f: Value -> T) -> Deferred<T> {
        let p = PurePromise<T>()
        
        onComplete(ec) { x in
            p.complete(f(x))
        }
        
        return p.deferred
    }
    
    /**

        Creates a new deferred by applying a function to the result of this deferred, and returns the result of the function as the new deferred.

        - parameter ec: Execution context of `f`. By defalut is global queue
        - parameter f: Funcion that will be applied to result of `dx`

        - returns: a new Deferred

    */
    public func flatMap<D: DeferredType>(ec: ExecutionContextType = Pure, f: Value -> D) -> Deferred<D.Value> {
        let p = PurePromise<D.Value>()
        
        onComplete(ec) { x in
            p.completeWith(f(x))
        }
        
        return p.deferred
    }
    
    /**

        Creates a new Deferred by filtering the value of the current Deferred with a predicate `p`

        - parameter ec: Execution context of `p`. By defalut is global queue
        - parameter p: Predicate function

        - returns: A new Deferred with value or nil

    */
    public func filter(ec: ExecutionContextType = Pure, p: Value -> Bool) -> Deferred<Value?> {
        return map(ec) { x in p(x) ? x : nil }
    }
    
    /**

        Zips with another Deferred and returns a new Deferred which contains a tuple of two elements

        - parameter d: Another deferred

        - returns: Deferred with resuls of two deferreds

    */
    public func zip<D: DeferredType>(d: D) -> Deferred<(Value, D.Value)> {
        
        let ec = Pure
        
        return flatMap(ec) { a in
            d.map(ec) { b in
                (a, b)
            }
        }
    }
    
    /**
        Maps the result of the current deferred using the `f` function and zips it 
        with the current result of deferred.
     
        - see: zip and map functions
     
        - parameter ec: Execution context of `f` function. By default is global queue
        - parameter f: mapping function
     
        - returns: Deferred with tuple of current value and result of mapping
    */
    public func zipMap<U>(ec: ExecutionContextType = Pure, f: Value -> U) -> Deferred<(Value, U)> {
        return zip(map(ec, f: f))
    }
}

// MARK: - Nested DeferredType extensions

extension DeferredType where Value: DeferredType {
    /**

        Converts Deferred<Deferred<T>> into Deferred<T>

        - parameter dx: Deferred

        - returns: flattened Deferred

    */
    public func flatten() -> Deferred<Value.Value> {
        let p = PurePromise<Value.Value>()
        
        let ec = Pure
        
        onComplete(ec) { d in
            p.completeWith(d)
        }
        
        return p.deferred
    }
}

// MARK: - SequenceTyep extensions

extension SequenceType where Generator.Element: DeferredType {
    
    /**

        Reduces the elements of sequence of deferreds using the specified reducing function `combine`

        - parameter ec: Execution context of `combine`. By defalut is global queue
        - parameter combine: reducing function
        - parameter initial: Initial value that will be passed as first argument in `combine` function

        - returns: Deferred which will contain result of reducing sequence of deferreds

    */
    public func reduce<T>(ec: ExecutionContextType = Pure, initial: T, combine: ((T, Generator.Element.Value) -> T)) -> Deferred<T> {
        return reduce(.completed(initial)) { acc, d in
            d.flatMap(ec) { x in
                acc.map(ec) { combine($0, x) }
            }
        }
    }
    
    /**

        Transforms a sequnce of Deferreds into Deferred of array of values:

        [Deferred<T>] -> Deferred<[T]>

        - parameter dxs: Sequence of Deferreds

        - returns: Deferred with array of values

    */
    public func sequence() -> Deferred<[Generator.Element.Value]> {
        return traverse(Pure, f: identity)
    }
    
}

extension SequenceType {
    
    /**

        Transforms a sequence of values into Deferred of array of this values using the provided function `f`

        - parameter ec: Execution context of `f`. By defalut is global queue
        - parameter f: Function for transformation values into Deferred

        - returns: a new Deferred

    */
    public func traverse<D: DeferredType>(ec: ExecutionContextType = Pure, f: Generator.Element -> D) -> Deferred<[D.Value]> {
        // TODO: Replace $0 + [$1] with the more efficient variant
        return map(f).reduce(ec, initial: []) { $0 + [$1] }
    }
}

// MARK: - Convenience extension

extension DeferredType {
    public func onComplete(c: Value -> Void) -> Self {
        return onComplete(SideEffects, c)
    }
}
