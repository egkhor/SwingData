//
//  ContentView.swift
//  SwingDataCollector Watch App
//
//  Created by Isaac Eng Gian Khor on 20/04/2025.
//

import SwiftUI
import WatchKit

struct ContentView: View {
    @StateObject private var recorder = MotionRecorder()
    @State private var swingType = "Forehand"
    
    var body: some View {
        VStack {
            Text("Swing Collector")
                .font(.system(size: 14))
            
            Picker("Swing", selection: $swingType) {
                Text("Forehand").tag("Forehand")
                Text("Backhand").tag("Backhand")
                Text("Serve").tag("Serve")
            }
            .frame(height: 50)
            
            Button(recorder.isRecording ? "Recording..." : "Record") {
                recorder.startRecording(swingType: swingType) { url in
                    if url != nil {
                        WKInterfaceDevice.current().play(.success)
                        print("Saved and transferring: \(url?.lastPathComponent ?? "unknown")")
                    } else {
                        WKInterfaceDevice.current().play(.failure)
                        print("Failed to save CSV")
                    }
                }
            }
            .disabled(recorder.isRecording)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
