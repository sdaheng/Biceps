//
//  BicepsScheduler.swift
//  HomeNAS
//
//  Created by SDH on 26/04/2017.
//  Copyright © 2017 sdaheng. All rights reserved.
//

import Foundation

class Scheduler {
    private var underlyingQueue = BicepsOperationQueue.shared.operationUnderlyingQueue
    
    func delay(_ seconds: TimeInterval, execute: @escaping ()->Void) {
        underlyingQueue.asyncAfter(deadline: DispatchTime.now() + seconds,
                                    execute: {
            execute()
        })
    }
    
    func deliver(on queue: DispatchQueue, execute: @escaping ()->Void) {
        underlyingQueue = queue
        
        underlyingQueue.async(execute: execute)
    }
    
    class func schedule(on queue: DispatchQueue) -> Scheduler {
        let scheduler = Scheduler()
        scheduler.underlyingQueue = queue
        return scheduler
    }

    class func scheduleOnMainQueue() -> Scheduler {
        return schedule(on: DispatchQueue.main)
    }
    
    class func scheduleOnGlobalQueue() -> Scheduler {
        return schedule(on: DispatchQueue.global())
    }
}
