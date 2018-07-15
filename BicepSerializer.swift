//
//  BicepSerializer.swift
//  HomeNAS
//
//  Created by SDH on 28/05/2017.
//  Copyright © 2017 sdaheng. All rights reserved.
//

import Foundation
import Alamofire

#if canImport(SwiftProtobuf)
import SwiftProtobuf
#endif

protocol BicepsRequestSerializer {
    
}

protocol BicepsResponseSerializer {
    
}

struct ProtobufEncoding: ParameterEncoding {
    
    #if canImport(SwiftProtobuf)
    var message: SwiftProtobuf.Message?
    var messageData: Data?
    
    init(_ _message: SwiftProtobuf.Message?) {
        message = _message
    }
    
    init(_ _messageData: Data?) {
        messageData = _messageData
    }
    
    func encode(_ urlRequest: URLRequestConvertible,
                with parameters: Parameters?) throws -> URLRequest {
        var _urlRequest = try urlRequest.asURLRequest()
        
        guard let message = self.messageData else {
            return _urlRequest
        }
        _urlRequest.httpBody = message
        
        return _urlRequest
    }
    
    func encode<T: SwiftProtobuf.Message>(_ urlRequest: URLRequestConvertible,
                                          with message: T?) throws -> URLRequest {
        var _urlRequest = try urlRequest.asURLRequest()
        
        guard let m = message else {
            return _urlRequest
        }
        
        let data = try m.serializedData()
        
        _urlRequest.httpBody = data
        
        return _urlRequest
    }
    #endif
}

extension DataRequest {
    
    public class func protobufResponseSerializer()
        -> DataResponseSerializer<Any> {
            return DataResponseSerializer { _, response, data, error in

                let result = Request.serializeResponseData(response: response,
                                                           data: data,
                                                           error: error)
                
                if let err = result.error {
                    return .failure(err)
                }
                
                return .success(result.value as Any)
            }
    }
    
    @discardableResult
    public func responseProtobuf(queue: DispatchQueue? = nil,
                                 completionHandler: @escaping (DataResponse<Any>) -> Void) -> Self {
            return response(queue: queue,
                            responseSerializer: DataRequest.protobufResponseSerializer(),
                            completionHandler: completionHandler)
    }
}
