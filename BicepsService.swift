//
//  BicepsService.swift
//  HomeNAS
//
//  Created by SDH on 03/04/2017.
//  Copyright © 2017 sdaheng. All rights reserved.
//

import Foundation

// MARK: Service Layer
public protocol BicepsProvidable {
    func fetch(paramater: [String:Any]?, resultBlock: @escaping (_ result: Any?)->Void) throws -> Biceps
    func send(paramater: [String:Any]?, resultBlock: @escaping (_ result: Any?)->Void)  throws -> Biceps
}

public extension BicepsProvidable {
    func fetch(paramater: [String:Any]?, resultBlock: @escaping (_ result: Any?)->Void) throws -> Biceps {
        throw BicepsError.UnimplementedMethodError.fetch
    }
    
    func send(paramater: [String:Any]?, resultBlock: @escaping (_ result: Any?)->Void) throws -> Biceps {
        throw BicepsError.UnimplementedMethodError.send
    }
}

open class BicepsService {
    open class func fetch<T: BicepsProvidable>(by provider: T, paramater: [String:Any]?, resultBlock: @escaping (_ result: Any?) -> Void) throws {
        do {
            let biceps = try provider.fetch(paramater: paramater, resultBlock: resultBlock)
            
            try add(biceps, to: BicepsOperationQueue.shared.operationQueue)
        } catch {
            throw BicepsError.UnimplementedMethodError.fetch
        }
    }
    
    open class func send<T: BicepsProvidable>(by provider: T, paramater: [String:Any]?, resultBlock: @escaping (_ result: Any?) -> Void) throws {
        do {
            let biceps = try provider.send(paramater: paramater, resultBlock: resultBlock)
            
            try add(biceps, to: BicepsOperationQueue.shared.operationQueue)
        } catch {
            throw BicepsError.UnimplementedMethodError.send
        }
    }
    
    class func add(_ biceps: Biceps, to queue: OperationQueue) throws {
        let operationQueue = queue
        if let combinedRequests = biceps.combinedRequest {
            operationQueue.addOperations(combinedRequests.map { (biceps) in
                return BicepsOperation(biceps)
            }, waitUntilFinished: false)
        } else if biceps.hasDependency() {
            guard let dependency = biceps.dependency, dependency != biceps else {
                throw BicepsError.DependencyError.cycle
            }
            operationQueue.addOperations(resolveDependencyChain(from: biceps),
                                         waitUntilFinished: false)
        } else {
            operationQueue.addOperation(BicepsOperation(biceps))
        }
    }
    
    class func resolveDependencyChain(from head: Biceps) -> [BicepsOperation] {
        var dependencyChain = head
        var dependencyOperation = BicepsOperation(head)
        var dependencyOperations = Set<BicepsOperation>()
        while dependencyChain.hasDependency() {
            if let depsDependency = dependencyChain.dependency {
                
                let depsDependencyOperation = BicepsOperation(depsDependency)
                dependencyOperation.addDependency(depsDependencyOperation)
                dependencyOperations.insert(dependencyOperation)
                if !depsDependency.hasDependency() {
                    dependencyOperations.insert(depsDependencyOperation)
                }
                dependencyOperation = depsDependencyOperation
                dependencyChain = depsDependency
            }
        }
        
        return dependencyOperations.map { return $0 }
    }
}
