//
//  DoseEntryTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 5/4/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit

@testable import LoopKit

class DoseEntryCodableTests: XCTestCase {
    func testCodable() throws {
        try assertDoseEntryCodable(DoseEntry(type: .bolus,
                                             startDate: dateFormatter.date(from: "2020-05-14T22:07:19Z")!,
                                             value: 2.5,
                                             unit: .units),
        encodesJSON: """
{
  "endDate" : "2020-05-14T22:07:19Z",
  "startDate" : "2020-05-14T22:07:19Z",
  "type" : "bolus",
  "unit" : "U",
  "value" : 2.5
}
"""
        )
    }

    func testCodableOptional() throws {
        try assertDoseEntryCodable(DoseEntry(type: .tempBasal,
                                             startDate: dateFormatter.date(from: "2020-05-14T22:07:19Z")!,
                                             endDate: dateFormatter.date(from: "2020-05-14T22:37:19Z")!,
                                             value: 1.25,
                                             unit: .unitsPerHour,
                                             deliveredUnits: 0.5,
                                             description: "Temporary Basal",
                                             syncIdentifier: "238E41EA-9576-4981-A1A4-51E10228584F",
                                             scheduledBasalRate: HKQuantity(unit: DoseEntry.unitsPerHour, doubleValue: 1.5),
                                             insulinType: .fiasp,
                                             automatic: true,
                                             manuallyEntered: true,
                                             isMutable: true,
                                             wasProgrammedByPumpUI: true),
                                   encodesJSON: """
{
  "automatic" : true,
  "deliveredUnits" : 0.5,
  "description" : "Temporary Basal",
  "endDate" : "2020-05-14T22:37:19Z",
  "insulinType" : 3,
  "isMutable" : true,
  "manuallyEntered" : true,
  "scheduledBasalRate" : 1.5,
  "scheduledBasalRateUnit" : "IU/hr",
  "startDate" : "2020-05-14T22:07:19Z",
  "syncIdentifier" : "238E41EA-9576-4981-A1A4-51E10228584F",
  "type" : "tempBasal",
  "unit" : "U/hour",
  "value" : 1.25,
  "wasProgrammedByPumpUI" : true
}
"""
        )
    }
    
    private func assertDoseEntryCodable(_ original: DoseEntry, encodesJSON string: String) throws {
        let data = try encoder.encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(DoseEntry.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    private let dateFormatter = ISO8601DateFormatter()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

class DoseEntryRawRepresentableTests: XCTestCase {
    func testDoseEntryRawRepresentable() {
        let original = DoseEntry(type: .bolus,
                                 startDate: Date(),
                                 value: 2.5,
                                 unit: .units)
        let actual = DoseEntry(rawValue: original.rawValue)
        XCTAssertEqual(actual, original)
    }

    func testDoseEntryRawRepresentableOptional() {
        let original = DoseEntry(type: .tempBasal,
                                 startDate: Date(),
                                 endDate: Date().addingTimeInterval(.minutes(30)),
                                 value: 1.25,
                                 unit: .unitsPerHour,
                                 deliveredUnits: 0.5,
                                 description: "Temporary Basal",
                                 syncIdentifier: UUID().uuidString,
                                 scheduledBasalRate: HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 1.5),
                                 insulinType: .fiasp,
                                 automatic: true,
                                 manuallyEntered: true,
                                 isMutable: true,
                                 wasProgrammedByPumpUI: true)
        let actual = DoseEntry(rawValue: original.rawValue)
        XCTAssertEqual(actual, original)
    }
}

// MARK: - Insulin type potency (custom)

class DoseEntryPotencyTests: XCTestCase {
    override func tearDown() {
        InsulinType.afrezzaPotencyFactor = InsulinType.defaultAfrezzaPotencyFactor
        super.tearDown()
    }

    func testAfrezzaPotencyFactorIsSettable() {
        InsulinType.afrezzaPotencyFactor = 0.2
        XCTAssertEqual(InsulinType.afrezza.potencyFactor, 0.2)
        XCTAssertEqual(InsulinType.novolog.potencyFactor, 1)
        let dose = DoseEntry(type: .bolus, startDate: Date(), value: 4, unit: .units, insulinType: .afrezza, manuallyEntered: true)
        XCTAssertEqual(dose.netBasalUnits, 0.8, accuracy: 0.0001)
        XCTAssertEqual(dose.programmedUnits, 4, "still recorded as the cartridge size")
    }

    func testAfrezzaPotencyFactorIsClampedToRange() {
        InsulinType.afrezzaPotencyFactor = 1.5
        XCTAssertEqual(InsulinType.afrezzaPotencyFactor, 1)
        InsulinType.afrezzaPotencyFactor = -0.1
        XCTAssertEqual(InsulinType.afrezzaPotencyFactor, 0)
    }

    func testPotencyFactorIsOneExceptAfrezza() {
        for type in InsulinType.allCases where type != .afrezza {
            XCTAssertEqual(type.potencyFactor, 1, "\(type) must not be scaled")
        }
        XCTAssertEqual(InsulinType.afrezza.potencyFactor, 0.5)
    }

    func testBolusWithoutInsulinTypeIsUnscaled() {
        let dose = DoseEntry(type: .bolus, startDate: Date(), value: 4, unit: .units)
        XCTAssertEqual(dose.netBasalUnits, 4)
    }

    func testRapidActingBolusIsUnscaled() {
        let dose = DoseEntry(type: .bolus, startDate: Date(), value: 4, unit: .units, insulinType: .novolog)
        XCTAssertEqual(dose.netBasalUnits, 4)
    }

    func testDeliveredUnitsStillWinForUnscaledTypes() {
        let dose = DoseEntry(type: .bolus, startDate: Date(), value: 4, unit: .units, deliveredUnits: 3.2, insulinType: .humalog)
        XCTAssertEqual(dose.netBasalUnits, 3.2)
    }

    func testAfrezzaCartridgeRecordedAsFourCountsAsTwo() {
        let dose = DoseEntry(type: .bolus, startDate: Date(), value: 4, unit: .units, insulinType: .afrezza, manuallyEntered: true)
        XCTAssertEqual(dose.programmedUnits, 4, "recorded as the cartridge size")
        XCTAssertEqual(dose.unitsInDeliverableIncrements, 4, "stored as the cartridge size")
        XCTAssertEqual(dose.netBasalUnits, 2, "counted as the injected equivalent")
    }

    func testAfrezzaInsulinOnBoardAndEffectUseScaledUnits() {
        let start = Date()
        let dose = DoseEntry(type: .bolus, startDate: start, value: 4, unit: .units, insulinType: .afrezza, manuallyEntered: true)
        let model = ExponentialInsulinModelPreset.afrezza

        XCTAssertEqual(dose.insulinOnBoard(at: start, model: model, delta: .minutes(5)), 2, accuracy: 0.0001)
        let fullEffect = dose.glucoseEffect(at: start.addingTimeInterval(model.effectDuration), model: model, insulinSensitivity: 50, delta: .minutes(5))
        XCTAssertEqual(fullEffect, -100, accuracy: 0.0001, "4U Afrezza at ISF 50 lowers like 2U: -100 mg/dL")
    }
}
