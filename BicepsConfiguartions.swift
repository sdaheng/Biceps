//
//  BicepsConfiguartions.swift
//  HomeNAS
//
//  Created by SDH on 03/04/2017.
//  Copyright © 2017 sdaheng. All rights reserved.
//

import Foundation

// MARK: Biceps Configuration
protocol BicepsConfigurable {
    var headers: [String:String]? { get set }
    
    var logLevel: BicepsLogLevel { get set }
    
    var sessionDidReceiveChallengeWithCompletion: ((URLSession, URLAuthenticationChallenge, (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)? { get set }
    var backgroundCompletionHander: BackgroundCompletionHandler? { get set }
}

protocol BicepsDelegatable {
    
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
