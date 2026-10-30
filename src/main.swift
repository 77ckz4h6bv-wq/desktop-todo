import AppKit

let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.setActivationPolicy(.accessory)
MenuBuilder.installMainMenu()
app.run()