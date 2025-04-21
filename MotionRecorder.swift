//
//  MotionRecorder.swift
//  SwingDataCollector
//
//  Created by Isaac Eng Gian Khor on 20/04/2025.
//
import CoreMotion
import Foundation
import WatchConnectivity

class MotionRecorder: NSObject, ObservableObject {
    private let motionManager = CMMotionManager()
    private let session: WCSession = .default
    @Published var isRecording = false
    private var samples: [[String]] = [["accelX", "accelY", "accelZ", "gyroX", "gyroY", "gyroZ", "swingType", "confidence"]]
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    func startRecording(swingType: String, duration: TimeInterval = 5.0, completion: @escaping (URL?) -> Void) {
        guard motionManager.isAccelerometerAvailable, motionManager.isGyroAvailable else {
            print("Accelerometer or Gyroscope not available")
            completion(nil)
            return
        }
        
        samples = [["accelX", "accelY", "accelZ", "gyroX", "gyroY", "gyroZ", "swingType", "confidence"]]
        isRecording = true
        
        motionManager.accelerometerUpdateInterval = 0.01 // 100 Hz
        motionManager.gyroUpdateInterval = 0.01 // 100 Hz
        
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] accelData, error in
            guard let self = self, let accel = accelData, self.isRecording else { return }
            
            self.motionManager.startGyroUpdates(to: .main) { gyroData, error in
                guard let gyro = gyroData, self.isRecording else { return }
                
                let sample = [
                    String(format: "%.3f", accel.acceleration.x),
                    String(format: "%.3f", accel.acceleration.y),
                    String(format: "%.3f", accel.acceleration.z),
                    String(format: "%.3f", gyro.rotationRate.x),
                    String(format: "%.3f", gyro.rotationRate.y),
                    String(format: "%.3f", gyro.rotationRate.z),
                    swingType,
                    "0.95" // Placeholder confidence
                ]
                self.samples.append(sample)
            }
        }
        
        // Stop after specified duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.stopRecording(swingType: swingType, completion: completion)
        }
    }
    
    func stopRecording(swingType: String, completion: (URL?) -> Void) {
        guard isRecording else {
            completion(nil)
            return
        }
        
        isRecording = false
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        
        // Save to CSV
        let csvString = samples.map { $0.joined(separator: ",") }.joined(separator: "\n")
        let fileName = "swing_data_\(swingType)_\(Date().timeIntervalSince1970).csv"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            // Transfer file to iPhone if on watchOS
            #if os(watchOS)
            if session.isReachable {
                session.transferFile(fileURL, metadata: ["swingType": swingType])
                print("Initiated file transfer to iPhone: \(fileURL.lastPathComponent)")
            } else {
                print("iPhone not reachable for file transfer")
            }
            #endif
            completion(fileURL)
        } catch {
            print("Error saving CSV: \(error)")
            completion(nil)
        }
    }
}

extension MotionRecorder: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error)")
        } else {
            print("WCSession activated with state: \(activationState.rawValue)")
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // Move file to a permanent location
        let fileName = file.fileURL.lastPathComponent
        let newURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try FileManager.default.moveItem(at: file.fileURL, to: newURL)
            print("Received file on iPhone: \(newURL.path)")
            // Notify UI to show share sheet
            NotificationCenter.default.post(name: .didReceiveFile, object: newURL)
        } catch {
            print("Error moving file: \(error)")
        }
    }
    #endif
    
    #if os(watchOS)
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error = error {
            print("File transfer failed: \(error)")
        } else {
            print("File transfer completed: \(fileTransfer.file.fileURL.lastPathComponent)")
        }
    }
    #endif
}

// Custom notification for file receipt
extension Notification.Name {
    static let didReceiveFile = Notification.Name("DidReceiveFile")
}
