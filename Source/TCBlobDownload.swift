//
//  TCBlobDownload.swift
//  TCBlobDownloadSwift
//
//  Created by Thibault Charbonnier on 30/12/14.
//  Copyright (c) 2014 thibaultcha. All rights reserved.
//

import Foundation

public typealias progressionHandler = ((_ progress: Float, _ totalBytesWritten: Int64, _ totalBytesExpectedToWrite: Int64) -> Void)
public typealias completionHandler = ((_ error: NSError?, _ location: URL?) -> Void)

@objc open class TCBlobDownload : NSObject {
    /// The underlying download task.
    @objc open let downloadTask: URLSessionDownloadTask

    /// An optional delegate to get notified of events.
    @objc open weak var delegate: TCBlobDownloadDelegate?

    /// An optional progression closure periodically executed when a chunk of data has been received.
    @objc open var progression: progressionHandler?

    /// An optional completion closure executed when a download was completed by the download task.
    @objc open var completion: completionHandler?

    /// An optional file name set by the user.
    fileprivate let preferedFileName: String?

    /// An optional destination path for the file. If nil, the file will be downloaded in the current user temporary directory.
    fileprivate let directory: URL?

    /// Will contain an error if the downloaded file couldn't be moved to its final destination.
    @objc var error: NSError?

    /// Current progress of the download, a value between 0 and 1. 0 means nothing was received and 1 means the download is completed. If expected size if unknown value equals -1
    @objc open var progress: Float = 0
    
    /// Current progress of the download, bytes of downloaded part
    @objc open var totalBytesWritten: Int64 = 0
    
    /// Current progress of the download, whole size in bytes. If expected size if unknown value equals -1
    @objc open var totalBytesExpectedToWrite: Int64 = 0

    /// If the moving of the file after downloading was successful, will contain the `NSURL` pointing to the final file.
    @objc open var resultingURL: URL?

    /// A computed property to get the filename of the downloaded file.
    @objc open var fileName: String? {
        return self.preferedFileName ?? self.downloadTask.response?.suggestedFilename
    }

    /// A computed destination URL depending on the `destinationPath`, `fileName`, and `suggestedFileName` from the underlying `NSURLResponse`.
    @objc open var destinationURL: URL {
        let destinationPath = self.directory ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return destinationPath.appendingPathComponent(self.fileName!)
    }

    /**
        Initialize a new download assuming the `NSURLSessionDownloadTask` was already created.
    
        - parameter downloadTask: The underlying download task for this download.
        - parameter directory: The directory where to move the downloaded file once completed.
        - parameter fileName: The preferred file name once the download is completed.
        - parameter delegate: An optional delegate for this download.
    */
    @objc init(downloadTask: URLSessionDownloadTask, toDirectory directory: URL?, fileName: String?, delegate: TCBlobDownloadDelegate?) {
        self.downloadTask = downloadTask
        self.directory = directory
        self.preferedFileName = fileName
        self.delegate = delegate
    }

    /**
        
    */
    @objc convenience init(downloadTask: URLSessionDownloadTask, toDirectory directory: URL?, fileName: String?, progression: progressionHandler?, completion: completionHandler?) {
        self.init(downloadTask: downloadTask, toDirectory: directory, fileName: fileName, delegate: nil)
        self.progression = progression
        self.completion = completion
    }

    /**
        Cancel a download. The download cannot be resumed after calling this method.
    
        :see: `NSURLSessionDownloadTask -cancel`
    */
    @objc open func cancel() {
        self.downloadTask.cancel()
    }

    /**
        Suspend a download. The download can be resumed after calling this method.
    
        :see: `TCBlobDownload -resume`
        :see: `NSURLSessionDownloadTask -suspend`
    */
    @objc open func suspend() {
        self.downloadTask.suspend()
    }

    /**
        Resume a previously suspended download. Can also start a download if not already downloading.
    
        :see: `NSURLSessionDownloadTask -resume`
    */
    @objc open func resume() {
        self.downloadTask.resume()
    }
    
    /**
        Convinience method
    */
    @objc open var isSuspended: Bool {
        return self.downloadTask.state == .suspended
    }

    /**
        Cancel a download and produce resume data. If stored, this data can allow resuming the download at its previous state.

        :see: `TCBlobDownloadManager -downloadFileWithResumeData`
        :see: `NSURLSessionDownloadTask -cancelByProducingResumeData`

        - parameter completionHandler: A completion handler that is called when the download has been successfully canceled. If the download is resumable, the completion handler is provided with a resumeData object.
    */
    @objc open func cancelWithResumeData(_ completionHandler: @escaping (Data?) -> Void) {
        self.downloadTask.cancel(byProducingResumeData: completionHandler)
    }

    // TODO: remaining time
    // TODO: instanciable TCBlobDownloads
}

@objc public protocol TCBlobDownloadDelegate: class {
    /**
        Periodically informs the delegate that a chunk of data has been received (similar to `NSURLSession -URLSession:dataTask:didReceiveData:`).
    
        :see: `NSURLSession -URLSession:dataTask:didReceiveData:`
    
        - parameter download: The download that received a chunk of data.
        - parameter progress: The current progress of the download, between 0 and 1. 0 means nothing was received and 1 means the download is completed.
        - parameter totalBytesWritten: The total number of bytes the download has currently written to the disk.
        - parameter totalBytesExpectedToWrite: The total number of bytes the download will write to the disk once completed.
    */
    @objc func download(_ download: TCBlobDownload, didProgress progress: Float, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)

    /**
        Informs the delegate that the download was completed (similar to `NSURLSession -URLSession:task:didCompleteWithError:`).
    
        :see: `NSURLSession -URLSession:task:didCompleteWithError:`
    
        - parameter download: The download that received a chunk of data.
        - parameter error: An eventual error. If `nil`, consider the download as being successful.
        - parameter location: The location where the downloaded file can be found.
    */
    @objc func download(_ download: TCBlobDownload, didFinishWithError error: NSError?, atLocation location: URL?)
}

// MARK: Printable

extension TCBlobDownload {
    override open var description: String {
        var parts: [String] = []
        var state: String
        
        switch self.downloadTask.state {
            case .running: state = "running"
            case .completed: state = "completed"
            case .canceling: state = "canceling"
            case .suspended: state = "suspended"
        }
        
        parts.append("TCBlobDownload")
        parts.append("URL: \(String(describing: self.downloadTask.originalRequest!.url))")
        parts.append("Download task state: \(state)")
        parts.append("destinationPath: \(String(describing: self.directory))")
        parts.append("fileName: \(String(describing: self.fileName))")
        
        return parts.joined(separator: " | ")
    }
}
