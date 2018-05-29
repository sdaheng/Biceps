//
//  BicepsLogProtocol.swift
//  HomeNAS
//
//  Created by SDH on 03/04/2017.
//  Copyright © 2017 sdaheng. All rights reserved.
//

import Foundation

// MARK: Custom URLProtocol for default interceptor
let BicepsLogRequestKey = "BicepsLogRequestKey"

internal protocol BicepsLoggable {
    func log(level: BicepsLogLevel, request: URLRequest)
    func log(level: BicepsLogLevel, task: URLSessionTask, data: Data)
    func log(level: BicepsLogLevel, task: URLSessionTask, error: Error)
    @available(iOS 10.0, *)
    func log(level: BicepsLogLevel, task: URLSessionTask, metrics: URLSessionTaskMetrics)
}

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

let JSONAvaliableContentTypes = [ JSONMIMEType ]

extension BicepsLogProtocol: BicepsLoggable {
    @available(iOS 10.0, *)
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
        
        logMessage += "URL: \(String(describing: request.url))\n"
        logMessage += "method: \(String(describing: request.httpMethod))\n"
        logMessage += "headers: \(String(describing: request.allHTTPHeaderFields))\n"
        
        print(logMessage)
    }
    
    func log(level: BicepsLogLevel, task: URLSessionTask, data: Data) {
        guard level != .Off && level != .Error else {
            return
        }
        
        var logMessage = "[\(level)] Response "
        
        logMessage += "URL: \(String(describing: task.response?.url))\n"
        
        let httpResponse = task.response as! HTTPURLResponse
        
        if level == .All || level == .Debug {
            logMessage += "MIME-type: \(String(describing: task.response?.mimeType))\n"
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
            logMessage += "URL: \(String(describing: task.originalRequest?.url))"
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
    
    @available(iOS 10.0, *)
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
