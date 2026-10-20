import Foundation
import Testing
@testable import CleanerCore

struct SafetyAdvisorTests {
    let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)

    private func verdict(_ relative: String) -> SafetyAdvice.Verdict {
        SafetyAdvisor.advise(for: home.appendingPathComponent(relative), home: home).verdict
    }

    @Test(arguments: [
        "Library/Caches/com.example/blob",
        "Library/Logs/thing.log",
        "Library/Developer/Xcode/DerivedData/App-abc/Build/x.o",
        "code/web/node_modules/.pnpm/big.node",
        "Downloads/Installer.dmg",
    ])
    func safeFiles(relative: String) { #expect(verdict(relative) == .safe) }

    @Test(arguments: [
        "Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw",
        "Library/Application Support/rancher-desktop/lima/0/diffdisk",
        "VMs/ubuntu.qcow2",
        "code/app/.git/objects/pack/pack-1.pack",
        "Library/Application Support/Slack/IndexedDB/big.db",
        ".ssh/key",
        "Pictures/Photos Library.photoslibrary/originals/x.mov",
    ])
    func keepFiles(relative: String) { #expect(verdict(relative) == .keep) }

    @Test(arguments: [
        "Movies/holiday.mov",
        "Documents/report.pdf",
        "projects/build.zip",
        "Library/Developer/Xcode/Archives/2026-01-01/App.xcarchive",
        "Library/Application Support/MobileSync/Backup/abc/Manifest.db",
        "misc/unknown.bin",
    ])
    func reviewFiles(relative: String) { #expect(verdict(relative) == .review) }

    @Test func outsideHomeIsKeep() {
        let advice = SafetyAdvisor.advise(for: URL(fileURLWithPath: "/opt/data.bin"), home: home)
        #expect(advice.verdict == .keep)
    }

    @Test func ageNotes() {
        let now = Date()
        #expect(SafetyAdvisor.ageNote(now.addingTimeInterval(-200 * 86_400), now: now)?.contains("200 days") == true)
        #expect(SafetyAdvisor.ageNote(now.addingTimeInterval(-86_400), now: now)?.contains("recently") == true)
        #expect(SafetyAdvisor.ageNote(now.addingTimeInterval(-30 * 86_400), now: now) == nil)
        #expect(SafetyAdvisor.ageNote(nil, now: now) == nil)
    }
}
