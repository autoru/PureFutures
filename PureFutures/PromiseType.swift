//
//  PromiseType.swift
//  PureFutures
//
//  Created by Victor Shamanov on 2/24/15.
//  Copyright (c) 2015 Victor Shamanov. All rights reserved.
//

import Foundation

public protocol PromiseType: PurePromiseType {
    
    typealias Def: FutureType
    typealias SuccessType = Def.SuccessType
    typealias ErrorType = Def.ErrorType

    func success(value: SuccessType)
    func error(error: ErrorType)
    
}