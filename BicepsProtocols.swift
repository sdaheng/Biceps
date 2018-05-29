//
//  BicepsProtocols.swift
//  Biceps
//
//  Created by SDH on 2018/5/23.
//  Copyright © 2018 sdaheng. All rights reserved.
//

import Foundation
import Alamofire
import SwiftProtobuf

public protocol ParameterConvertible {
    func asDictionary() throws -> [String:Any]?
    func asMessage() throws -> SwiftProtobuf.Google_Protobuf_Any?
    func asData() throws -> Data?
}

internal protocol BicepsRequestable {    
    func request() -> DataRequest?
}

internal protocol BicepsURLRequestable: BicepsRequestable {
}

internal protocol BicepsJSONRequestable: BicepsRequestable {
}

internal protocol BicepsProtobufRequestable: BicepsRequestable {
}


internal protocol BicepsOperatable {
    func cancel(_ task: URLSessionTask)
    func resume(_ task: URLSessionTask)
    func suspend(_ task: URLSessionTask)
}

internal protocol BicepsUploadable: BicepsOperatable {
    func upload(URL: URL, filePath: String, headers: [String:String]?,
                progress: @escaping ProgressBlock,
                success: @escaping SuccessBlock,
                fail: @escaping FailBlock) -> URLSessionTask?
    
    func upload(URL: URL, mutipartFormData: @escaping (MultipartFormData) -> Void,
                headers: [String:String]?,
                progress: @escaping ProgressBlock,
                success: @escaping SuccessBlock,
                fail: @escaping FailBlock) -> URLSessionTask?
}

internal protocol BicepsBackgroundUploadable: BicepsUploadable {
}

internal protocol BicepsDownloadable: BicepsOperatable {
    func download(URL: URLConvertible, paramater: ParameterConvertible?,
                  configuration: BicepsConfigurable, destination: URL,
                  progress: @escaping ProgressBlock,
                  success: @escaping SuccessBlock,
                  fail: @escaping FailBlock) -> URLSessionTask?
}

internal protocol BicepsBackgroundDownloadable: BicepsDownloadable {
}

internal protocol BicepsResumeDownloadable: BicepsDownloadable {
}

internal protocol BicepsResponsable {
    func response(dataResponse: DefaultDataResponse);
}

