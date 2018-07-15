//
//  BicepsHTTP.swift
//  HomeNAS
//
//  Created by SDH on 03/04/2017.
//  Copyright © 2017 sdaheng. All rights reserved.
//

import Foundation
import Alamofire

#if canImport(SwiftProtobuf)
import SwiftProtobuf
#endif

// MARK: Real request layer

public let BackgroundSessionIdentifier = "com.body.biceps.backgroundSession"

class BicepsHTTP {
    
    static let shared: BicepsHTTP = BicepsHTTP()
    
    internal lazy var session: Alamofire.SessionManager = {
        let configuration = URLSessionConfiguration.default
        
        if let interceptor = self.interceptor, interceptor.useDefaultInterceptor == false {
            configuration.protocolClasses = interceptor.customURLProtocols
        } else {
            configuration.protocolClasses = [(self.customURLProtocols?.first)!]
        }
        
        let sessionManager = Alamofire.SessionManager(configuration: configuration)
        
        if let receiveChallenge = self.generalConfiguartion.sessionDidReceiveChallengeWithCompletion {
            sessionManager.delegate.sessionDidReceiveChallengeWithCompletion = receiveChallenge
        }

        return sessionManager
    }()
    
    internal lazy var backgroundSession: Alamofire.SessionManager = {
        
        let configuration = URLSessionConfiguration.background(withIdentifier: BackgroundSessionIdentifier)
        
        if let interceptor = self.interceptor, interceptor.useDefaultInterceptor == false {
            configuration.protocolClasses = interceptor.customURLProtocols
        } else {
            configuration.protocolClasses = [(self.customURLProtocols?.first)!]
        }
        
        let sessionManager = Alamofire.SessionManager(configuration: configuration)
        
        if let completionHandler = self.generalConfiguartion.backgroundCompletionHander {
            sessionManager.backgroundCompletionHandler = completionHandler
        }
        
        if let receiveChallenge = self.generalConfiguartion.sessionDidReceiveChallengeWithCompletion {
            sessionManager.delegate.sessionDidReceiveChallengeWithCompletion = receiveChallenge
        }
        
        return sessionManager
    }()
}

extension BicepsHTTP {
    var generalConfiguartion: BicepsConfigurable {
        return BicepsGeneralConfiguration.shared
    }
}

extension BicepsHTTP {
    func convertMethod(_ type: BicepsType) -> HTTPMethod {
        switch type {
        case .GET:    return .get
        case .POST:   return .post
        case .HEAD:   return .head
        case .DELETE: return .delete
        case .OPTIONS: return .options
        case .PUT: return .put
        case .PATCH: return .patch
        case .CONNECT: return .connect
        case .TRACE: return .trace
        }
    }
}

extension BicepsHTTP {
    func createURLRequester(with URL: URL, and type: BicepsType) -> Requester {
        return Requester(requestURL: URL, type: type)
    }

    func createJSONRequester(with URL: URL, and type: BicepsType) -> JSONRequester {
        return JSONRequester(requestURL: URL, type: type)
    }
    
    func createProtobufRequester(with URL: URL, and type: BicepsType) -> ProtobufRequester {
        return ProtobufRequester(requestURL: URL, type: type)
    }
}

extension BicepsHTTP {
    struct BicepsHTTPResponser: BicepsResponsable {
        var progress: ProgressBlock?
        var success: SuccessBlock
        var fail: FailBlock

        func response(dataResponse: DefaultDataResponse) {
            guard let contentType =  dataResponse.response?.allHeaderFields["Content-Type"] as? String
            else { return }
            
            let response = ResponseDispatcher.Responsable.response((dataResponse.request)!,
                                                                    dataResponse.response!,
                                                                    dataResponse.data,
                                                                    dataResponse.error)
            let responserOperations = ResponseDispatcher.Operations.operations(progress!, success, fail)
            
            let dispatcher = ResponseDispatcher.responseDispatcher
            switch contentType {
            case JSONMIMEType:
                dispatcher.dispatch(to: DataRequest.jsonResponseSerializer(),
                                    with: response,
                                    and: responserOperations)
            case ProtobufMIMEType:
                dispatcher.dispatch(to: DataRequest.protobufResponseSerializer(),
                                    with: response,
                                    and: responserOperations)
            default:
                dispatcher.dispatch(to: DataRequest.dataResponseSerializer(),
                                    with: response,
                                    and: responserOperations)
            }
        }
    }
    
    func handleResponse(result: Result<Any>, success: SuccessBlock, fail: FailBlock) {
        if result.isSuccess {
            if let ret = result.value {
                success(ret)
            }
        } else if result.isFailure {
            if let err = result.error {
                fail(err)
            }
        }
    }
}

extension BicepsHTTP: BicepsInterceptable {
    var customURLProtocols: Array<AnyClass>? {
        get {
            return [ BicepsLogProtocol.self ]
        }
    }
    
    var interceptor: BicepsInterceptable? {
        return BicepsGeneralConfiguration.shared.interceptor
    }
}

class BicepsConnector {
    func connect(requester: BicepsRequestable, with responser: BicepsResponsable) {
        requester.request()?.response(completionHandler: { (response) in
            responser.response(dataResponse: response)
        })
    }
}
