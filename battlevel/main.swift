import Foundation

import IOKit
import IOKit.ps

class Daemon {
    private var timer: Timer = Timer()
    private var currChargeLevel: Int64 = -1;
    
    init() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let updatedChargeLevel = self.getBatteryChargePercentage();
            if self.currChargeLevel == -1 {
                self.currChargeLevel = updatedChargeLevel
                self.log(message: "Battery charge level \(updatedChargeLevel)%")
            }
            else {
                if self.currChargeLevel != updatedChargeLevel {
                    self.currChargeLevel = updatedChargeLevel
                    self.log(message: "Battery charge level \(updatedChargeLevel)%")
                }
            }
        }
    }
    
    func start() {
        log(message: "Starting the daemon")
        RunLoop.current.add(self.timer, forMode: .default)
        RunLoop.current.run()
    }
    
    func stop() {
        log(message: "Stopping the daemon")
        self.timer.invalidate()
    }
    
    private func sendCurlCommand(to ipAddress: String, with parameters: String) {
        log(message: "Sending curl command to \(ipAddress) with parameters: \(parameters)")
        let command = "curl -X POST -d \(parameters) \(ipAddress)"
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        task.launch()
        task.waitUntilExit()
    }

    public func getBatteryChargePercentage() -> Int64 {
        let powerSources = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        guard let powerSourcesArray = powerSources as? [NSDictionary] else {
            self.log(message: "Didn't get battery information")
            return 0
        }
        
        var batteryChargePercentage : Int64 = 0
        for powerSource in powerSourcesArray {
            guard let currentCapacity = powerSource.value(forKey: "Current Capacity") as? Int64,
                  let maxCapacity = powerSource.value(forKey: "Max Capacity") as? Int64 else {
                continue
            }
            batteryChargePercentage = (currentCapacity * 100) / maxCapacity
        }

        return batteryChargePercentage
    }
    
    private func log(message: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd hh:mm:ss"
        let dateString = dateFormatter.string(from: Date())
        
        let logMessage = "[\(dateString)] \(message)\n"
        let logFilePath = "daemon.log"
        
        if let logFileHandle = FileHandle(forWritingAtPath: logFilePath) {
            logFileHandle.seekToEndOfFile()
            logFileHandle.write(logMessage.data(using: .utf8)!)
            logFileHandle.closeFile()
        } else {
            do {
                try logMessage.write(toFile: logFilePath, atomically: true, encoding: .utf8)
            } catch {
                print("Error writing to log file: \(error)")
            }
        }
    }
}

let daemon = Daemon()

// Check if the program was launched with start or stop arguments
if CommandLine.arguments.count > 1 {
    switch CommandLine.arguments[1] {
    case "start":
        daemon.start()
    case "stop":
        daemon.stop()
    default:
        print("Unknown argument. Use start or stop.")
    }
} else {
    print("No argument provided. Use start or stop.")
}
