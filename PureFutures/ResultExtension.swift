//
//  ResultExtension.swift
//  PureFutures
//
//  Created by Victor Shamanov on 23.11.15.
//  Copyright © 2015 Victor Shamanov. All rights reserved.
//

extension Result {
    init<R: ResultType where R.Value == T, R.Error == Error>(result: R) {
        
        if let result = result as? Result {
            self = result
            return
        }
        
        var res: Result<T, Error>? {
            didSet {
                if oldValue != nil {
                    fatalError("Setting result twice")
                }
            }
        }
        
        result.analysis(ifSuccess: {
            res = .Success($0)
        }, ifFailure: {
            res = .Failure($0)
        })
        
        guard let result = res else {
            fatalError("Non of analisys closures was called")
        }
        
        self = result
    }
}
