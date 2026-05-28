//
//  LinksApp.swift
//  Links
//
//  Created by Clwyd on 20/05/2026.
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {

        DispatchQueue.main.async {

            guard let window = NSApplication.shared.windows.first else { return }

            // Allow dragging from anywhere in the window, not just a title bar
            window.isMovableByWindowBackground = true

            // Normal managed window — prevents snapping to fixed positions
            window.collectionBehavior = [.managed, .participatesInCycle]

            // Stop the window growing beyond the usable screen area
            window.minSize = NSSize(width: 280, height: 200)
            if let screen = NSScreen.main {
                window.maxSize = screen.visibleFrame.size
            }
        }
    }
}

@main
struct LinksApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
    }
}
