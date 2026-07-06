import XCTest
@testable import PadelKit

final class DeviceOwnerNameTests: XCTestCase {

    func testEnglishGenitive() {
        XCTAssertEqual(DeviceOwnerName.parse(from: "Nicolaj's iPhone"), "Nicolaj")
        XCTAssertEqual(DeviceOwnerName.parse(from: "Nicolaj’s iPhone"), "Nicolaj")
        XCTAssertEqual(DeviceOwnerName.parse(from: "Nicolaj’s iPad"), "Nicolaj")
    }

    func testDanishGenitiveDropsTheBareS() {
        XCTAssertEqual(DeviceOwnerName.parse(from: "Nicolajs iPhone"), "Nicolaj")
        XCTAssertEqual(DeviceOwnerName.parse(from: "Anne Maries iPhone"), "Anne Marie")
    }

    func testDanishApostropheGenitiveForNamesEndingInS() {
        XCTAssertEqual(DeviceOwnerName.parse(from: "Mads' iPhone"), "Mads")
        XCTAssertEqual(DeviceOwnerName.parse(from: "Mads’ iPad"), "Mads")
    }

    func testParenthesizedStyle() {
        XCTAssertEqual(DeviceOwnerName.parse(from: "iPhone (Nicolaj)"), "Nicolaj")
        XCTAssertEqual(DeviceOwnerName.parse(from: "iPad (Nicolaj)"), "Nicolaj")
    }

    func testGenericDeviceNamesYieldNothing() {
        XCTAssertNil(DeviceOwnerName.parse(from: "iPhone"))
        XCTAssertNil(DeviceOwnerName.parse(from: "iphone"))
        XCTAssertNil(DeviceOwnerName.parse(from: "iPad"))
        XCTAssertNil(DeviceOwnerName.parse(from: "iPhone 15 Pro"))
        XCTAssertNil(DeviceOwnerName.parse(from: ""))
        XCTAssertNil(DeviceOwnerName.parse(from: "   "))
    }

    func testFullyCustomNameIsUsedAsIs() {
        XCTAssertEqual(DeviceOwnerName.parse(from: "Nicolaj"), "Nicolaj")
    }
}
