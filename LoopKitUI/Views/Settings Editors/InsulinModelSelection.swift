//
//  InsulinModelSelection.swift
//  Loop
//
//  Created by Michael Pangburn on 7/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import SwiftUI
import LoopKit

public struct InsulinModelSelection: View {
    @EnvironmentObject private var displayGlucosePreference: DisplayGlucosePreference
    @Environment(\.appName) private var appName   
    @Environment(\.dismissAction) private var dismiss
    @Environment(\.authenticate) private var authenticate

    @State private var value: ExponentialInsulinModelPreset
    @State private var chartManager: ChartsManager
    @State private var afrezzaPotencyFactor: Double?

    private let initialValue: ExponentialInsulinModelPreset
    private let initialAfrezzaPotencyFactor: Double?
    private let insulinSensitivitySchedule: InsulinSensitivitySchedule
    private let mode: SettingsPresentationMode
    private let showsModelSelection: Bool
    private let save: (_ insulinModelPreset: ExponentialInsulinModelPreset, _ afrezzaPotencyFactor: Double?) -> Void

    static let defaultInsulinSensitivitySchedule = InsulinSensitivitySchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue<Double>(startTime: 0, value: 40)])!
    
    private var displayGlucoseUnit: HKUnit {
        displayGlucosePreference.unit
    }
    
    public init(
        value: ExponentialInsulinModelPreset,
        insulinSensitivitySchedule: InsulinSensitivitySchedule?,
        chartColors: ChartColorPalette,
        onSave save: @escaping (_ insulinModelPreset: ExponentialInsulinModelPreset) -> Void,
        mode: SettingsPresentationMode
    ){
        self.init(value: value, afrezzaPotencyFactor: nil, insulinSensitivitySchedule: insulinSensitivitySchedule, chartColors: chartColors,
                  onSave: { preset, _ in save(preset) }, mode: mode)
    }

    /// With a non-nil `afrezzaPotencyFactor`, also edits the Afrezza potency factor and saves it with the model. (custom)
    public init(
        value: ExponentialInsulinModelPreset,
        afrezzaPotencyFactor: Double?,
        insulinSensitivitySchedule: InsulinSensitivitySchedule?,
        chartColors: ChartColorPalette,
        onSave save: @escaping (_ insulinModelPreset: ExponentialInsulinModelPreset, _ afrezzaPotencyFactor: Double?) -> Void,
        mode: SettingsPresentationMode,
        showsModelSelection: Bool = true
    ){
        self.showsModelSelection = showsModelSelection
        self._value = State(initialValue: value)
        self.initialValue = value
        self._afrezzaPotencyFactor = State(initialValue: afrezzaPotencyFactor)
        self.initialAfrezzaPotencyFactor = afrezzaPotencyFactor
        self.insulinSensitivitySchedule = insulinSensitivitySchedule ?? Self.defaultInsulinSensitivitySchedule
        self.save = save
        self.mode = mode

        let chartManager = ChartsManager(
            colors: chartColors,
            settings: .default,
            axisLabelFont: .systemFont(ofSize: 12),
            charts: [InsulinModelChart()],
            traitCollection: .current
        )

        chartManager.startDate = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(minute: 0),
            matchingPolicy: .strict,
            direction: .backward
        ) ?? Date()
        self._chartManager = State(initialValue: chartManager)
    }

    public init(
        mode: SettingsPresentationMode,
        therapySettingsViewModel: TherapySettingsViewModel,
        chartColors: ChartColorPalette,
        didSave: (() -> Void)? = nil
    ) {
        self.init(
            value: therapySettingsViewModel.therapySettings.defaultRapidActingModel ?? .rapidActingAdult,
            afrezzaPotencyFactor: therapySettingsViewModel.therapySettings.afrezzaPotencyFactor ?? InsulinType.defaultAfrezzaPotencyFactor,
            insulinSensitivitySchedule: therapySettingsViewModel.therapySettings.insulinSensitivitySchedule,
            chartColors: chartColors,
            onSave: { [weak therapySettingsViewModel] insulinModelPreset, afrezzaPotencyFactor in
                if let afrezzaPotencyFactor {
                    // Without model selection only the factor is saved; the model stays as it was
                    let selectable = therapySettingsViewModel?.adultChildInsulinModelSelectionEnabled == true
                    therapySettingsViewModel?.saveInsulinModel(insulinModelPreset: selectable ? insulinModelPreset : nil, afrezzaPotencyFactor: afrezzaPotencyFactor)
                } else {
                    therapySettingsViewModel?.saveInsulinModel(insulinModelPreset: insulinModelPreset)
                }
                didSave?()
            },
            mode: mode,
            showsModelSelection: therapySettingsViewModel.adultChildInsulinModelSelectionEnabled
        )
    }

    public var body: some View {
        switch mode {
        case .acceptanceFlow:
            content
        case .settings:
            contentWithCancel
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var contentWithCancel: some View {
        content
            .navigationBarBackButtonHidden(hasChanges)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    leadingNavigationBarItem
                }
            }
    }

    @ViewBuilder
    private var leadingNavigationBarItem: some View {
        if hasChanges {
            cancelButton
        } else {
            EmptyView()
        }
    }
    
    private var cancelButton: some View {
        Button(action: { dismiss() } ) { Text(LocalizedString("Cancel", comment: "Cancel editing settings button title")) }
    }
    
    private var content: some View {
        VStack(spacing: 0) {
            CardList(title: Text(LocalizedString("Insulin Model", comment: "Title text for insulin model")),
                     style: .simple(CardStack(cards: showsModelSelection ? [card, afrezzaCard] : [afrezzaCard])))
            Button(action: { startSaving() }) {
                Text(mode.buttonText())
                    .actionButtonStyle(.primary)
                    .padding()
            }
            .disabled(!hasChanges && mode != .acceptanceFlow)
            // Styling to mimic the floating button of a ConfigurationPage
            .padding(.bottom)
            .background(Color(.secondarySystemGroupedBackground).shadow(radius: 5))
        }
        .supportedInterfaceOrientations(.portrait)
        .edgesIgnoringSafeArea(.bottom)
    }
    
    private var card: Card {
        Card {
            Section {
                SettingDescription(
                    text: insulinModelSettingDescription,
                    informationalContent: {
                        TherapySetting.insulinModel.helpScreen()
                    }
                )
                .padding(4)
                .padding(.top, 4)

                VStack {
                    InsulinModelChartView(
                        chartManager: chartManager,
                        glucoseUnit: displayGlucoseUnit,
                        selectedInsulinModelValues: selectedInsulinModelValues,
                        unselectedInsulinModelValues: unselectedInsulinModelValues,
                        glucoseDisplayRange: endingGlucoseQuantity...startingGlucoseQuantity
                    )
                    .frame(height: 170)

                    CheckmarkListItem(
                        title: Text(ExponentialInsulinModelPreset.rapidActingAdult.title),
                        description: Text(ExponentialInsulinModelPreset.rapidActingAdult.subtitle),
                        isSelected: isSelected(ExponentialInsulinModelPreset.rapidActingAdult)
                    )
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }

                SectionDivider()
                CheckmarkListItem(
                    title: Text(ExponentialInsulinModelPreset.rapidActingChild.title),
                    description: Text(ExponentialInsulinModelPreset.rapidActingChild.subtitle),
                    isSelected: isSelected(ExponentialInsulinModelPreset.rapidActingChild)
                )
                .padding(.vertical, 4)
                .padding(.bottom, 4)
            }
            .buttonStyle(PlainButtonStyle()) // Disable row highlighting on selection
        }
    }

    private var hasChanges: Bool {
        value != initialValue || afrezzaPotencyFactor != initialAfrezzaPotencyFactor
    }

    // MARK: - Afrezza potency (custom)

    /// Shown only when editing the factor; the stepper keeps it on 0.05 steps within the allowed range.
    private var afrezzaCard: Card? {
        guard let factor = afrezzaPotencyFactor else { return nil }
        let cartridge = 4.0
        return Card {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedString("Afrezza (inhaled insulin)", comment: "Title for the Afrezza potency setting"))
                        .font(.headline)
                    Text(LocalizedString("How much of each logged Afrezza unit counts as injected insulin, for active insulin and the forecast. History and Nightscout keep the units actually taken.", comment: "Description of the Afrezza potency setting"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Stepper(
                        value: Binding(
                            get: { factor },
                            set: { afrezzaPotencyFactor = (min(max($0, InsulinType.afrezzaPotencyFactorRange.lowerBound), InsulinType.afrezzaPotencyFactorRange.upperBound) * 20).rounded() / 20 }
                        ),
                        in: InsulinType.afrezzaPotencyFactorRange,
                        step: 0.05
                    ) {
                        Text(String(format: LocalizedString("%1$@U counts as %2$@U", comment: "Afrezza potency: units logged and units counted (1: cartridge units, 2: counted units)"),
                                    Self.unitsFormatter.string(from: cartridge as NSNumber) ?? "", Self.unitsFormatter.string(from: cartridge * factor as NSNumber) ?? ""))
                            .font(.body.bold())
                    }
                    Text(String(format: LocalizedString("Factor %@", comment: "Afrezza potency factor value (1: factor)"), Self.factorFormatter.string(from: factor as NSNumber) ?? ""))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(4)
            }
        }
    }

    private static let unitsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let factorFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    var insulinModelSettingDescription: Text {
        let spellOutFormatter = NumberFormatter()
        spellOutFormatter.numberStyle = .spellOut
        let modelCountString = spellOutFormatter.string(from: selectableInsulinModelSettings.count as NSNumber)!
        return Text(String(format: LocalizedString("For fast acting insulin, %1$@ assumes it is actively working for 6 hours. You can choose from %2$@ different models for how the app measures the insulin’s peak activity.", comment: "Insulin model setting description (1: app name) (2: number of models)"), appName, modelCountString))
    }

    var selectableInsulinModelSettings: [ExponentialInsulinModelPreset] {
        return [
            .rapidActingAdult,
            .rapidActingChild
        ]
    }

    private var selectedInsulinModelValues: [GlucoseValue] {
        oneUnitBolusEffectPrediction(using: value)
    }

    private var unselectedInsulinModelValues: [[GlucoseValue]] {
        selectableInsulinModelSettings
            .filter { $0 != value }
            .map { oneUnitBolusEffectPrediction(using: $0) }
    }
    
    private func oneUnitBolusEffectPrediction(using modelPreset: ExponentialInsulinModelPreset) -> [GlucoseValue] {
        let bolus = DoseEntry(type: .bolus, startDate: chartManager.startDate, value: 1, unit: .units, insulinType: .novolog)
        let startingGlucoseSample = HKQuantitySample(type: HealthKitSampleStore.glucoseType, quantity: startingGlucoseQuantity, start: chartManager.startDate, end: chartManager.startDate)
        let effects = [bolus].glucoseEffects(insulinModelProvider: StaticInsulinModelProvider(modelPreset), longestEffectDuration: .hours(6), insulinSensitivity: insulinSensitivitySchedule)
        return LoopMath.predictGlucose(startingAt: startingGlucoseSample, effects: effects)
    }

    private var startingGlucoseQuantity: HKQuantity {
        let startingGlucoseValue = insulinSensitivitySchedule.quantity(at: chartManager.startDate).doubleValue(for: displayGlucoseUnit) + displayGlucoseUnit.glucoseExampleTargetValue
        return HKQuantity(unit: displayGlucoseUnit, doubleValue: startingGlucoseValue)
    }

    private var endingGlucoseQuantity: HKQuantity {
        HKQuantity(unit: displayGlucoseUnit, doubleValue: displayGlucoseUnit.glucoseExampleTargetValue)
    }

    private func isSelected(_ preset: ExponentialInsulinModelPreset) -> Binding<Bool> {
        Binding(
            get: { value == preset },
            set: { isSelected in
                if isSelected {
                    withAnimation {
                        value = preset
                    }
                }
            }
        )
    }

    private func startSaving() {
        guard mode == .settings else {
            continueSaving()
            return
        }
        authenticate(TherapySetting.insulinModel.authenticationChallengeDescription) {
            switch $0 {
            case .success: continueSaving()
            case .failure: break
            }
        }
    }
    
    private func continueSaving() {
        save(value, afrezzaPotencyFactor)
    }

    var dismissButton: some View {
        Button(action: dismiss) {
            Text(LocalizedString("Close", comment: "Button text to close a modal"))
        }
    }
}

fileprivate extension HKUnit {
    /// An example value for the "ideal" target
    var glucoseExampleTargetValue: Double {
        if self == .milligramsPerDeciliter {
            return 100
        } else {
            return 5.5
        }
    }
}

fileprivate struct SectionDivider: View {
    var body: some View {
        Divider()
            .padding(.trailing, -16)
    }
}
