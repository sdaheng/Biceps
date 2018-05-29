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
public typealias SuccessBlock = (_ result: Any) -> Void
public typealias FailBlock = (_ error: Error) -> Void
public typealias BackgroundCompletionHandler = () -> Void
public typealias MultipartFormDataBlock = (MultipartFormData) -> Void

public enum ParamaterEncodingType {
    case URL
    case JSON
    case protobuf
}

let JSONMIMEType = "application/json"
let ProtobufMIMEType = "application/x-protobuf"
let BinaryMIMEType = "application/octet-stream"
