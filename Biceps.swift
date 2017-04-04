
//  Biceps.swift
//  Biceps
//
//  Created by SDH on 13/03/2017.
//  Copyright © 2017 sdaheng. All rights reserved.
//

import Foundation
import Alamofire

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
    open class func combine(_ requests: [Biceps]) -> Biceps {
        let biceps = Biceps.GET
        
        biceps.combinedRequest = requests
        
        return biceps
    }
    
    open func delay(_ timeInterval: TimeInterval) -> Biceps {
        guard timeInterval >= 0 else {
            self.delayTimeInterval = 0
            return self
        }
        self.delayTimeInterval = timeInterval
        return self
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
        request(for: self.internalType, contentType: JSONMIMEType)
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
        return lhs.identifier == rhs.identifier && lhs.internalURL == rhs.internalURL
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

extension Biceps: CustomStringConvertible {
    public var description: String {
        return self.internalName
    }
}

class BicepsOperation: Operation {
    
    var biceps: Biceps
    
    var _finished: Bool = false {
        willSet {
            self.willChangeValue(forKey: "isFinished")
        }
        
        didSet {
            self.didChangeValue(forKey: "isFinished")
        }
    }
    var _executing: Bool = false {
        willSet {
            self.willChangeValue(forKey: "isExecuting")
        }
        
        didSet {
            self.didChangeValue(forKey: "isExecuting")
        }
    }
    
    init(_ biceps: Biceps) {
        self.biceps = biceps
    }

    override func start() {

        guard self.isReady else {
            return
        }
        
        let progress = biceps.internalProgressBlock
        let success = biceps.internalSuccessBlock
        let fail = biceps.internalFailBlock

        biceps.progress({ (_progress) in
            self._finished = false
            self._executing = true
            
            progress(_progress)
        }).success { (result) in
            self._finished = true
            self._executing = false
            
            success(result)
        }.fail({ (error) in
            self._finished = true
            self._executing = false
            
            fail(error)
        }).requestJSON()
    }
    
    override var isExecuting: Bool {
        return _executing
    }
    
    override var isFinished: Bool {
        return _finished
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

internal protocol BicepsLoggable {
    func log(level: BicepsLogLevel, request: URLRequest)
    func log(level: BicepsLogLevel, task: URLSessionTask, data: Data)
    func log(level: BicepsLogLevel, task: URLSessionTask, error: Error)
    func log(level: BicepsLogLevel, task: URLSessionTask, metrics: URLSessionTaskMetrics)
}
