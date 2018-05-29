//
//  BicepsDownloaders.swift
//  HomeNAS
//
//  Created by SDH on 2018/5/29.
//  Copyright © 2018 sdaheng. All rights reserved.
//

import Foundation
import Alamofire

extension BicepsHTTP {
    struct Downloader: BicepsDownloadable {
        
        func download(URL: URLConvertible,
                      paramater: ParameterConvertible?,
                      configuration: BicepsConfigurable, destination: URL,
                      progress: @escaping ProgressBlock,
                      success: @escaping SuccessBlock,
                      fail: @escaping FailBlock) -> URLSessionTask? {
            do {
                let parameterDictionary = try paramater?.asDictionary()
                return shared.session.download(URL, method: .get,
                                               parameters: parameterDictionary,
                                               headers: configuration.headers) {
                                                (URL, response) -> (destinationURL: URL, options: DownloadRequest.DownloadOptions) in
                                                return (destination, .createIntermediateDirectories)
                    }.downloadProgress {
                        progress($0)
                    }.responseJSON { (response) in
                        shared.handleResponse(result: response.result, success: success, fail: fail)
                    }.task
            } catch {
                return nil
            }
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
        
        func download(URL: URLConvertible, paramater: ParameterConvertible?,
                      configuration: BicepsConfigurable, destination: URL,
                      progress: @escaping ProgressBlock,
                      success: @escaping SuccessBlock,
                      fail: @escaping FailBlock) -> URLSessionTask? {
            
            do {
                let parameterDictionary = try paramater?.asDictionary()
                return shared.backgroundSession.download(URL, method: .get,
                                                         parameters: parameterDictionary,
                                                         headers: configuration.headers) { (URL, response) -> (destinationURL: URL, options: DownloadRequest.DownloadOptions) in
                                                            return (destination, .createIntermediateDirectories)
                    }.downloadProgress {
                        progress($0)
                    }.responseJSON { (response) in
                        shared.handleResponse(result: response.result, success: success, fail: fail)
                    }.task
            } catch {
                return nil
            }
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
            let directoryPath = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory,
                                                                    .userDomainMask, true).first! + "/" + Bundle.main.bundleIdentifier!
            #endif
            
            return  directoryPath + "/" + fileName
        }
        
        func resumeData(for URL: URL) throws -> Data? {
            let resumeDataFilePath = self.resumeDataFilePath(try URL.asURL())
            
            return try Data(contentsOf: Foundation.URL(fileURLWithPath: resumeDataFilePath))
        }
        
        func download(URL: URLConvertible, paramater: ParameterConvertible?,
                      configuration: BicepsConfigurable, destination: URL,
                      progress: @escaping ProgressBlock,
                      success: @escaping SuccessBlock,
                      fail: @escaping FailBlock) -> URLSessionTask? {
            
            do {
                
                guard let resumeData = try self.resumeData(for: URL.asURL()) else {
                    let parameterDictionary = try paramater?.asDictionary()
                    return shared.session.download(URL, method: .get,
                                                   parameters: parameterDictionary,
                                                   headers: configuration.headers) { (URL, response) -> (destinationURL: URL, options: DownloadRequest.DownloadOptions) in
                                                    return (destination, .createIntermediateDirectories)
                        }.downloadProgress {
                            progress($0)
                        }.responseJSON { (response) in
                            shared.handleResponse(result: response.result, success: success, fail: fail)
                        }.task
                }
                return shared.backgroundSession.download(resumingWith: resumeData).downloadProgress {
                    progress($0)
                    }.responseJSON { (response) in
                        shared.handleResponse(result: response.result, success: success, fail: fail)
                    }.task
                
            } catch {
                return nil
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
