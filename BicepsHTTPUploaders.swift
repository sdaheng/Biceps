//
//  BicepsHTTPUploaders.swift
//  HomeNAS
//
//  Created by SDH on 2018/5/29.
//  Copyright © 2018 sdaheng. All rights reserved.
//

import Foundation
import Alamofire

extension BicepsHTTP {
    
    struct Uploader: BicepsUploadable {
        
        func upload(URL: URL, filePath: String, headers: [String:String]?,
                    progress: @escaping ProgressBlock,
                    success: @escaping SuccessBlock,
                    fail: @escaping FailBlock) -> URLSessionTask? {
            
            let fileURL = Foundation.URL(fileURLWithPath: filePath)
            
            let task = shared.session.upload(fileURL, to: URL, headers: headers).uploadProgress {
                progress($0)
                }.responseJSON { response in
                    shared.handleResponse(result: response.result,
                                          success: success, fail: fail)
                }.task
            
            return task
        }
        
        func upload(URL: URL, mutipartFormData: @escaping (MultipartFormData) -> Void,
                    headers: [String:String]?,
                    progress: @escaping ProgressBlock,
                    success: @escaping SuccessBlock,
                    fail: @escaping FailBlock) -> URLSessionTask? {
            
            var task: URLSessionTask? = nil
            shared.session.upload(multipartFormData: {
                mutipartFormData($0)
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
            
            let uploadTask = shared.backgroundSession.upload(fileURL,
                                                             to: URL,
                                                             headers: headers).uploadProgress {
                                                                progress($0)
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
