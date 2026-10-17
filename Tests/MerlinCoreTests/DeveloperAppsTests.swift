import XCTest
@testable import MerlinCore

final class DeveloperAppsTests: XCTestCase {
    func testPadBridgeIsListed() {
        let pad = DeveloperApps.all.first { $0.id == "padbridge" }
        XCTAssertEqual(pad?.name, "PadBridge")
        XCTAssertEqual(pad?.url.scheme, "https")
        XCTAssertEqual(pad?.iconName, "PadBridge")
        XCTAssertFalse(pad?.summary.isEmpty ?? true)
    }

    func testIdsAndNamesAreUnique() {
        let ids = DeveloperApps.all.map(\.id)
        let names = DeveloperApps.all.map(\.name)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testUrlsUseHTTPS() {
        for app in DeveloperApps.all {
            XCTAssertEqual(app.url.scheme, "https", app.id)
            XCTAssertNotNil(app.url.host, app.id)
        }
    }
}
