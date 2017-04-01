
//  Biceps.swift
//  Biceps
//
//  Created by SDH on 13/03/2017.
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

// MARK: Biceps Configuration
protocol BicepsConfigurable {
    var headers: [String:String]? { get set }
    
    var logLevel: BicepsLogLevel { get set }
    
    var sessionDidReceiveChallengeWithCompletion: ((URLSession, URLAuthenticationChallenge, (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)? { get set }
    var backgroundCompletionHander: BackgroundCompletionHandler? { get set }
}

extension BicepsConfigurable {
    var logLevel: BicepsLogLevel {
        return .Off
    }
}

open class BicepsGeneralConfiguration: BicepsConfigurable {
    open var backgroundCompletionHander: BackgroundCompletionHandler?

    open var sessionDidReceiveChallengeWithCompletion: ((URLSession, URLAuthenticationChallenge, (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)?


    open static let shared = BicepsGeneralConfiguration()
    
    open var logLevel: BicepsLogLevel = .Off
    open var headers: [String : String]?
    
    private var allowCache: Bool = true
    
    open var interceptor: BicepsInterceptable?
    
    init() {}
}

open class BicepsConfiguration: BicepsConfigurable {
    internal var backgroundCompletionHander: BackgroundCompletionHandler?

    internal var sessionDidReceiveChallengeWithCompletion: ((URLSession, URLAuthenticationChallenge, (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)?

    open var logLevel: BicepsLogLevel = .Off

    open var headers: [String : String]?
}

// MARK: Biceps Errors
public enum BicepsError: Error {
    public enum BicepsUnimplementedMethodError: Error {
        case fetch
        case send
    }
}

extension BicepsError.BicepsUnimplementedMethodError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .fetch: return "BicepsUnimplementMethodError: not implement fetch method"
        case .send : return "BicepsUnimplementMethodError: not implement send method"
        }
    }
}

// MARK: Service Layer
public protocol BicepsServiceable {
    func fetch(paramater: [String:Any]?, resultBlock: @escaping (_ result: Any?)->Void) throws -> Biceps
    func send(paramater: [String:Any]?, resultBlock: @escaping (_ result: Any?)->Void)  throws -> Biceps
}

public extension BicepsServiceable {
    func fetch(paramater: [String:Any]?, resultBlock: @escaping (_ result: Any?)->Void) throws -> Biceps {
        throw BicepsError.BicepsUnimplementedMethodError.fetch
    }
    
    func send(paramater: [String:Any]?, resultBlock: @escaping (_ result: Any?)->Void) throws -> Biceps {
        throw BicepsError.BicepsUnimplementedMethodError.send
    }
}

open class BicepsService {
    open class func fetch<T: BicepsServiceable>(by provider: T, paramater: [String:Any]?, resultBlock: @escaping (_ result: Any?) -> Void) throws {
        do {
            let biceps = try provider.fetch(paramater: paramater, resultBlock: resultBlock)
            
            biceps.requestJSON()
        } catch {
            throw BicepsError.BicepsUnimplementedMethodError.fetch
        }
    }
    
    open class func send<T: BicepsServiceable>(by provider: T, paramater: [String:Any]?, resultBlock: @escaping (_ result: Any?) -> Void) throws {
        do {
            let biceps = try provider.send(paramater: paramater, resultBlock: resultBlock)
            
            biceps.requestJSON()
        } catch {
            throw BicepsError.BicepsUnimplementedMethodError.send
        }
    }
}

// MARK: Specific protocol independent layer
open class Biceps {

    internal var internalType: BicepsType
    internal lazy var internalName: String = defaultRequestName
    internal lazy var internalParamaters: [String : Any]? = nil
    internal lazy var internalURL: String! = ""
    
    internal lazy var internalProgressBlock: ProgressBlock = {_ in }
    internal lazy var internalSuccessBlock:  SuccessBlock = {_ in }
    internal lazy var internalFailBlock: FailBlock = {_ in }
    
    internal lazy var internalDataTask: URLSessionTask? = nil
    
    internal lazy var delayTimeInterval: TimeInterval = 0

    internal var combinedRequest: [Biceps]?
    internal var dependency: Biceps?
    internal lazy var configuration: BicepsConfiguration = BicepsConfiguration()

    internal lazy var dispatcher: Dispatcher = .request(.foreground)
    
    lazy var identifier: Int = {
        if let dataTask = self.internalDataTask {
            return dataTask.taskIdentifier
        }
        return 0
    }()
    
    open lazy var name: String = {
        if self.internalName == defaultRequestName {
            return defaultRequestName + " with identifier: \(self.identifier)"
        }
        return self.internalName
    }()
    
    open var result: [String:Any]?
    
    init(_ type: BicepsType) {
        self.internalType = type
    }
}

extension Biceps {
    open func paramaters(_ paramaters: [String : Any]?) -> Biceps {
        self.internalParamaters = paramaters
        return self
    }
    
    open func URL(_ URL: String) -> Biceps {
        self.internalURL = URL
        return self
    }
    
    open func headers(_ headers: [String : String]) -> Biceps {
        self.configuration.headers = headers
        return self
    }
}

extension Biceps {
    open func progress(_ progress: @escaping ProgressBlock) -> Biceps {
        self.internalProgressBlock = progress
        return self
    }
    
    open func success(_ success: @escaping SuccessBlock) -> Biceps {
        self.internalSuccessBlock = success
        return self
    }
    
    open func fail(_ fail: @escaping FailBlock) -> Biceps {
        self.internalFailBlock = fail
        return self
    }
}

extension Biceps {
    open func delay(_ timeInterval: TimeInterval) -> Biceps {
        guard timeInterval >= 0 else {
            self.delayTimeInterval = 0
            return self
        }
        self.delayTimeInterval = timeInterval
        return self
    }
    
    open class func combine(_ requests: [Biceps]) -> Biceps {
        let biceps = Biceps.GET
        
        biceps.combinedRequest = requests
        
        return biceps
    }
    
    open func configuration(_ block: (BicepsConfiguration) -> Void) -> Biceps {
        block(self.configuration)
        return self
    }
    
    private func log(_ level: BicepsLogLevel) -> Biceps {
        self.configuration.logLevel = level
        return self
    }
    
    open func name(_ name: String) -> Biceps {
        self.internalName = name
        return self
    }
}

extension Biceps {
    open var with: Biceps {
        return self
    }
}

extension Biceps {
    open static var GET: Biceps {
        return Biceps(.GET)
    }
    
    open static var POST: Biceps {
        return Biceps(.POST)
    }
    
    open static var HEAD: Biceps {
        return Biceps(.HEAD)
    }
    
    open static var DELETE: Biceps {
        return Biceps(.DELETE)
    }
    
    open static var OPTIONS: Biceps {
        return Biceps(.OPTIONS)
    }
    
    open static var PUT: Biceps {
        return Biceps(.PUT)
    }
    
    open static var PATCH: Biceps {
        return Biceps(.PATCH)
    }
    
    open static var TRACE: Biceps {
        return Biceps(.TRACE)
    }
    
    open static var CONNECT: Biceps {
        return Biceps(.CONNECT)
    }
}

extension Biceps {
    internal enum Dispatcher {
        
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
        
        case request(Disposition)
        case upload(Disposition, Uploadable)
        case download(Disposition, Downloadable)
        
        func dispatch(_ biceps: Biceps, with operation: Operation) {
            switch self {
            case let .request(disposition):
                switch disposition {
                case .foreground:
                    dispatch(biceps, to: biceps.requester, with: operation)
                default:
                    break
                }
            case let .upload(disposition, uploadable):
                switch disposition {
                case .foreground:
                    dispatch(biceps, to: biceps.uploader, with: operation, and: uploadable)
                case .background:
                    dispatch(biceps, to: biceps.backgroundUploader, with: operation, and: uploadable)
                case .resumeable: break
                }
            case let .download(disposition, downloadable):
                switch disposition {
                case .foreground:
                    dispatch(biceps, to: biceps.downloader, with: operation, and: downloadable)
                case .background:
                    dispatch(biceps, to: biceps.backgroundDownloader, with: operation, and: downloadable)
                case .resumeable:
                    dispatch(biceps, to: biceps.resumeDownloader, with: operation, and: downloadable)
                }
            }
        }
        
        func dispatch(_ biceps: Biceps, to requester: BicepsRequestable, with operation: Operation) {
            switch operation {
            case .start:
                biceps.internalDataTask = requester.request(URL: Foundation.URL(string: biceps.internalURL)!,
                                                            paramaters: biceps.internalParamaters,
                                                            configuration: biceps.configuration,
                                                            method: biceps.internalType,
                                                            progress: biceps.internalProgressBlock,
                                                            success: biceps.internalSuccessBlock,
                                                            fail: biceps.internalFailBlock)
            case .resume: fallthrough
            case .suspend: fallthrough
            case .cancel: break
            }
        }
        
        func dispatch(_ biceps: Biceps, to downloader: BicepsDownloadable?,
                      with operation: Operation, and downloadable: Downloadable) {
            switch operation {
            case .start:
                switch downloadable {
                case let .file(filePath):
                biceps.internalDataTask = downloader?.download(URL: biceps.internalURL,
                                                              paramater: biceps.internalParamaters,
                                                              configuration: biceps.configuration,
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
        
        func dispatch(_ biceps: Biceps, to uploader: BicepsUploadable?,
                      with operation: Operation, and uploadble: Uploadable) {
            switch operation {
            case .start:
                switch uploadble {
                case let .file(filePath):
                    biceps.internalDataTask = uploader?.upload(URL: Foundation.URL(string: biceps.internalURL)!,
                                                               filePath: filePath, headers: biceps.configuration.headers,
                                                               progress: biceps.internalProgressBlock,
                                                               success: biceps.internalSuccessBlock,
                                                               fail: biceps.internalFailBlock)
                case let .multipart(multipartFormDataBlock):
                    biceps.internalDataTask = uploader?.upload(URL: Foundation.URL(string: biceps.internalURL)!,
                                                               mutipartFormData: multipartFormDataBlock,
                                                               headers: biceps.configuration.headers,
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
}

protocol BicepsOperatable {
    func cancel(_ task: URLSessionTask)
    func resume(_ task: URLSessionTask)
    func suspend(_ task: URLSessionTask)
}

protocol BicepsRequestable {
    func request(URL: URL, paramaters: [String:Any]?, configuration: BicepsConfigurable,
                 method: BicepsType,
                 progress: @escaping ProgressBlock,
                 success: @escaping SuccessBlock,
                 fail: @escaping FailBlock) -> URLSessionTask?
}

extension Biceps {
    open func requestJSON() {
        if let combinedRequest = self.combinedRequest, combinedRequest.count > 0 {
            for biceps in combinedRequest {
                biceps.requestJSON()
            }
        } else {
            request(for: self.internalType, contentType: "")
        }
    }
    
    var requester: BicepsRequestable {
        switch self.internalType {
        case .GET, .POST, .DELETE, .HEAD, .PUT, .PATCH, .OPTIONS, .TRACE, .CONNECT:
            return BicepsHTTP.Requester()
        }
    }
    
    private func request(for bicepsType: BicepsType, contentType: String) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + self.delayTimeInterval) {
            self.dispatcher = .request(.foreground)
            self.dispatcher.dispatch(self, with: .start)
        }
    }
}

protocol BicepsUploadable: BicepsOperatable {
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

protocol BicepsBackgroundUploadable: BicepsUploadable {
}

extension Biceps {
    var uploader: BicepsUploadable? {
        switch self.internalType {
        case .POST, .PUT, .PATCH:
            return BicepsHTTP.Uploader()
        default: return nil
        }
    }
    
    open func upload(from filePath: String) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + self.delayTimeInterval) {
            self.dispatcher = .upload(.foreground, .file(filePath))
            self.dispatcher.dispatch(self, with: .start)
        }
    }
    
    open func upload(from multipartFormData: @escaping(MultipartFormData) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + self.delayTimeInterval) {
            self.dispatcher = .upload(.background, .multipart(multipartFormData))
            self.dispatcher.dispatch(self, with: .start)
        }
    }
}

public extension Biceps {
    
    internal var backgroundUploader: BicepsBackgroundUploadable? {
        switch self.internalType {
        case .POST, .PUT, .PATCH:
            return BicepsHTTP.BackgroundUploader()
        default: return nil
        }
    }
    
    public func backgroundUpload(_ filePath: String) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + self.delayTimeInterval) {
            self.dispatcher = .upload(.background, .file(filePath))
            self.dispatcher.dispatch(self, with: .start)
        }
    }
    
    public func backgroundUpload(_ multipartFormData: @escaping(MultipartFormData) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + self.delayTimeInterval) {
            self.dispatcher = .upload(.foreground, .multipart(multipartFormData))
            self.dispatcher.dispatch(self, with: .start)
        }
    }
}

protocol BicepsDownloadable: BicepsOperatable {
    func download(URL: URLConvertible, paramater: [String:Any]?,
                  configuration: BicepsConfigurable, destination: URL,
                  progress: @escaping ProgressBlock,
                  success: @escaping SuccessBlock,
                  fail: @escaping FailBlock) -> URLSessionTask?
}

protocol BicepsBackgroundDownloadable: BicepsDownloadable {
}

protocol BicepsResumeDownloadable: BicepsDownloadable {
}

public extension Biceps {
    
    internal var downloader: BicepsDownloadable? {
        switch self.internalType {
        case .GET: return BicepsHTTP.Downloader()
        default: return nil
        }
    }
    
    func download(to path: String) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + self.delayTimeInterval) {
            self.dispatcher = .download(.foreground, .file(path))
            self.dispatcher.dispatch(self, with: .start)
        }
    }
}

public extension Biceps {
    internal var backgroundDownloader: BicepsBackgroundDownloadable? {
        switch self.internalType {
        case .GET: return BicepsHTTP.BackgroundDownloader()
        default: return nil
        }
    }
    
    func backgroundDownload(to path: String) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + self.delayTimeInterval) {
            self.dispatcher = .download(.background, .file(path))
            self.dispatcher.dispatch(self, with: .start)
        }
    }
}

public extension Biceps {
    internal var resumeDownloader: BicepsResumeDownloadable? {
        switch self.internalType {
        case .GET: return BicepsHTTP.ResumeDownloader()
        default: return nil
        }
    }
    
    public func resumeDownload(to path: String) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + self.delayTimeInterval) {
            self.dispatcher = .download(.resumeable, .file(path))
            self.dispatcher.dispatch(self, with: .start)
        }
    }
}

public extension Biceps {
    
    func resume() {
        self.dispatcher.dispatch(self, with: .resume)
    }
    
    func suspend() {
        self.dispatcher.dispatch(self, with: .suspend)
    }
    
    func cancel() {
        self.dispatcher.dispatch(self, with: .cancel)
    }
}

extension Biceps: Hashable, Equatable {
    public var hashValue: Int {
        return self.identifier.hashValue
    }
    
    public static func ==(lhs: Biceps, rhs: Biceps) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

precedencegroup DependencyPrecedence {
    associativity: left
}

infix operator ~>: DependencyPrecedence

extension Biceps {
    open static func ~> (lhs: Biceps, rhs: Biceps) -> Biceps {
        return lhs.dependency(rhs)
    }
    
    open func dependency(_ d: Biceps) -> Biceps {
        self.dependency = d
        return self
    }
    
    open func hasDependency() -> Bool {
        return dependency != nil
    }
}

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

// MARK: Biceps Interceptor
public protocol BicepsInterceptable {
    var customURLProtocols: Array<AnyClass>? { get }
    
    var useDefaultInterceptor: Bool { get }
}

public extension BicepsInterceptable {
    var useDefaultInterceptor: Bool {
        return true
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

internal protocol BicepsLoggable {
    func log(level: BicepsLogLevel, request: URLRequest)
    func log(level: BicepsLogLevel, task: URLSessionTask, data: Data)
    func log(level: BicepsLogLevel, task: URLSessionTask, error: Error)
    func log(level: BicepsLogLevel, task: URLSessionTask, metrics: URLSessionTaskMetrics)
}

// MARK: Custom URLProtocol for default interceptor
let BicepsLogRequestKey = "BicepsLogRequestKey"

internal class BicepsLogProtocol: URLProtocol {
    private lazy var activeTask: URLSessionTask? = nil
    
    private lazy var session: URLSession = {
        
        let queue = OperationQueue()
        
        let configuration = URLSessionConfiguration.ephemeral
        
        if let interceptor = self.interceptor {
            configuration.protocolClasses = interceptor.customURLProtocols
        }
        
        let session = URLSession(configuration: configuration,
                                 delegate: self, delegateQueue: queue)
        
        return session
    }()
    
    override class func canInit(with request: URLRequest) -> Bool {
        if URLProtocol.property(forKey: BicepsLogRequestKey, in: request) != nil {
            return false
        }
        return true
    }
    
    override class func canInit(with task: URLSessionTask) -> Bool {
        if (URLProtocol.property(forKey: BicepsLogRequestKey, in: task.originalRequest!) != nil) {
            return false
        }
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        let request: NSURLRequest = self.request as NSURLRequest
        URLProtocol.setProperty(true, forKey: BicepsLogRequestKey,
                                in: request.mutableCopy() as! NSMutableURLRequest)

        log(level: BicepsGeneralConfiguration.shared.logLevel, request: self.request)

        activeTask = session.dataTask(with: request as URLRequest)
        activeTask?.resume()
    }
    
    override func stopLoading() {
        activeTask?.cancel()
    }
}

extension BicepsLogProtocol {
    internal var interceptor: BicepsInterceptable? {
        return BicepsGeneralConfiguration.shared.interceptor
    }
}

let JSONAvaliableContentTypes = [ "application/json" ]

extension BicepsLogProtocol: BicepsLoggable {
    internal func log(level: BicepsLogLevel, task: URLSessionTask, metrics: URLSessionTaskMetrics) {
        guard level == .All || level == .Debug else {
            return
        }
        
        print("[\(level)] metrics: \(metrics)")
    }

    internal func log(level: BicepsLogLevel, request: URLRequest) {
        guard level != .Off && level != .Error else {
            return
        }
        
        var logMessage = "[\(level)] Request "
        
        logMessage += "URL: \(request.url)\n"
        logMessage += "method: \(request.httpMethod)\n"
        logMessage += "headers: \(request.allHTTPHeaderFields)\n"
        
        print(logMessage)
    }
    
    func log(level: BicepsLogLevel, task: URLSessionTask, data: Data) {
        guard level != .Off && level != .Error else {
            return
        }
        
        var logMessage = "[\(level)] Response "
        
        logMessage += "URL: \(task.response?.url)\n"
        
        let httpResponse = task.response as! HTTPURLResponse
        
        if level == .All || level == .Debug {
            logMessage += "MIME-type: \(task.response?.mimeType)\n"
            logMessage += "Status code: \(httpResponse.statusCode)\n"
            logMessage += "Headers: \(httpResponse.allHeaderFields))\n"
        }
        
        if let MIMEType = task.response?.mimeType, JSONAvaliableContentTypes.contains(MIMEType) {
            do {
                let result = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                
                logMessage += "\(result)\n"
            } catch {
                
            }
        } else {
            logMessage += String(bytes: data, encoding: .utf8) ?? ""
        }
        
        print(logMessage)
    }
    
    func log(level: BicepsLogLevel, task: URLSessionTask, error: Error) {
        guard level != .Off && level != .Info else {
            return
        }
        
        var logMessage = "[\(level)]"

        if let httpResponse = task.response as? HTTPURLResponse {
            logMessage += "URL: \(task.originalRequest?.url)"
            logMessage += "Status code: \(httpResponse.statusCode)\n"
        }
        
        logMessage += "Error: \(error)\n"
        print(logMessage)
    }
}

extension BicepsLogProtocol: URLSessionDataDelegate, URLSessionDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Swift.Void) {
        
        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
        
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        log(level: BicepsGeneralConfiguration.shared.logLevel, task: dataTask, data: data)
        self.client?.urlProtocol(self, didLoad: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        log(level: BicepsGeneralConfiguration.shared.logLevel, task: task, metrics: metrics)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?){
        if let err = error {
            self.client?.urlProtocol(self, didFailWithError: err)
            log(level: BicepsGeneralConfiguration.shared.logLevel, task: task, error: err)
        } else {
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }
}
