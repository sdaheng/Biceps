
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

// MARK: Biceps Configuration
protocol BicepsConfigurable {
    var headers: [String:String]? { get set }
    
    var logLevel: BicepsLogLevel { get set }
}

open class BicepsGeneralConfigure: BicepsConfigurable {
    open static let shared = BicepsGeneralConfigure()
    
    open var logLevel: BicepsLogLevel = .Off
    open var headers: [String : String]?
    
    private var allowCache: Bool = true
    
    open var monitor: BicepsMonitorable?
    
    open var sessionDidReceiveChallengeWithCompletion: ((URLSession, URLAuthenticationChallenge, (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)?
    
    init() {}
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
        case .fetch: return "BicepsUmimplementMethodError: not implement fetch method"
        case .send : return "BicepsUmimplementMethodError: not implement send method"
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
    open class func fetch<T: BicepsServiceable>(by impClass: T, paramater: [String:Any]?, resultBlock: @escaping (_ result: Any?) -> Void) throws {
        do {
            let biceps = try impClass.fetch(paramater: paramater, resultBlock: resultBlock)
            
            biceps.requestJSON()
        } catch {
            throw BicepsError.BicepsUnimplementedMethodError.fetch
        }
    }

    open class func send<T: BicepsServiceable>(by impClass: T, paramater: [String:Any]?, resultBlock: @escaping (_ result: Any?) -> Void) throws {
        do {
            let biceps = try impClass.send(paramater: paramater, resultBlock: resultBlock)
            
            biceps.requestJSON()
        } catch {
            throw BicepsError.BicepsUnimplementedMethodError.send
        }
    }
}

// MARK: Specific protocol independent layer
open class Biceps: BicepsConfigurable, BicepsMonitorable {
    public var customURLProtocols: Array<AnyClass>?

    private var internalType: BicepsType
    private lazy var internalName: String = defaultRequestName
    private lazy var internalParamaters: [String : Any]? = nil
    private lazy var internalURL: String! = ""
    
    private lazy var internalProgressBlock: ProgressBlock = {_ in }
    private lazy var internalSuccessBlock:  SuccessBlock = {_ in }
    private lazy var internalFailBlock: FailBlock = {_ in }
    
    private lazy var internalDataTask: URLSessionTask? = nil
    
    private lazy var delayTimeInterval: TimeInterval = 0
    
    internal var headers: [String : String]?
    internal var logLevel: BicepsLogLevel = .Off
    
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
    
    init(_ type: BicepsType) {
        self.internalType = type
    }
    
    open var with: Biceps {
        get {
            return self
        }
    }
    
    open func name(_ name: String) -> Biceps {
        self.internalName = name
        return self
    }
    
    open func paramaters(_ paramaters: [String : Any]?) -> Biceps {
        self.internalParamaters = paramaters
        return self
    }
    
    open func URL(_ URL: String) -> Biceps {
        self.internalURL = URL
        return self
    }
    
    open func headers(_ headers: [String : String]) -> Biceps {
        self.headers = headers
        return self
    }
    
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
    
    open func delay(_ timeInterval: TimeInterval) -> Biceps {
        guard timeInterval >= 0 else {
            return self
        }
        self.delayTimeInterval = timeInterval
        return self
    }
    
    private func log(_ level: BicepsLogLevel) -> Biceps {
        self.logLevel = level
        return self
    }

    open func requestJSON() {
        request(for: self.internalType, contentType: "")
    }

    lazy var requester: BicepsRequestable? = {
        switch self.internalType {
        case .GET, .POST, .DELETE, .HEAD, .PUT, .PATCH, .OPTIONS, .TRACE, .CONNECT:
            return BicepsHTTP.shared
        }
    }()
    
    private func request(for bicepsType: BicepsType, contentType: String) {
        do {
            let requestURL = try internalURL.asURL()
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + self.delayTimeInterval, execute: {
                if let requester = self.requester {
                    self.internalDataTask = requester.request(URL: requestURL,
                                                              paramaters: self.internalParamaters,
                                                              headers: self.headers ?? [:],
                                                              method: self.internalType,
                                                              progress: self.internalProgressBlock,
                                                              success: self.internalSuccessBlock,
                                                              fail: self.internalFailBlock)
                }
            })
        } catch {
            
        }
    }
}

extension Biceps {
    open static var GET: Biceps {
        get {
            return Biceps(.GET)
        }
    }
    
    open static var POST: Biceps {
        get {
            return Biceps(.POST)
        }
    }
    
    open static var HEAD: Biceps {
        get {
            return Biceps(.HEAD)
        }
    }
    
    open static var DELETE: Biceps {
        get {
            return Biceps(.DELETE)
        }
    }
    
    open static var OPTIONS: Biceps {
        get {
            return Biceps(.OPTIONS)
        }
    }
    
    open static var PUT: Biceps {
        get {
            return Biceps(.PUT)
        }
    }
    
    open static var PATCH: Biceps {
        get {
            return Biceps(.PATCH)
        }
    }
    
    open static var TRACE: Biceps {
        get {
            return Biceps(.TRACE)
        }
    }
    
    open static var CONNECT: Biceps {
        get {
            return Biceps(.CONNECT)
        }
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

// MARK: Real request layer
internal protocol BicepsRequestable {
    func request(URL: URL, paramaters: [String:Any]?, headers: [String:String],
                 method: BicepsType,
                 progress: @escaping ProgressBlock,
                 success: @escaping (Dictionary<String, Any>) -> Void,
                 fail: @escaping (Error) -> Void) -> URLSessionTask
}

class BicepsHTTP: BicepsRequestable, BicepsConfigurable {
    static let shared: BicepsHTTP = BicepsHTTP()
    
    internal var logLevel: BicepsLogLevel = .Off
    internal var headers: [String : String]?

    private lazy var session: Alamofire.SessionManager = {
        let configuration = URLSessionConfiguration.default
        
        if let monitor = self.monitor, monitor.useDefaultMonitor == false {
            configuration.protocolClasses = monitor.customURLProtocols
        } else {
            configuration.protocolClasses = [(self.customURLProtocols?.first)!]
        }

        let sessionManager = Alamofire.SessionManager(configuration: configuration)
        
        if let receiveChallenge = BicepsGeneralConfigure.shared.sessionDidReceiveChallengeWithCompletion {
            sessionManager.delegate.sessionDidReceiveChallengeWithCompletion = receiveChallenge
        }
        
        return sessionManager
    }()
    
    func request(URL: URL, paramaters: [String : Any]?, headers: [String:String],
                 method: BicepsType,
                 progress: @escaping ProgressBlock,
                 success: @escaping (Dictionary<String, Any>) -> Void,
                 fail: @escaping (Error) -> Void) -> URLSessionTask {
        
        var _headers: [String:String]? = headers
        if let generalHeader = BicepsGeneralConfigure.shared.headers {
            for (key, value) in generalHeader {
                _ = _headers?.updateValue(value, forKey: key)
            }
        }

        return session.request(URL, method: convertMethod(method),
                               parameters: paramaters,
                               encoding: URLEncoding.default,
                               headers: _headers).responseJSON { (result) in
                if result.result.isSuccess {
                    if let ret = result.result.value {
                        success(ret as! Dictionary<String, Any>)
                    }
                } else if result.result.isFailure {
                    if let err = result.result.error {
                        fail(err)
                    }
                }
            }.task!
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

// MARK: Bicep Monitor
public protocol BicepsMonitorable {
    var customURLProtocols: Array<AnyClass>? { get }
    
    var useDefaultMonitor: Bool { get }
}

public extension BicepsMonitorable {
    var useDefaultMonitor: Bool {
        return true
    }
}

extension BicepsHTTP: BicepsMonitorable {
    var customURLProtocols: Array<AnyClass>? {
        get {
            return [ BicepsLogProtocol.self ]
        }
    }
    
    var monitor: BicepsMonitorable? {
        return BicepsGeneralConfigure.shared.monitor
    }
}

internal protocol BicepsLoggable {
    func log(level: BicepsLogLevel, request: URLRequest)
    func log(level: BicepsLogLevel, task: URLSessionTask, data: Data)
    func log(level: BicepsLogLevel, task: URLSessionTask, error: Error)
    func log(level: BicepsLogLevel, task: URLSessionTask, metrics: URLSessionTaskMetrics)
}

// MARK: Custom URLProtocol for default Monitor
let BicepsLogRequestKey = "BicepsLogRequestKey"

internal class BicepsLogProtocol: URLProtocol {
    private lazy var activeTask: URLSessionTask? = nil
    
    private lazy var session: URLSession = {
        
        let queue = OperationQueue()
        
        let configuration = URLSessionConfiguration.ephemeral
        
        if let monitor = self.monitor {
            configuration.protocolClasses = monitor.customURLProtocols
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

        log(level: BicepsGeneralConfigure.shared.logLevel, request: self.request)

        activeTask = session.dataTask(with: request as URLRequest)
        activeTask?.resume()
    }
    
    override func stopLoading() {
        activeTask?.cancel()
    }
}

extension BicepsLogProtocol {
    internal var monitor: BicepsMonitorable? {
        return BicepsGeneralConfigure.shared.monitor
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
            logMessage += String(bytes: data, encoding: .utf8)!
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
        log(level: BicepsGeneralConfigure.shared.logLevel, task: dataTask, data: data)
        self.client?.urlProtocol(self, didLoad: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        log(level: BicepsGeneralConfigure.shared.logLevel, task: task, metrics: metrics)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?){
        if let err = error {
            self.client?.urlProtocol(self, didFailWithError: err)
            log(level: BicepsGeneralConfigure.shared.logLevel, task: task, error: err)
        } else {
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }
}
