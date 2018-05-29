//
//  BicepsHTTPRequesters.swift
//  HomeNAS
//
//  Created by SDH on 2018/5/29.
//  Copyright © 2018 sdaheng. All rights reserved.
//

import Foundation
import Alamofire

class Requester: BicepsURLRequestable {
    
    var dataRequest: DataRequest?
    var URL: URL
    var parameters: ParameterConvertible?
    var configuration: BicepsConfigurable?
    var method: BicepsType
    
    init(requestURL: URL, type: BicepsType) {
        URL = requestURL
        method = type
    }
    
    func request() -> DataRequest? {
        
        var _headers: [String:String]? = self.configuration?.headers
        if let generalHeader = BicepsHTTP.shared.generalConfiguartion.headers {
            for (key, value) in generalHeader {
                _ = _headers?.updateValue(value, forKey: key)
            }
        }
        
        do {
            let method = BicepsHTTP.shared.convertMethod(self.method)
            return BicepsHTTP.shared.session.request(self.URL,
                                                     method: method,
                                                     parameters: try self.parameters?.asDictionary(),
                                                     encoding: URLEncoding.default,
                                                     headers: _headers)
        } catch {
            return nil
        }
    }
}

class JSONRequester: BicepsJSONRequestable {
    var dataRequest: DataRequest?
    var URL: URL
    var parameters: ParameterConvertible?
    var configuration: BicepsConfigurable?
    var method: BicepsType
    
    init(requestURL: URL, type: BicepsType) {
        URL = requestURL
        method = type
    }
    
    func request() -> DataRequest? {
        var _headers: [String:String]? = self.configuration?.headers
        if let generalHeader = BicepsHTTP.shared.generalConfiguartion.headers {
            for (key, value) in generalHeader {
                _ = _headers?.updateValue(value, forKey: key)
            }
        }
        
        do {
            let method = BicepsHTTP.shared.convertMethod(self.method)
            return try BicepsHTTP.shared.session.request(URL, method: method,
                                                         parameters: self.parameters?.asDictionary(),
                                                         encoding: JSONEncoding.default,
                                                         headers: _headers)
        } catch {
            return nil
        }
    }
}

class ProtobufRequester: BicepsProtobufRequestable {
    var dataRequest: DataRequest?
    var URL: URL
    var parameters: ParameterConvertible?
    var configuration: BicepsConfigurable?
    var method: BicepsType
    
    init(requestURL: URL, type: BicepsType) {
        URL = requestURL
        method = type
    }
    
    func request() -> DataRequest? {
        var _headers: [String:String]? = self.configuration?.headers
        if let generalHeader = BicepsHTTP.shared.generalConfiguartion.headers {
            for (key, value) in generalHeader {
                _ = _headers?.updateValue(value, forKey: key)
            }
        }
        
        do {
            let method = BicepsHTTP.shared.convertMethod(self.method)
            return try BicepsHTTP.shared.session.request(URL, method: method,
                                                         parameters: self.parameters?.asDictionary(),
                                                         encoding: JSONEncoding.default,
                                                         headers: _headers)
        } catch {
            return nil
        }
    }
}

