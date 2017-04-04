//
//  BicepsDefines.swift
//  HomeNAS
//
//  Created by SDH on 03/04/2017.
//  Copyright © 2017 sdaheng. All rights reserved.
//

import Foundation
import Alamofire

public enum BicepsLogLevel: String {
    case All    = "All"
    case Debug  = "Debug"
    case Info   = "Info"
    case Error  = "Error"
    case Off    = "Off"
}

internal enum BicepsType {
    case GET
    case POST
    case HEAD
    case DELETE
    case PUT
    case PATCH
    case OPTIONS
    case CONNECT
    case TRACE
}

let defaultRequestName: String = "com.body.biceps.annoymous"

public typealias ProgressBlock = (_ progress: Progress) -> Void
public typealias SuccessBlock = (_ result: Dictionary<String, Any>) -> Void
public typealias FailBlock = (_ error: Error) -> Void
public typealias BackgroundCompletionHandler = () -> Void
public typealias MultipartFormDataBlock = (MultipartFormData) -> Void

// MARK: Biceps Errors
public enum BicepsError: Error {
    public enum UnimplementedMethodError: Error {
        case fetch
        case send
    }
    
    public enum DependencyError: Error {
        case cycle
    }
}

extension BicepsError.UnimplementedMethodError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .fetch: return "BicepsUnimplementMethodError: not implement fetch method"
        case .send : return "BicepsUnimplementMethodError: not implement send method"
        }
    }
}

extension BicepsError.DependencyError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .cycle: return "Shouldn`t create a circular dependency"
        }
    }
}

let JSONMIMEType = "application/json"

