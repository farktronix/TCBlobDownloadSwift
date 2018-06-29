//
//  TCBlobDownloadManager.swift
//  TCBlobDownloadSwift
//
//  Created by Thibault Charbonnier on 30/12/14.
//  Copyright (c) 2014 thibaultcha. All rights reserved.
//

import Foundation

public let kTCBlobDownloadSessionIdentifier = "tcblobdownloadmanager_downloads"

public let kTCBlobDownloadErrorDomain = "com.tcblobdownloadswift.error"
public let kTCBlobDownloadErrorDescriptionKey = "TCBlobDownloadErrorDescriptionKey"
public let kTCBlobDownloadErrorHTTPStatusKey = "TCBlobDownloadErrorHTTPStatusKey"
public let kTCBlobDownloadErrorFailingURLKey = "TCBlobDownloadFailingURLKey"

public enum TCBlobDownloadError: Int {
    case tcBlobDownloadHTTPError = 1
    case tcBlobDownloadFileError
}

@objc open class TCBlobDownloadManager : NSObject {
    /**
     A shared instance of `TCBlobDownloadManager`.
     */
    @objc open static let sharedInstance = TCBlobDownloadManager()
    
    /// Instance of the underlying class implementing `NSURLSessionDownloadDelegate`.
    fileprivate let delegate: DownloadDelegate
    
    /// If `true`, downloads will start immediatly after being created. `true` by default.
    @objc open var startImmediatly = true
    
    /// The underlying `NSURLSession`.
    @objc open let session: URLSession
    
    @objc open var allowRedirection: Bool {
        set {
            self.delegate.allowRedirection = newValue
        }
        get {
            return self.delegate.allowRedirection
        }
    }
    
    /**
     Custom `NSURLSessionConfiguration` init.
     
     - parameter config: The configuration used to manage the underlying session.
     */
    @objc public init(config: URLSessionConfiguration) {
        self.delegate = DownloadDelegate()
        self.session = URLSession(configuration: config, delegate: self.delegate, delegateQueue: nil)
        self.session.sessionDescription = "TCBlobDownloadManger session"
    }
    
    /**
     Default `NSURLSessionConfiguration` init.
     */
    @objc public convenience override init() {
        let config = URLSessionConfiguration.default
        //config.HTTPMaximumConnectionsPerHost = 1
        self.init(config: config)
    }
    
    /**
     Base method to start a download, called by other download methods.
     
     - parameter download: Download to start.
     */
    fileprivate func downloadWithDownload(_ download: TCBlobDownload) -> TCBlobDownload {
        self.delegate.downloads[download.downloadTask.taskIdentifier] = download
        
        if self.startImmediatly {
            download.downloadTask.resume()
        }
        
        return download
    }
    
    /**
     Start downloading the file at the given URL.
     
     - parameter request: NSURLRequest of the file to download.
     - parameter directory: Directory Where to copy the file once the download is completed. If `nil`, the file will be downloaded in the current user temporary directory/
     - parameter name: Name to give to the file once the download is completed.
     - parameter delegate: An eventual delegate for this download.
     
     :return: A `TCBlobDownload` instance.
     */
    @objc open func downloadFileWithRequest(_ request: URLRequest, toDirectory directory: URL?, withName name: String?, andDelegate delegate: TCBlobDownloadDelegate?) -> TCBlobDownload {
        let downloadTask = self.session.downloadTask(with: request)
        let download = TCBlobDownload(downloadTask: downloadTask, toDirectory: directory, fileName: name, delegate: delegate)
        
        return self.downloadWithDownload(download)
    }
    
    /**
     Start downloading the file at the given URL.
     
     - parameter url: NSURL of the file to download.
     - parameter directory: Directory Where to copy the file once the download is completed. If `nil`, the file will be downloaded in the current user temporary directory/
     - parameter name: Name to give to the file once the download is completed.
     - parameter delegate: An eventual delegate for this download.
     
     :return: A `TCBlobDownload` instance.
     */
    @objc open func downloadFileAtURL(_ url: URL, toDirectory directory: URL?, withName name: String?, andDelegate delegate: TCBlobDownloadDelegate?) -> TCBlobDownload {
        return downloadFileWithRequest(URLRequest(url: url), toDirectory: directory, withName: name, andDelegate: delegate)
    }
    
    /**
     Start downloading the file at the given URL.
     
     - parameter request: NSURLRequest of the file to download.
     - parameter directory: Directory Where to copy the file once the download is completed. If `nil`, the file will be downloaded in the current user temporary directory/
     - parameter name: Name to give to the file once the download is completed.
     - parameter progression: A closure executed periodically when a chunk of data is received.
     - parameter completion: A closure executed when the download has been completed.
     
     :return: A `TCBlobDownload` instance.
     */
    @objc open func downloadFileWithRequest(_ request: URLRequest, toDirectory directory: URL?, withName name: String?, progression: progressionHandler?, completion: completionHandler?) -> TCBlobDownload {
        let downloadTask = self.session.downloadTask(with: request)
        let download = TCBlobDownload(downloadTask: downloadTask, toDirectory: directory, fileName: name, progression: progression, completion: completion)
        
        return self.downloadWithDownload(download)
    }
    
    /**
     Start downloading the file at the given URL.
     
     - parameter url: NSURL of the file to download.
     - parameter directory: Directory Where to copy the file once the download is completed. If `nil`, the file will be downloaded in the current user temporary directory/
     - parameter name: Name to give to the file once the download is completed.
     - parameter progression: A closure executed periodically when a chunk of data is received.
     - parameter completion: A closure executed when the download has been completed.
     
     :return: A `TCBlobDownload` instance.
     */
    @objc open func downloadFileAtURL(_ url: URL, toDirectory directory: URL?, withName name: String?, progression: progressionHandler?, completion: completionHandler?) -> TCBlobDownload {
        return downloadFileWithRequest(URLRequest(url: url), toDirectory: directory, withName: name, progression: progression, completion: completion)
    }
    
    
    /**
     Resume a download with previously acquired resume data.
     
     :see: `TCBlobDownload -cancelWithResumeData:` to produce this data.
     
     - parameter resumeData: Data blob produced by a previous download cancellation.
     - parameter directory: Directory Where to copy the file once the download is completed. If `nil`, the file will be downloaded in the current user temporary directory/
     - parameter name: Name to give to the file once the download is completed.
     - parameter delegate: An eventual delegate for this download.
     
     :return: A `TCBlobDownload` instance.
     */
    @objc open func downloadFileWithResumeData(_ resumeData: Data, toDirectory directory: URL?, withName name: String?, andDelegate delegate: TCBlobDownloadDelegate?) -> TCBlobDownload {
        let downloadTask = self.session.downloadTask(withResumeData: resumeData)
        let download = TCBlobDownload(downloadTask: downloadTask, toDirectory: directory, fileName: name, delegate: delegate)
        
        return self.downloadWithDownload(download)
    }
    
    /**
     Gets the downloads in a given state currently being processed by the instance of `TCBlobDownloadManager`.
     
     - parameter state: The state by which to filter the current downloads.
     
     :return: An `Array` of all current downloads with the given state.
     */
    open func currentDownloadsFilteredByState(_ state: URLSessionTask.State?) -> [TCBlobDownload] {
        var downloads = [TCBlobDownload]()
        
        // TODO: make functional as soon as Dictionary supports reduce/filter.
        for download in self.delegate.downloads.values {
            if state == nil || download.downloadTask.state == state {
                downloads.append(download)
            }
        }
        
        return downloads
    }
}


@objc class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    
    @objc var downloads: [Int: TCBlobDownload] = [:]
    let acceptableStatusCodes: CountableRange<Int> = 200..<300
    @objc var allowRedirection = false
    
    @objc func validateResponse(_ response: HTTPURLResponse) -> Bool {
        return self.acceptableStatusCodes.contains(response.statusCode)
    }
    
    // MARK: NSURLSessionDownloadDelegate
    
    @objc func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(self.allowRedirection ? request : nil)
    }
    
    @objc func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        print("Resume at offset: \(fileOffset) total expected: \(expectedTotalBytes)")
    }
    
    @objc func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if let download = self.downloads[downloadTask.taskIdentifier] {
            let progress = totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown ? -1 : Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            
            download.progress = progress
            download.totalBytesWritten = totalBytesWritten
            download.totalBytesExpectedToWrite = totalBytesExpectedToWrite
            
            DispatchQueue.main.async {
                download.delegate?.download(download, didProgress: progress, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
                download.progression?(progress, totalBytesWritten, totalBytesExpectedToWrite)
                return
            }
        }
    }
    
    @objc func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let download = self.downloads[downloadTask.taskIdentifier] {
            do {
                var resultingURL: NSURL?
                if FileManager.default.fileExists(atPath: download.destinationURL.path) {
                    try FileManager.default.replaceItem(at: download.destinationURL as URL, withItemAt: location, backupItemName: nil, options: [], resultingItemURL: &resultingURL)
                } else {
                    // Check if the parent directory exists already and create it if needed
                    var isDir : ObjCBool = false
                    let parentDirectory = download.destinationURL.deletingLastPathComponent()
                    let exists = FileManager.default.fileExists(atPath: parentDirectory.path, isDirectory: &isDir)
                    if (!exists) {
                        try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)
                    } else if (isDir.boolValue == false) {
                        let errorString = "Cannot download to \(download.destinationURL) because that path is not a directory"
                        print(errorString)
                        throw NSError(domain: kTCBlobDownloadErrorDomain,
                                      code: TCBlobDownloadError.tcBlobDownloadFileError.rawValue,
                                        userInfo: [kTCBlobDownloadErrorDescriptionKey: errorString,
                                            kTCBlobDownloadErrorFailingURLKey: downloadTask.originalRequest!.url!])
                    }
                 
                    // Move the file into place
                    try FileManager.default.moveItem(at: location, to: download.destinationURL as URL)
                }
                download.resultingURL = resultingURL as URL? ?? download.destinationURL
            } catch let error as NSError {
                download.error = error
            }
        } else {
            do {
                try FileManager.default.removeItem(at: location)
            }
            catch let error as NSError {
                print(error.description)
            }
        }
    }
    
    @objc func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError sessionError: Error?) {
        if let download = self.downloads[task.taskIdentifier] {
            var error: NSError? = sessionError as NSError?? ?? download.error
            // Handle possible HTTP errors
            if let response = task.response as? HTTPURLResponse {
                // NSURLErrorDomain errors are not supposed to be reported by this delegate
                // according to https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/URLLoadingSystem/NSURLSessionConcepts/NSURLSessionConcepts.html
                // so let's ignore them as they sometimes appear there for now. (But WTF?)
                if !validateResponse(response) && (error == nil || error!.domain == NSURLErrorDomain) {
                    error = NSError(domain: kTCBlobDownloadErrorDomain,
                                    code: response.statusCode,
                                    userInfo: [kTCBlobDownloadErrorDescriptionKey: "Erroneous HTTP status code: \(response.statusCode)",
                                        kTCBlobDownloadErrorFailingURLKey: task.originalRequest!.url!,
                                        kTCBlobDownloadErrorHTTPStatusKey: response.statusCode])
                }
            }
            
            // Remove the reference to the download
            self.downloads.removeValue(forKey: task.taskIdentifier)
            
            DispatchQueue.main.async {
                download.delegate?.download(download, didFinishWithError: error, atLocation: download.resultingURL)
                download.completion?(error, download.resultingURL)
                return
            }
        }
    }
}
