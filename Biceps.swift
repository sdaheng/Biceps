
//  Biceps.swift
//  Biceps
//
//  Created by SDH on 13/03/2017.
//  Copyright © 2017 sdaheng. All rights reserved.
//

import Foundation
import Alamofire

#if canImport(SwiftProtobuf)
import SwiftProtobuf
#endif

// MARK: Specific protocol independent layer
open class Biceps {

    internal var internalType: BicepsType
    internal lazy var internalName: String = defaultRequestName
    
    internal lazy var internalMessage: Message? = nil
    internal lazy var internalMessageData: Data? = nil
    
    internal lazy var internalParamaters: ParameterConvertible? = nil
    internal lazy var internalParameterEncodingType: ParamaterEncodingType = .URL
    
    internal lazy var internalURL: String! = ""
    
    internal lazy var internalProgressBlock: ProgressBlock = {_ in }
    internal lazy var internalSuccessBlock:  SuccessBlock = {_ in }
    internal lazy var internalFailBlock: FailBlock = {_ in }
    
    internal lazy var internalDataTask: URLSessionTask? = nil
    
    internal lazy var delayTimeInterval: TimeInterval = 0

    internal var combinedRequest: [Biceps]?

    internal var dependency: Biceps?
    
    internal lazy var internalConfiguration: BicepsConfiguration = BicepsConfiguration()

    internal lazy var dispatcher: Dispatcher = .request(.foreground, .type(.URL, nil))
    
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
    open func paramaters(_ paramaters: ParameterConvertible?) -> Biceps {
        self.internalParamaters = paramaters
        return self
    }
    
    open func parameterEncodingType(_ parameterEncodingType: ParamaterEncodingType) -> Biceps {
        self.internalParameterEncodingType = parameterEncodingType
        return self
    }
    
    open func URL(_ URL: String) -> Biceps {
        self.internalURL = URL
        return self
    }
    
    open func headers(_ headers: [String : String]) -> Biceps {
        self.internalConfiguration.headers = headers
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
        block(self.internalConfiguration)
        return self
    }
    
    private func log(_ level: BicepsLogLevel) -> Biceps {
        self.internalConfiguration.logLevel = level
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
    var requester: BicepsURLRequestable? {
        switch self.internalType {
        case .GET, .POST, .DELETE, .HEAD, .PUT, .PATCH, .OPTIONS, .TRACE, .CONNECT:
            do {
                return BicepsHTTP.shared.createURLRequester(with: try self.internalURL.asURL(),
                                                            and: self.internalType)
            } catch {
                return nil
            }
        }
    }
    
    var jsonRequester: BicepsJSONRequestable? {
        switch self.internalType {
        case .GET, .POST, .DELETE, .HEAD, .PUT, .PATCH, .OPTIONS, .TRACE, .CONNECT:
            do {
                return BicepsHTTP.shared.createJSONRequester(with: try self.internalURL.asURL(),
                                                             and: self.internalType)
            } catch {
                return nil
            }
        }
    }
    
    var protobufRequester: BicepsProtobufRequestable? {
        switch self.internalType {
        case .GET, .POST, .DELETE, .HEAD, .PUT, .PATCH, .OPTIONS, .TRACE, .CONNECT:
            do {
                return BicepsHTTP.shared.createProtobufRequester(with: try self.internalURL.asURL(),
                                                                 and: self.internalType)
            } catch {
                return nil
            }
        }
    }
    
    open func request() {
        self.dispatchRequest(for: self.internalType,
                             paramaterEncodingType: .URL,
                             paramaters: self.internalParamaters)
    }
    
    open func requestJSON() {
        self.dispatchRequest(for: self.internalType,
                             paramaterEncodingType: .JSON,
                             paramaters: self.internalParamaters)
    }
    
    internal func dispatchRequest(for bicepsType: BicepsType,
                                  paramaterEncodingType: ParamaterEncodingType,
                                  paramaters: ParameterConvertible?) {
        Scheduler().delay(self.delayTimeInterval) { 
            self.dispatcher = .request(.foreground, .type(paramaterEncodingType, paramaters))
            self.dispatcher.dispatch(self, with: .start)
        }
    }
}

public extension Biceps {
    #if canImport(SwiftProtobuf)
    func message<T: Message>(_ _message: T) -> Biceps {
        self.internalMessage = _message;
        do {
            self.internalMessageData = try _message.serializedData()
        } catch {
        }
        
        return self
    }
    
    func requestProtobuf() {
        self.dispatchRequest(for: self.internalType,
                             paramaterEncodingType: .protobuf,
                             paramaters: self.internalMessageData)
    }
    #endif
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
        Scheduler().delay(self.delayTimeInterval) { 
            self.dispatcher = .upload(.foreground, .file(filePath))
            self.dispatcher.dispatch(self, with: .start)
        }
    }
    
    open func upload(from multipartFormData: @escaping(MultipartFormData) -> Void) {
        Scheduler().delay(self.delayTimeInterval) {
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
        Scheduler().delay(self.delayTimeInterval) {
            self.dispatcher = .upload(.background, .file(filePath))
            self.dispatcher.dispatch(self, with: .start)
        }
    }
    
    public func backgroundUpload(_ multipartFormData: @escaping(MultipartFormData) -> Void) {
        Scheduler().delay(self.delayTimeInterval) {
            self.dispatcher = .upload(.foreground, .multipart(multipartFormData))
            self.dispatcher.dispatch(self, with: .start)
        }
    }
}


public extension Biceps {
    
    internal var downloader: BicepsDownloadable? {
        switch self.internalType {
        case .GET: return BicepsHTTP.Downloader()
        default: return nil
        }
    }
    
    func download(to path: String) {
        Scheduler().delay(self.delayTimeInterval) {
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
        Scheduler().delay(self.delayTimeInterval) {
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
        Scheduler().delay(self.delayTimeInterval) {
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

extension Dictionary: ParameterConvertible {
    public func asDictionary() throws -> [String : Any]? {
        return self as? [String : Any]
    }
    
    public func asMessage() throws -> SwiftProtobuf.Google_Protobuf_Any? {
        throw BicepsError.InvalidateParameterError.protobufMessage
    }
    
    public func asData() throws -> Data? {
        return nil
    }
}

extension SwiftProtobuf.Google_Protobuf_Any: ParameterConvertible {
    public func asDictionary() throws -> [String : Any]? {
        throw BicepsError.InvalidateParameterError.dictionary
    }
    
    #if canImport(SwiftProtobuf)
    public func asMessage() throws -> SwiftProtobuf.Google_Protobuf_Any? {
        return self
    }
    #endif
    
    public func asData() throws -> Data? {
        return nil
    }
}

extension Data: ParameterConvertible {
    public func asDictionary() throws -> [String : Any]? {
        return nil;
    }
    
    #if canImport(SwiftProtobuf)
    public func asMessage() throws -> Google_Protobuf_Any? {
        return nil;
    }
    #endif
    
    public func asData() throws -> Data? {
        return self
    }
}
