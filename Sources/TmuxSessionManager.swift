import Foundation

class TmuxSessionManager {
    static let shared = TmuxSessionManager()
    private init() {}

    func getActiveSessions() -> [String] {
        let output = shell("tmux list-sessions -F '#{session_name}:#{session_attached}' 2>/dev/null")
        let sessions = output
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line -> String? in
                let parts = line.split(separator: ":", maxSplits: 1)
                guard parts.count == 2, parts[1] != "0" else { return nil }
                return String(parts[0])
            }

        return sessions.filter { hasClaudeRunning(in: $0) }
    }

    func send(text: String, to session: String) {
        let escaped = text.replacingOccurrences(of: "'", with: "'\\''")
        shell("tmux send-keys -t '\(session)' '\(escaped)' Enter")
    }

    // MARK: - Private

    private func hasClaudeRunning(in session: String) -> Bool {
        let pids = shell("tmux list-panes -t '\(session)' -F '#{pane_pid}' 2>/dev/null")
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }

        for pid in pids {
            let allPids = ([pid] + shell("pgrep -P \(pid) 2>/dev/null")
                .components(separatedBy: "\n")
                .filter { !$0.isEmpty })

            for p in allPids {
                let name = shell("ps -o comm= -p \(p) 2>/dev/null")
                if name.lowercased().contains("claude") { return true }
            }
        }
        return false
    }

    @discardableResult
    private func shell(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH; \(command)"]
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
