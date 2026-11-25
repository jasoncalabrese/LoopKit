//
//  InsulinType.swift
//  LoopKit
//
//  Created by Anna Quinlan on 12/8/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public enum InsulinType: Int, Codable, CaseIterable {
    case novolog
    case humalog
    case apidra
    case fiasp
    case lyumjev
    case afrezza
    
    public var title: String {
        switch self {
        case .novolog:
            return LocalizedString("Novolog (insulin aspart)", comment: "Title for Novolog insulin type")
        case .humalog:
            return LocalizedString("Humalog (insulin lispro)", comment: "Title for Humalog insulin type")
        case .apidra:
            return LocalizedString("Apidra (insulin glulisine)", comment: "Title for Apidra insulin type")
        case .fiasp:
            return LocalizedString("Fiasp", comment: "Title for Fiasp insulin type")
        case .lyumjev:
            return LocalizedString("Lyumjev", comment: "Title for Lyumjev insulin type")
        case .afrezza:
            return LocalizedString("Afrezza", comment: "Title for Afrezza insulin type")
        }
    }
    
    public var brandName: String {
        switch self {
        case .novolog:
            return LocalizedString("Novolog", comment: "Brand name for novolog insulin type")
        case .humalog:
            return LocalizedString("Humalog", comment: "Brand name for humalog insulin type")
        case .apidra:
            return LocalizedString("Apidra", comment: "Brand name for apidra insulin type")
        case .fiasp:
            return LocalizedString("Fiasp", comment: "Brand name for fiasp insulin type")
        case .lyumjev:
            return LocalizedString("Lyumjev", comment: "Brand name for lyumjev insulin type")
        case .afrezza:
            return LocalizedString("Afrezza", comment: "Brand name for afrezza insulin type")
        }
    }
    
    public var description: String {
        switch self {
        case .novolog:
            return LocalizedString("NovoLog (insulin aspart) is a rapid-acting insulin made by Novo Nordisk", comment: "Description for novolog insulin type")
        case .humalog:
            return LocalizedString("Humalog (insulin lispro) is a rapid-acting insulin made by Eli Lilly", comment: "Description for humalog insulin type")
        case .apidra:
            return LocalizedString("Apidra (insulin glulisine) is a rapid-acting insulin made by Sanofi-aventis", comment: "Description for apidra insulin type")
        case .fiasp:
            return LocalizedString("Fiasp is a mealtime insulin aspart formulation with the addition of nicotinamide (vitamin B3) made by Novo Nordisk", comment: "Description for fiasp insulin type")
        case .lyumjev:
            return LocalizedString("Lyumjev is a mealtime insulin lispro formulation with the addition of citrate and treprostinil made by Eli Lilly", comment: "Description for lyumjev insulin type")
        case .afrezza:
            return LocalizedString("Afrezza is an ultra rapid-acting mealtime insulin that is breathed in through your lungs using an oral inhaler and made by MannKind", comment: "Description for afrezza insulin type")
        }
    }
    
    public var pumpAdministerable: Bool {
        switch self {
        case .afrezza:
            return false
        default:
            return true
        }
    }

    /// Glucose-lowering effect per logged unit, relative to rapid-acting injected insulin. (custom)
    ///
    /// Lets a dose be recorded as what was actually taken (a 4U Afrezza cartridge) while
    /// insulin on board and glucose effects count its injected equivalent.
    /// The insulin model only shapes the curve over time; this sets how much it adds up to.
    public var potencyFactor: Double {
        switch self {
        case .afrezza:
            return InsulinType.afrezzaPotencyFactor
        default:
            return 1
        }
    }

    /// Default and allowed range for the user-set Afrezza potency factor (custom)
    public static let defaultAfrezzaPotencyFactor = 0.5
    public static let afrezzaPotencyFactorRange: ClosedRange<Double> = 0...1

    /// The Afrezza potency factor in effect, app-wide. Set from therapy settings; clamped to the range. (custom)
    public static var afrezzaPotencyFactor: Double {
        get { lockedAfrezzaPotencyFactor.value }
        set { lockedAfrezzaPotencyFactor.value = min(max(newValue, afrezzaPotencyFactorRange.lowerBound), afrezzaPotencyFactorRange.upperBound) }
    }
    private static let lockedAfrezzaPotencyFactor = Locked(defaultAfrezzaPotencyFactor)
}
