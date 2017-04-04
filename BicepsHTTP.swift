//
//  BicepsHTTP.swift
//  HomeNAS
//
//  Created by SDH on 03/04/2017.
//  Copyright © 2017 sdaheng. All rights reserved.
//

import Foundation
import Alamofire

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
    struct Requester: BicepsRequestable {
        func request(URL: URL, paramaters: [String : Any]?,
                     configuration: BicepsConfigurable, method: BicepsType,
                     progress: @escaping ProgressBlock,
                     success: @escaping (Dictionary<String, Any>) -> Void,
                     fail: @escaping (Error) -> Void) -> URLSessionTask? {
            
            var _headers: [String:String]? = configuration.headers
            if let generalHeader = shared.generalConfiguartion.headers {
                for (key, value) in generalHeader {
                    _ = _headers?.updateValue(value, forKey: key)
                }
            }
            
            return shared.session.request(URL, method: shared.convertMethod(method),
                                          parameters: paramaters,
                                          encoding: URLEncoding.default,
                                          headers: _headers).responseJSON { (response) in
                                            shared.handleResponse(result: response.result,
                                                                  success: success, fail: fail)
                }.task
        }
    }
}

extension BicepsHTTP {
    
    struct Uploader: BicepsUploadable {
        
        func upload(URL: URL, filePath: String, headers: [String:String]?,
                    progress: @escaping ProgressBlock,
                    success: @escaping (Dictionary<String, Any>) -> Void,
                    fail: @escaping (Error) -> Void) -> URLSessionTask? {
            
            let fileURL = Foundation.URL(fileURLWithPath: filePath)
            
            let task = shared.session.upload(fileURL, to: URL, headers: headers).uploadProgress { (_progress) in
                progress(_progress)
                }.responseJSON { response in
                    shared.handleResponse(result: response.result,
                                          success: success, fail: fail)
                }.task
            
            return task
        }
        
        func upload(URL: URL, mutipartFormData: @escaping (MultipartFormData) -> Void,
                    headers: [String:String]?,
                    progress: @escaping ProgressBlock,
                    success: @escaping (Dictionary<String, Any>) -> Void,
                    fail: @escaping (Error) -> Void) -> URLSessionTask? {
            
            var task: URLSessionTask? = nil
            shared.session.upload(multipartFormData: { (m) in
                mutipartFormData(m)
            }, to: URL, headers: headers) { (encodingResult) in
                switch encodingResult {
                case .success(request: let upload, streamingFromDisk: _, streamFileURL: _):
                    task = upload.responseJSON(completionHandler: { (response) in
                        shared.handleResponse(result: response.result,
                                              success: success, fail: fail)
                    }).task
                case .failure(let encodingError):
                    print(encodingError)
                }
            }
            
            return task
        }
        
        func cancel(_ task: URLSessionTask) {
            task.cancel()
        }
        
        func resume(_ task: URLSessionTask) {
            task.resume()
        }
        
        func suspend(_ task: URLSessionTask) {
            task.suspend()
        }
    }
}

extension BicepsHTTP {
    struct BackgroundUploader: BicepsBackgroundUploadable {
        
        func upload(URL: URL, filePath: String, headers: [String:String]?,
                    progress: @escaping ProgressBlock,
                    success: @escaping SuccessBlock,
                    fail: @escaping FailBlock) -> URLSessionTask? {
            let fileURL = Foundation.URL(fileURLWithPath: filePath)
            
            let uploadTask = shared.backgroundSession.upload(fileURL, to: URL, headers: headers).uploadProgress { (_progress) in
                progress(_progress)
                }.responseJSON { response in
                    shared.handleResponse(result: response.result,
                                          success: success, fail: fail)
                }.task
            
            return uploadTask
        }
        
        func upload(URL: URL, mutipartFormData: @escaping (MultipartFormData) -> Void,
                    headers: [String:String]?,
                    progress: @escaping ProgressBlock,
                    success: @escaping SuccessBlock,
                    fail: @escaping FailBlock) -> URLSessionTask? {
            
            var uploadTask: URLSessionTask? = nil
            shared.backgroundSession.upload(multipartFormData: { (m) in
                mutipartFormData(m)
            }, to: URL, headers: headers) { (encodingResult) in
                switch encodingResult {
                case .success(request: let upload, streamingFromDisk: _, streamFileURL: _):
                    uploadTask = upload.uploadProgress { (_progress) in
                        progress(_progress)
                        }.responseJSON(completionHandler: { (response) in
                            shared.handleResponse(result: response.result,
                                                  success: success, fail: fail)
                        }).task
                case .failure(let encodingError):
                    print(encodingError)
                }
            }
            
            return uploadTask
        }
        
        func cancel(_ task: URLSessionTask) {
            task.cancel()
        }
        
        func resume(_ task: URLSessionTask) {
            task.resume()
        }
        
        func suspend(_ task: URLSessionTask) {
            task.suspend()
        }
    }
}

extension BicepsHTTP {
    struct Downloader: BicepsDownloadable {
        
        func download(URL: URLConvertible, paramater: [String:Any]?,
                      configuration: BicepsConfigurable, destination: URL,
                      progress: @escaping ProgressBlock,
                      success: @escaping SuccessBlock,
                      fail: @escaping FailBlock) -> URLSessionTask? {
            
            return shared.session.download(URL, method: .get, parameters: paramater, headers: configuration.headers) { (URL, response) -> (destinationURL: URL, options: DownloadRequest.DownloadOptions) in
                return (destination, .createIntermediateDirectories)
                }.downloadProgress { (_progress) in
                    progress(_progress)
                }.responseJSON { (response) in
                    shared.handleResponse(result: response.result, success: success, fail: fail)
                }.task
        }
        
        func cancel(_ task: URLSessionTask) {
            task.cancel()
        }
        
        func resume(_ task: URLSessionTask) {
            task.resume()
        }
        
        func suspend(_ task: URLSessionTask) {
            task.suspend()
        }
    }
}

extension BicepsHTTP {
    struct BackgroundDownloader: BicepsBackgroundDownloadable {
        
        func download(URL: URLConvertible, paramater: [String : Any]?,
                      configuration: BicepsConfigurable, destination: URL,
                      progress: @escaping ProgressBlock,
                      success: @escaping SuccessBlock,
                      fail: @escaping FailBlock) -> URLSessionTask? {
            return shared.backgroundSession.download(URL, method: .get, parameters: paramater, headers: configuration.headers) { (URL, response) -> (destinationURL: URL, options: DownloadRequest.DownloadOptions) in
                return (destination, .createIntermediateDirectories)
                }.downloadProgress { (_progress) in
                    progress(_progress)
                }.responseJSON { (response) in
                    shared.handleResponse(result: response.result, success: success, fail: fail)
                }.task
        }
        
        func cancel(_ task: URLSessionTask) {
            task.cancel()
        }
        
        func resume(_ task: URLSessionTask) {
            task.resume()
        }
        
        func suspend(_ task: URLSessionTask) {
            task.suspend()
        }
    }
}

extension BicepsHTTP {
    struct ResumeDownloader: BicepsResumeDownloadable {
        
        func resumeDataFilePath(_ URL: URL) -> String {
            let fileName = URL.lastPathComponent + ".biceps.r"
            
            #if os(iOS)
                let directoryPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first!
            #elseif os(macOS)
                let directoryPath = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first! + "/" + Bundle.main.bundleIdentifier!
            #endif
            
            return  directoryPath + "/" + fileName
        }
        
        func resumeData(for URL: URL) throws -> Data {
            let resumeDataFilePath = self.resumeDataFilePath(try URL.asURL())
            
            return try Data(contentsOf: Foundation.URL(fileURLWithPath: resumeDataFilePath))
        }
        
        func download(URL: URLConvertible, paramater: [String : Any]?,
                      configuration: BicepsConfigurable, destination: URL,
                      progress: @escaping ProgressBlock,
                      success: @escaping SuccessBlock,
                      fail: @escaping FailBlock) -> URLSessionTask? {
            
            do {
                let resumeData = try self.resumeData(for: URL.asURL())
                
                return shared.backgroundSession.download(resumingWith: resumeData).downloadProgress { (_progress) in
                    progress(_progress)
                    }.responseJSON { (response) in
                        shared.handleResponse(result: response.result, success: success, fail: fail)
                    }.task
                
            } catch {
                return shared.backgroundSession.download(URL, method: .get, parameters: paramater, headers: configuration.headers) { (URL, response) -> (destinationURL: URL, options: DownloadRequest.DownloadOptions) in
                    return (destination, .createIntermediateDirectories)
                    }.downloadProgress { (_progress) in
                        progress(_progress)
                    }.responseJSON { (response) in
                        shared.handleResponse(result: response.result,
                                              success: success,
                                              fail: fail)
                    }.task
            }
        }
        
        func cancel(_ task: URLSessionTask) {
            suspend(task)
        }
        
        func resume(_ task: URLSessionTask) {
            task.resume()
        }
        
        func suspend(_ task: URLSessionTask) {
            let downloadTask = task as! URLSessionDownloadTask
            downloadTask.cancel { (resumeData) in
                do {
                    if let URL = downloadTask.currentRequest?.url {
                        try resumeData?.write(to: Foundation.URL(fileURLWithPath: self.resumeDataFilePath(URL)))
                    }
                } catch {}
            }
        }
    }
}

extension BicepsHTTP {
    func handleResponse(result: Result<Any>, success: SuccessBlock, fail: FailBlock) {
        if result.isSuccess {
            if let ret = result.value {
                success(ret as! Dictionary<String, Any>)
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