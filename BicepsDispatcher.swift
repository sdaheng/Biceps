//
//  BicepsDispatcher.swift
//  Biceps
//
//  Created by SDH on 2018/5/24.
//  Copyright © 2018 sdaheng. All rights reserved.
//

import Foundation
import Alamofire
import SwiftProtobuf

enum Dispatcher {
    
    internal enum Disposition {
        case foreground
        case background
        case resumeable
    }
    
    internal enum Operation {
        case start
        case resume
        case suspend
        case cancel
    }
    
    internal enum Requestable {
        case type(ParamaterEncodingType, ParameterConvertible?)
    }
    
    internal enum Uploadable {
        case file(String)
        case multipart(MultipartFormDataBlock)
        #if unimplement
        case data
        case stream
        #endif
    }
    
    internal enum Downloadable {
        case file(String)
    }
    
    case request(Disposition, Requestable)
    case upload(Disposition, Uploadable)
    case download(Disposition, Downloadable)
    
    func dispatch(_ biceps: Biceps, with operation: Operation) {
        switch self {
        case let .request(disposition, requestable):
            switch disposition {
            case .foreground:
                switch requestable {
                case let .type(paramaterEncodingType, _):
                    switch paramaterEncodingType {
                    case .URL:
                        dispatch(request: biceps, to: biceps.requester,
                                 with: operation, and: requestable)
                    case .JSON:
                        dispatch(request: biceps, to: biceps.jsonRequester,
                                 with: operation, and: requestable)
                    case .protobuf:
                        dispatch(request: biceps, to: biceps.protobufRequester,
                                 with: operation, and: requestable)

                    }
                }
            default:
                break
            }
        case let .upload(disposition, uploadable):
            switch disposition {
            case .foreground:
                dispatch(upload: biceps, to: biceps.uploader,
                         with: operation, and: uploadable)
            case .background:
                dispatch(upload: biceps, to: biceps.backgroundUploader,
                         with: operation, and: uploadable)
            case .resumeable: break
            }
        case let .download(disposition, downloadable):
            switch disposition {
            case .foreground:
                dispatch(download: biceps, to: biceps.downloader,
                         with: operation, and: downloadable)
            case .background:
                dispatch(download: biceps, to: biceps.backgroundDownloader,
                         with: operation, and: downloadable)
            case .resumeable:
                dispatch(download: biceps, to: biceps.resumeDownloader,
                         with: operation, and: downloadable)
            }
        }
    }
}

extension Dispatcher {
    func dispatch(request biceps: Biceps, to requester: BicepsRequestable?,
                  with operation: Operation, and requestable: Requestable) {
        switch operation {
        case .start:
            let responser = BicepsHTTP.BicepsHTTPResponser(progress: biceps.internalProgressBlock,
                                                           success: biceps.internalSuccessBlock,
                                                           fail: biceps.internalFailBlock)
            
            let _requester = requester as? Requester
            _requester?.parameters = biceps.internalParamaters
            _requester?.configuration = biceps.internalConfiguration
            let connector = BicepsConnector()
            connector.connect(requester: _requester!, with: responser)
        case .resume, .suspend, .cancel: break
        }
    }
}

extension Dispatcher {
    func dispatch(download biceps: Biceps, to downloader: BicepsDownloadable?,
                  with operation: Operation, and downloadable: Downloadable) {
        switch operation {
        case .start:
            switch downloadable {
            case let .file(filePath):
                biceps.internalDataTask = downloader?.download(URL: biceps.internalURL,
                                                               paramater: biceps.internalParamaters,
                                                               configuration: biceps.internalConfiguration,
                                                               destination: Foundation.URL(fileURLWithPath: filePath),
                                                               progress: biceps.internalProgressBlock,
                                                               success: biceps.internalSuccessBlock,
                                                               fail: biceps.internalFailBlock)
            }
        case .resume:
            downloader?.resume(biceps.internalDataTask!)
        case .suspend:
            downloader?.suspend(biceps.internalDataTask!)
        case .cancel:
            downloader?.cancel(biceps.internalDataTask!)
        }
    }
}

extension Dispatcher {
    func dispatch(upload biceps: Biceps, to uploader: BicepsUploadable?,
                  with operation: Operation, and uploadble: Uploadable) {
        switch operation {
        case .start:
            switch uploadble {
            case let .file(filePath):
                biceps.internalDataTask = uploader?.upload(URL: Foundation.URL(string: biceps.internalURL)!,
                                                           filePath: filePath, headers: biceps.internalConfiguration.headers,
                                                           progress: biceps.internalProgressBlock,
                                                           success: biceps.internalSuccessBlock,
                                                           fail: biceps.internalFailBlock)
            case let .multipart(multipartFormDataBlock):
                biceps.internalDataTask = uploader?.upload(URL: Foundation.URL(string: biceps.internalURL)!,
                                                           mutipartFormData: multipartFormDataBlock,
                                                           headers: biceps.internalConfiguration.headers,
                                                           progress: biceps.internalProgressBlock,
                                                           success: biceps.internalSuccessBlock,
                                                           fail: biceps.internalFailBlock)
            }
        case .resume:
            uploader?.resume(biceps.internalDataTask!)
        case .suspend:
            uploader?.suspend(biceps.internalDataTask!)
        case .cancel:
            uploader?.cancel(biceps.internalDataTask!)
        }
    }
}

enum ResponseDispatcher {
    enum Responsable {
        case response(URLRequest?, URLResponse?, Data?, Error?)
    }
    enum Operations {
        case operations(ProgressBlock?, SuccessBlock, FailBlock)

    }
    case responseDispatcher
    func dispatch<T: DataResponseSerializerProtocol>(to seriliazer: T,
                                                     with responsable: Responsable,
                                                     and operations: Operations) {
        switch responsable {
        case let .response(request, response, data, error):
            let result = seriliazer.serializeResponse(request, (response as! HTTPURLResponse), data, error)
            switch operations {
            case let .operations(_, successBlock, failBlock):
                if result.isSuccess {
                    successBlock(result.value as Any)
                } else if result.isFailure {
                    failBlock(result.error!)
                }
            }
        }
    }
}
