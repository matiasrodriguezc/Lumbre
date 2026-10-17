import Foundation
import Testing
@testable import LumbreCore

@Suite struct FeatureFlagTests {
    /// `-flag.reveal_synapse NO` deja en UserDefaults el texto "NO", no un Bool.
    @Test func launchArgumentOverrideAcceptsYesAndNo() {
        let key = "flag.\(FeatureFlag.revealSynapse.rawValue)"
        defer { UserDefaults.standard.removeObject(forKey: key) }

        UserDefaults.standard.set("NO", forKey: key)
        #expect(FeatureFlag.revealSynapse.isEnabled == false)
        UserDefaults.standard.set("YES", forKey: key)
        #expect(FeatureFlag.revealSynapse.isEnabled == true)
        UserDefaults.standard.set(false, forKey: key)
        #expect(FeatureFlag.revealSynapse.isEnabled == false)
    }
}
