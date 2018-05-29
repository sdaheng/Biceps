//
//  BicepsOperation.swift
//  HomeNAS
//
//  Created by SDH on 2018/5/24.
//  Copyright © 2018 sdaheng. All rights reserved.
//

import Foundation

class BicepsOperationQueue {
    let operationQueue: OperationQueue
    let operationUnderlyingQueue: DispatchQueue
    static let shared = BicepsOperationQueue()
    
    init() {
        let underlyingQueue = DispatchQueue(label: "com.body.biceps.operationQueue.underlyingQueue")
        self.operationUnderlyingQueue = underlyingQueue
        self.operationQueue = OperationQueue()
        self.operationQueue.underlyingQueue = underlyingQueue
        self.operationQueue.qualityOfService = .userInitiated
        self.operationQueue.name = "com.body.biceps.operationQueue.request"
    }
}

class BicepsOperation: Operation {
    
    var biceps: Biceps
    
    var _finished: Bool = false {
        willSet {
            self.willChangeValue(forKey: "isFinished")
        }
        
        didSet {
            self.didChangeValue(forKey: "isFinished")
        }
    }
    var _executing: Bool = false {
        willSet {
            self.willChangeValue(forKey: "isExecuting")
        }
        
        didSet {
            self.didChangeValue(forKey: "isExecuting")
        }
    }
    
    init(_ biceps: Biceps) {
        self.biceps = biceps
    }
    
    override func start() {
        
        guard self.isReady else {
            return
        }
        
        let progress = biceps.internalProgressBlock
        let success = biceps.internalSuccessBlock
        let fail = biceps.internalFailBlock
        
        self.biceps.progress({ [unowned self] ( _progress) in
            self._finished = false
            self._executing = true
            
            progress(_progress)
        }).success { [unowned self] (result) in
            self._finished = true
            self._executing = false
            
            success(result)
        }.fail({ [unowned self] (error) in
            self._finished = true
            self._executing = false
            
            fail(error)
        }).dispatchRequest(for: self.biceps.internalType,
                           paramaterEncodingType: self.biceps.internalParameterEncodingType,
                           paramaters: self.biceps.internalParamaters)
        
    }
    
    override var isExecuting: Bool {
        return _executing
    }
    
    override var isFinished: Bool {
        return _finished
    }
}
