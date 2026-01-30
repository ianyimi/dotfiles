import Cocoa
import MediaPlayer

// Create alert function
func showAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

// Request media permissions via MPMediaLibrary
MPMediaLibrary.requestAuthorization { status in
    DispatchQueue.main.async {
        switch status {
        case .authorized:
            showAlert(title: "Success", message: "Media permissions have been granted. Restart sketchybar with: brew services restart sketchybar")
        case .denied:
            showAlert(title: "Permission Denied", message: "Media permissions were denied. Please go to System Settings > Privacy & Security > Media & Apple Music and enable permissions for Terminal.")
        case .notDetermined:
            showAlert(title: "Permission Not Determined", message: "Media permissions status is not determined. Please try again.")
        case .restricted:
            showAlert(title: "Permission Restricted", message: "Media permissions are restricted. This may be due to parental controls or other system restrictions.")
        @unknown default:
            showAlert(title: "Unknown Status", message: "Unknown permission status.")
        }
        exit(0)
    }
}

// Keep the application running until we get a response
RunLoop.main.run(until: Date(timeIntervalSinceNow: 60))