import UIKit

class NotificationCounterStream: NSObject {
    var inputStream: InputStream!
    var outputStream: OutputStream!
    
    let address: String
    let port: UInt32
    let maxReadLength: Int
    weak var delegate: NotificationCounterDelegate?
    
    init(address: String, port: UInt32, maxReadLength: Int = 4096) {
        self.address = address
        self.port = port
        self.maxReadLength = maxReadLength
    }
    
    func setupConnection(){
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, address as CFString, port, &readStream, &writeStream)
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()
        
        [inputStream,outputStream].forEach { (stream) in
            stream?.schedule(in: .current, forMode: .common)
            stream?.open()

        }
        
        inputStream.delegate = self
    }
    
    func startListining(token: String){
        // data to be sent
        let data = "iam:\(token)".data(using: .utf8)!
        
        // provides a convenient way to work with an unsafe pointer version of some data within the safe confines of a closure
        _ = data.withUnsafeBytes {
            guard let pointer = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                print("Error joining chat")
                return
            }
            // write your message to the output stream
            outputStream.write(pointer, maxLength: data.count)
        }
    }
    
}

extension NotificationCounterStream: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            handleRecievedBytes(stream: aStream as! InputStream)
        case .openCompleted:
            print("connection opened")
        case .hasSpaceAvailable:
            print("has space available, you can write to the stream")
        case .errorOccurred:
            print("error occurred")
        case .endEncountered:
            close()
        default:
            break
        }
    }
    
    private func handleRecievedBytes(stream: InputStream){
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadLength)
        
        while stream.hasBytesAvailable {
            let numberOfBytesRead = inputStream.read(buffer, maxLength: maxReadLength)
            
            if numberOfBytesRead < 0, let error = stream.streamError {
                print(error)
                break
            }
            
            if let notificationCount = processString(buffer: buffer, length: numberOfBytesRead) {
                // Notify interested parties
                delegate?.notificationCounter(didRecieve: notificationCount)
            }
        }
    }
    
    func close(){
        [inputStream, outputStream].forEach { (stream) in
            stream?.remove(from: .current, forMode: .common)
            stream?.delegate = nil
            stream?.close()
        }
    }
    
    private func processString(buffer: UnsafeMutablePointer<UInt8>,
                                        length: Int) -> String? {
        // message formate notificationCount:12
        guard
            let stringArray = String(
                bytesNoCopy: buffer,
                length: length,
                encoding: .utf8,
                freeWhenDone: true)?.components(separatedBy: ":"),
            let text = stringArray.last
            else {
                return nil
        }
        return text
    }
   
}

protocol NotificationCounterDelegate: class {
    func notificationCounter(didRecieve count: String)
}
