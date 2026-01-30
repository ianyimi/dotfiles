#!/usr/bin/swift

import Foundation
import AppKit

class MonitorDaemon {
    // Dictionary mapping monitor ID -> last active workspace on that monitor
    private var monitorWorkspaces: [String: String] = [:]
    // The monitor ID that was last focused
    private var lastFocusedMonitor: String?
    private var isProcessing = false

    func start() {
        NSLog("[AeroMon] 🚀 AeroSpace Monitor Daemon started")
        NSLog("[AeroMon]    Listening for system sleep/wake events")

        // Listen for system sleep events (capture state before sleep)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )

        // Listen for system wake events (restore state after wake)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        NSLog("[AeroMon] ✅ Listeners registered - ready for sleep/wake events")

        // Keep the program running
        RunLoop.main.run()
    }

    @objc private func systemWillSleep(notification: Notification) {
        NSLog("[AeroMon] 😴 System going to sleep - capturing workspace state...")

        // Get the currently focused workspace
        guard let focusedWorkspace = runAerospaceQuery(["list-workspaces", "--focused"]) else {
            NSLog("[AeroMon] ⚠️  Failed to get focused workspace")
            return
        }

        // Get all monitors and their visible workspaces
        guard let monitorOutput = runAerospaceQuery(["list-monitors"]) else {
            NSLog("[AeroMon] ⚠️  Failed to get monitors")
            return
        }

        let monitorIds = monitorOutput.components(separatedBy: "\n")
            .map { line in
                line.components(separatedBy: "|").first?.trimmingCharacters(in: .whitespaces) ?? line.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }

        // Clear previous state and capture current state
        monitorWorkspaces.removeAll()
        var newFocusedMonitor: String?

        // Capture the visible workspace on EACH monitor
        for monitorId in monitorIds {
            guard let workspaces = runAerospaceQuery(["list-workspaces", "--monitor", monitorId, "--visible"]) else {
                continue
            }

            let visibleWorkspaces = workspaces.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            if let visibleWorkspace = visibleWorkspaces.first {
                monitorWorkspaces[monitorId] = visibleWorkspace

                // Determine which monitor has focus
                if visibleWorkspace == focusedWorkspace {
                    newFocusedMonitor = monitorId
                }
            }
        }

        lastFocusedMonitor = newFocusedMonitor

        // Log captured state
        NSLog("[AeroMon] 💾 Captured state (%d monitor(s)):", monitorWorkspaces.count)
        for (mid, ws) in monitorWorkspaces.sorted(by: { $0.key < $1.key }) {
            let focusMarker = mid == lastFocusedMonitor ? " 👆 (focused)" : ""
            NSLog("[AeroMon]    Monitor %@: workspace %@%@", mid, ws, focusMarker)
        }
    }

    private func findMonitorForWorkspace(_ workspace: String) -> String? {
        // Get all monitors
        guard let monitorOutput = runAerospaceQuery(["list-monitors"]) else {
            return nil
        }

        let monitorIds = monitorOutput.components(separatedBy: "\n")
            .map { line in
                line.components(separatedBy: "|").first?.trimmingCharacters(in: .whitespaces) ?? line.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }

        // Check each monitor to see if this workspace is visible on it
        for monitorId in monitorIds {
            guard let workspaces = runAerospaceQuery(["list-workspaces", "--monitor", monitorId]) else {
                continue
            }

            let visibleWorkspaces = workspaces.components(separatedBy: "\n")
            if visibleWorkspaces.contains(workspace) {
                return monitorId
            }
        }

        return nil
    }

    private func runAerospaceQuery(_ arguments: [String]) -> String? {
        let task = Process()
        let pipe = Pipe()

        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/aerospace")
        task.arguments = arguments
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                return output
            }
        } catch {
            // Silently fail
        }

        return nil
    }

    @objc private func systemDidWake(notification: Notification) {
        // Prevent multiple rapid-fire executions
        guard !isProcessing else { return }
        isProcessing = true

        NSLog("[AeroMon] 💤 System woke from sleep!")

        guard !monitorWorkspaces.isEmpty else {
            NSLog("[AeroMon] ⚠️  No workspace history to restore")
            isProcessing = false
            return
        }

        // Save the desired state to restore
        let savedWorkspaces = monitorWorkspaces
        let savedFocusedMonitor = lastFocusedMonitor

        NSLog("[AeroMon] 🎯 Will restore %d workspace(s) across %d monitor(s)",
              savedWorkspaces.count,
              savedWorkspaces.count)

        let expectedMonitorCount = savedWorkspaces.count

        // Wait for all monitors to be detected
        self.waitForMonitors(expectedCount: expectedMonitorCount) { [weak self] in
            guard let self = self else { return }

            NSLog("[AeroMon] ✅ All %d monitor(s) detected", expectedMonitorCount)
            NSLog("[AeroMon] ⏳ Waiting 1.5s for AeroSpace window detection...")

            // Brief additional wait for AeroSpace's on-window-detected rules
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }

                NSLog("[AeroMon] ✅ Restoring workspaces...")
                self.restoreWorkspaces(savedWorkspaces, focusedMonitor: savedFocusedMonitor)

                // Wait for restoration to fully settle before verification
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                    guard let self = self else { return }

                NSLog("[AeroMon] 🔍 Verifying restoration...")

                // Check if workspaces are still correct
                var needsCorrection = false
                for (monitorId, expectedWorkspace) in savedWorkspaces {
                    if let currentWorkspace = self.getCurrentWorkspaceForMonitor(monitorId),
                       currentWorkspace != expectedWorkspace {
                        NSLog("[AeroMon] ⚠️  Monitor %@ drifted to workspace %@ (expected %@)",
                              monitorId, currentWorkspace, expectedWorkspace)
                        needsCorrection = true
                    }
                }

                    if needsCorrection {
                        NSLog("[AeroMon] 🔧 Re-restoring workspaces (AeroSpace rules interfered)...")
                        self.restoreWorkspaces(savedWorkspaces, focusedMonitor: savedFocusedMonitor)

                        // Wait longer after re-restoration to ensure stability
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                            guard let self = self else { return }

                            NSLog("[AeroMon] ✅ Restoration complete - resuming workspace tracking")
                            self.isProcessing = false
                        }
                    } else {
                        NSLog("[AeroMon] ✅ Verification passed - workspaces are stable")

                        // Keep blocking for additional time to ignore late window detection rules
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                            guard let self = self else { return }

                            NSLog("[AeroMon] ✅ Restoration complete - resuming workspace tracking")
                            // Keep the saved state for next wake cycle - never clear it
                            self.isProcessing = false
                        }
                    }
                }
            }
        }
    }

    private func waitForMonitors(expectedCount: Int, completion: @escaping () -> Void) {
        let maxAttempts = 20  // Max 10 seconds (20 * 0.5s)
        var attempts = 0
        var initialCount = 0
        var hasSeenChange = false

        func checkMonitors() {
            // Get current monitor count from AeroSpace
            guard let monitorOutput = runAerospaceQuery(["list-monitors"]) else {
                // If AeroSpace isn't responding, retry
                attempts += 1
                if attempts < maxAttempts {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        checkMonitors()
                    }
                } else {
                    NSLog("[AeroMon] ⚠️  Timeout waiting for monitors, proceeding anyway")
                    completion()
                }
                return
            }

            let detectedMonitors = monitorOutput.components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .count

            // Capture initial count on first attempt
            if attempts == 0 {
                initialCount = detectedMonitors
                NSLog("[AeroMon] 📺 Initial monitor count: %d, expecting: %d", initialCount, expectedCount)
            }

            // Check if monitor count has changed from initial
            if detectedMonitors != initialCount {
                hasSeenChange = true
            }

            // Proceed if we've reached the expected count AND seen a change (or started with expected count)
            if detectedMonitors >= expectedCount && (hasSeenChange || initialCount >= expectedCount) {
                NSLog("[AeroMon] ✅ All %d monitor(s) detected", detectedMonitors)
                completion()
                return
            }

            // Keep waiting
            attempts += 1
            if attempts < maxAttempts {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    checkMonitors()
                }
            } else {
                // Timeout reached
                if detectedMonitors < expectedCount {
                    NSLog("[AeroMon] 💻 Timeout after 10s - detected %d/%d monitors (likely laptop mode), proceeding",
                          detectedMonitors, expectedCount)
                } else {
                    NSLog("[AeroMon] ⏳ Timeout after 10s - proceeding with %d monitor(s)",
                          detectedMonitors)
                }
                completion()
            }
        }

        // Start checking
        checkMonitors()
    }

    private func getCurrentWorkspaceForMonitor(_ monitorId: String) -> String? {
        // Get all workspaces visible on this monitor
        guard let workspaces = runAerospaceQuery(["list-workspaces", "--monitor", monitorId, "--visible"]) else {
            return nil
        }

        // Return the first visible workspace (should only be one per monitor)
        let visibleWorkspaces = workspaces.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return visibleWorkspaces.first
    }

    private func restoreWorkspaces(_ workspaces: [String: String], focusedMonitor: String?) {
        // Build list of workspaces to restore, with the last focused one at the end
        var workspacesToRestore: [(monitorId: String, workspace: String, isFocused: Bool)] = []

        // Add non-focused workspaces first
        for (monitorId, workspace) in workspaces {
            if monitorId != focusedMonitor {
                workspacesToRestore.append((monitorId, workspace, false))
            }
        }

        // Add the focused workspace last
        if let focusedMonitorId = focusedMonitor,
           let focusedWorkspace = workspaces[focusedMonitorId] {
            workspacesToRestore.append((focusedMonitorId, focusedWorkspace, true))
        }

        NSLog("[AeroMon] 🔄 Restoring workspaces in order:")
        for (index, item) in workspacesToRestore.enumerated() {
            let focusMarker = item.isFocused ? " 👆 (will restore last)" : ""
            NSLog("[AeroMon]    %d. Monitor %@ → workspace %@%@",
                  index + 1, item.monitorId, item.workspace, focusMarker)
        }

        for item in workspacesToRestore {
            // Focus the target monitor first, then switch workspace
            _ = runAerospaceCommand(["focus-monitor", item.monitorId])
            Thread.sleep(forTimeInterval: 0.1)

            // Navigate to target workspace on the now-focused monitor
            if runAerospaceCommand(["workspace", item.workspace]) {
                let focusMarker = item.isFocused ? " 👆" : ""
                NSLog("[AeroMon] ✅ Restored monitor %@ → workspace %@%@",
                      item.monitorId, item.workspace, focusMarker)
            } else {
                NSLog("[AeroMon] ⚠️  Failed to restore workspace %@ on monitor %@",
                      item.workspace, item.monitorId)
            }

            // Small delay between workspace switches
            Thread.sleep(forTimeInterval: 0.15)
        }

        NSLog("[AeroMon] ✨ All workspaces restored successfully!")
    }

    private func runAerospaceCommand(_ arguments: [String]) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/aerospace")
        task.arguments = arguments

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            NSLog("[AeroMon] ❌ Error running aerospace command: %@", error.localizedDescription)
            return false
        }
    }
}

// Handle SIGTERM and SIGINT gracefully
signal(SIGTERM) { _ in
    NSLog("[AeroMon] 👋 Received SIGTERM - shutting down gracefully")
    exit(0)
}

signal(SIGINT) { _ in
    NSLog("[AeroMon] 👋 Received SIGINT - shutting down gracefully")
    exit(0)
}

// Start the daemon
let daemon = MonitorDaemon()
daemon.start()
