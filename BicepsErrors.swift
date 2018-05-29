//
//  BicepsErrors.swift
//  HomeNAS
//
//  Created by SDH on 2018/5/24.
//  Copyright © 2018 sdaheng. All rights reserved.
//

import Foundation

// MARK: Biceps Errors
public enum BicepsError: Error {
    public enum UnimplementedMethodError: Error {
        case fetch
        case send
    }
    
    public enum DependencyError: Error {
        case cycle
    }
    
    public enum InvalidateParameterError: Error {
        case dictionary
        case protobufMessage
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

extension BicepsError.InvalidateParameterError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dictionary:
            return "Its not a valid dictionary"
        case .protobufMessage:
            return "Its not protobuf message"
        }
    }
}
