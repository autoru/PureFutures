//
//  Future.swift
//  PureFutures
//
//  Created by Victor Shamanov on 2/11/15.
//  Copyright (c) 2015 Victor Shamanov. All rights reserved.
//

import typealias Foundation.NSTimeInterval
import class Foundation.NSError

// MARK:- future creation function

/**

    Creates a new `Future<T, E>` whose value will be
    result of execution `f` on `ec` execution context

    - parameter ec: execution context of given function (global queue by default)
    - parameter f: function, which result will become value of returned Future

    - returns: a new Future<T, E>
    
*/
public func future<T, E>(ec: ExecutionContextType = Pure, f: () -> Result<T, E>) -> Future<T, E> {
    let p = Promise<T, E>()
    
    ec.execute {
        p.complete(f())
    }
    
    return p.future
}

/**
     Creates a new `Future<T, E>` whose value will be
     result of execution throwing function `f` on `ec` execution context
     
     - parameter ec: execution context of given function (global queue by default)
     - parameter f: throwing function, which result will become value of returned Future
     
     - returns: a new Future<T, NSError>
*/
public func future<T>(ec: ExecutionContextType = Pure, f: () throws -> T) -> Future<T, NSError> {
    return future { materialize(f) }
}

// MARK:- Future

/**

    Represents a value that will be available in the future

    This value is usually result of some computation or network request.

    May completes with either `Success` and `Error` cases

    This is convenient way to use `Deferred<Result<T, E>>`

    See also: `Deferred`

*/

public final class Future<T, E: ErrorType>: FutureType {
    
    // MARK:- Type declarations
    
    public typealias Value = Result<T, E>
    
    public typealias CompleteCallback = Value -> Void
    public typealias SuccessCallback = T -> Void
    public typealias ErrorCallback = E -> Void
    
    // MARK:- Private properties
    
    private let deferred: Deferred<Value>
    
    // MARK:- Public properties

    /// Value of Future
    public private(set) var value: Value? {
        set {
            deferred.setValue(newValue!)
        }
        get {
            return deferred.value
        }
    }

    /// Shows if Future is completed
    public var isCompleted: Bool {
        return deferred.isCompleted
    }
    
    // MARK:- Initialization
    
    internal init() {
        deferred = Deferred()
    }
    
    internal init(deferred: Deferred<Value>) {
        self.deferred = deferred
    }
    
    public init<F: FutureType where F.Value.Value == T, F.Value.Error == E>(future: F) {
        deferred = future.map { Result(result: $0) }
    }
    
    // MARK:- Class methods

    /**
    
        Returns a new immediately completed `Future<T, E>` with given `value`

        - parameter value: value which Future will have

        - returns: a new Future

    */
    public class func succeed(value: T) -> Future {
        return .completed(.Success(value))
    }


    /**

        Returns a new immediately completed `Future<T, E>` with given `error`

        - parameter error: error which Future will have

        - returns: a new Future
        
    */
    public class func failed(error: E) -> Future {
        return .completed(.Failure(error))
    }
    
    /// Creates a new Future with given Result<T, E>
    public static func completed(x: Value) -> Future {
        return Future(deferred: .completed(x))
    }

    // MARK:- FutureType methods

    /**

        Register a callback which will be called when Future is completed

        - parameter ec: execution context of callback
        - parameter c: callback

        - returns: Returns itself for chaining operations
        
    */
    public func onComplete(ec: ExecutionContextType = SideEffects, _ c: CompleteCallback) -> Future {
        deferred.onComplete(ec, c)
        return self
    }

    // MARK:- Internal methods
    
    internal func setValue<R: ResultType where R.Value == T, R.Error == E>(value: R) {
        self.value = Result(result: value)
    }
    
}
