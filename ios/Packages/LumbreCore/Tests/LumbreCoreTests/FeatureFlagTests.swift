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

    /// El swipe del reveal (paso 93): evento y flag con los nombres de docs/analytics.md.
    @Test func sparkSwipedEvent() {
        let event = AnalyticsEvent.sparkSwiped(mode: .daily, direction: "save", input: "gesture")
        #expect(event.name == "spark_swiped")
        #expect(event.properties["mode"] == .string("daily"))
        #expect(event.properties["direction"] == .string("save"))
        #expect(event.properties["input"] == .string("gesture"))
        #expect(FeatureFlag(rawValue: "reveal_swipe") == .revealSwipe)
    }
}
