import Foundation

struct AgentActivity {
    enum Kind: String {
        case codex = "Codex"
        case claude = "Claude Code"
    }

    let kind: Kind
    let pid: Int
    let detail: String

    var displayName: String {
        return String(format: "%@ %@", kind.rawValue, detail)
    }
}

extension AppDelegate {
    func syncKeepAwakeMode() {
        lastAgentActivity = detectAgentActivity()
        applyKeepAwakeState()
    }

    func detectAgentActivity() -> AgentActivity? {
        let output = runCommand("/bin/ps", ["-axo", "pid=,ppid=,args="])
        let ownPID = Int(ProcessInfo.processInfo.processIdentifier)

        for rawLine in output.split(separator: "\n").map(String.init) {
            guard let process = parseProcessLine(rawLine), process.pid != ownPID else {
                continue
            }

            let command = process.args.lowercased()
            if shouldIgnoreProcess(command) {
                continue
            }

            if isCodexAgent(command) {
                return AgentActivity(kind: .codex, pid: process.pid, detail: agentDetail(from: command))
            }
            if isClaudeAgent(command) {
                return AgentActivity(kind: .claude, pid: process.pid, detail: agentDetail(from: command))
            }
        }

        return nil
    }

    func parseProcessLine(_ line: String) -> (pid: Int, ppid: Int, args: String)? {
        let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count == 3, let pid = Int(parts[0]), let ppid = Int(parts[1]) else {
            return nil
        }
        return (pid, ppid, String(parts[2]))
    }

    func shouldIgnoreProcess(_ command: String) -> Bool {
        command.contains("vibecodingguard") ||
            command.contains("/vibe coding guard.app/") ||
            command.contains("/usr/bin/caffeinate") ||
            command.contains("/bin/ps -axo") ||
            command.contains("codex computer use.app") ||
            command.contains("skycomputeruseclient") ||
            command.contains("browser_crashpad_handler") ||
            command.contains("codex (renderer)") ||
            command.contains("codex (service)") ||
            command.contains("--type=gpu-process") ||
            command.contains("--type=renderer") ||
            command.contains("--type=utility")
    }

    func isCodexAgent(_ command: String) -> Bool {
        if command.contains("/codex app-server") {
            return true
        }

        let firstToken = command.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
        if firstToken.contains("/applications/codex.app/contents/resources/codex") {
            return command.contains(" app-server")
        }

        let executable = firstToken.split(separator: "/").last.map(String.init) ?? firstToken
        return executable == "codex" && !command.contains("/applications/codex.app/contents/macos/codex")
    }

    func isClaudeAgent(_ command: String) -> Bool {
        if command.contains("@anthropic-ai/claude-code") ||
            command.contains("claude-code") ||
            command.contains("claude code") {
            return true
        }

        let firstToken = command.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
        let executable = firstToken.split(separator: "/").last.map(String.init) ?? firstToken
        return executable == "claude" && !command.contains("/applications/claude.app/")
    }

    func agentDetail(from command: String) -> String {
        if command.contains("node_repl") {
            return "tool session".localized
        }
        if command.contains("app-server") {
            return "task".localized
        }
        if command.contains("claude") {
            return "task".localized
        }
        return "work".localized
    }
}
