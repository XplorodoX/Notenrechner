import SwiftUI
import Foundation

#if os(iOS)
import UIKit
#endif

enum InputField: Hashable {
    case points
    case maxPoints
}

struct ContentView: View {
    @State private var pointsText = ""
    @State private var maxPointsText = ""
    @State private var mode: GradeMode = .ihk
    @State private var noteText = ""
    @State private var verbalText = ""
    @State private var history: [HistoryEntry] = []
    @State private var showClearAlert = false
    @FocusState private var focusedField: InputField?
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private var isCompact: Bool {
        horizontalSizeClass == .compact || verticalSizeClass == .compact
    }
    
    private var isLandscape: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .compact
    }

    private let gradeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if isLandscape && geometry.size.width > 768 {
                    // iPad/Mac Landscape Layout
                    HStack(spacing: 0) {
                        // Left Panel - Input
                        VStack(spacing: 24) {
                            HeaderView(isCompact: false)
                            ModeSelectionView(mode: $mode, isCompact: false) {
                                handleModeChange()
                            }
                            InputSectionView(
                                mode: mode,
                                pointsText: $pointsText,
                                maxPointsText: $maxPointsText,
                                focusedField: $focusedField,
                                isCompact: false
                            )
                            CalculateButtonView(
                                inputsValid: inputsValid,
                                isCompact: false,
                                action: calculate
                            )
                            Spacer()
                        }
                        .padding()
                        .frame(maxWidth: 400)
                        .background(.regularMaterial)
                        
                        // Right Panel - Results & History
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                if !noteText.isEmpty {
                                    ResultCard(
                                        noteText: noteText,
                                        mode: mode,
                                        verbalText: verbalText,
                                        percentageText: percentageSummary(),
                                        isCompact: false
                                    )
                                }
                                
                                if !history.isEmpty {
                                    HistorySection(
                                        history: history,
                                        onRemove: remove,
                                        onClearAll: { showClearAlert = true },
                                        isCompact: false
                                    )
                                }
                            }
                            .padding()
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    // iPhone/Compact Layout
                    ScrollView {
                        LazyVStack(spacing: isCompact ? 16 : 20) {
                            HeaderView(isCompact: isCompact)
                            
                            ModeSelectionView(mode: $mode, isCompact: isCompact) {
                                handleModeChange()
                            }
                            
                            InputSectionView(
                                mode: mode,
                                pointsText: $pointsText,
                                maxPointsText: $maxPointsText,
                                focusedField: $focusedField,
                                isCompact: isCompact
                            )
                            
                            CalculateButtonView(
                                inputsValid: inputsValid,
                                isCompact: isCompact,
                                action: calculate
                            )
                            
                            if !noteText.isEmpty {
                                ResultCard(
                                    noteText: noteText,
                                    mode: mode,
                                    verbalText: verbalText,
                                    percentageText: percentageSummary(),
                                    isCompact: isCompact
                                )
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .bottom).combined(with: .opacity)
                                ))
                            }
                            
                            if !history.isEmpty {
                                HistorySection(
                                    history: history,
                                    onRemove: remove,
                                    onClearAll: { showClearAlert = true },
                                    isCompact: isCompact
                                )
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .bottom).combined(with: .opacity)
                                ))
                            }
                        }
                        .padding(.horizontal, isCompact ? 16 : 20)
                        .animation(.easeInOut, value: mode)
                        .animation(.easeInOut, value: noteText.isEmpty)
                        .animation(.easeInOut, value: history.isEmpty)
                    }
                }
            }
            .background(.regularMaterial)
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
            #if os(macOS)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if !history.isEmpty {
                        Button("Verlauf löschen") {
                            showClearAlert = true
                        }
                        .keyboardShortcut("k", modifiers: [.command, .shift])
                    }
                    
                    Button("Berechnen") {
                        calculate()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!inputsValid)
                }
            }
            #endif
            .alert("Verlauf löschen?", isPresented: $showClearAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Ja", role: .destructive) {
                    withAnimation(.easeInOut) {
                        history.removeAll()
                    }
                }
            } message: {
                Text("Möchtest du wirklich alle Einträge löschen?")
            }
        }
    }

    private var inputsValid: Bool {
        guard let points = Int(pointsText) else { return false }
        switch mode {
        case .ihk:
            return (0...100).contains(points)
        case .normal:
            guard let maxPoints = Int(maxPointsText), maxPoints > 0 else { return false }
            return points >= 0 && points <= maxPoints
        }
    }

    private func calculate() {
        focusedField = nil
        
        // Platform-specific haptic feedback
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        #endif
        
        guard let points = Int(pointsText) else { return }

        switch mode {
        case .ihk:
            if points < 0 || points > 100 {
                noteText = "IHK: Punkte müssen zwischen 0 und 100 liegen."
                verbalText = ""
                return
            }
            let grade = GradeCalculator.calculateIHK(points: points)
            verbalText = GradeCalculator.verbalAssessment(for: grade)
            noteText = formattedGrade(grade)
            appendHistory(points: points, maxPoints: 100, grade: grade)
        case .normal:
            guard let maxPoints = Int(maxPointsText), maxPoints > 0 else {
                noteText = "Bitte gültige Werte eingeben (Punkte und maximale Punkte > 0)."
                verbalText = ""
                return
            }
            if points < 0 || points > maxPoints {
                noteText = "Punkte müssen zwischen 0 und \(maxPoints) liegen."
                verbalText = ""
                return
            }
            let grade = GradeCalculator.calculateNormal(points: points, maxPoints: maxPoints)
            verbalText = GradeCalculator.verbalAssessment(for: grade)
            noteText = formattedGrade(grade)
            appendHistory(points: points, maxPoints: maxPoints, grade: grade)
        }
    }
    
    private func handleModeChange() {
        withAnimation(.easeInOut) {
            noteText = ""
            verbalText = ""
            if mode == .ihk {
                maxPointsText = ""
            }
        }
    }

    private func appendHistory(points: Int, maxPoints: Int, grade: Double) {
        let entry = HistoryEntry(mode: mode,
                                 points: points,
                                 maxPoints: maxPoints,
                                 grade: grade,
                                 verbalAssessment: verbalText,
                                 timestamp: Date())
        history.append(entry)
        if history.count > 50 {
            history.removeFirst(history.count - 50)
        }
    }

    private func remove(_ entry: HistoryEntry) {
        history.removeAll { $0.id == entry.id }
    }

    private func formattedGrade(_ grade: Double) -> String {
        if let formatted = gradeFormatter.string(from: NSNumber(value: grade)) {
            return formatted
        }
        return String(format: "%.1f", locale: Locale(identifier: "de_DE"), grade)
    }

    private func percentageSummary() -> String? {
        guard let points = Int(pointsText) else { return nil }
        switch mode {
        case .ihk:
            let percent = Double(points)
            return "\(points)/100 = " + String(format: "%.1f%%", locale: Locale(identifier: "de_DE"), percent)
        case .normal:
            guard let maxPoints = Int(maxPointsText), maxPoints > 0 else { return nil }
            let percent = (Double(points) * 100.0) / Double(maxPoints)
            return "\(points)/\(maxPoints) = " + String(format: "%.1f%%", locale: Locale(identifier: "de_DE"), percent)
        }
    }

    private func badgeColor(for verbal: String) -> Color {
        switch verbal.lowercased() {
        case "sehr gut": return Color(.systemGreen)
        case "gut": return Color(.systemTeal)
        case "befriedigend": return Color(.systemOrange)
        case "ausreichend": return Color(.systemYellow)
        case "mangelhaft": return Color(.systemRed)
        case "ungenügend": return Color(.systemRed)
        default: return Color.accentColor
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    let isCompact: Bool
    
    var body: some View {
        VStack(spacing: isCompact ? 6 : 8) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: isCompact ? 40 : 50))
                .foregroundStyle(.tint)
            
            Text("Notenrechner")
                .font(isCompact ? .title.bold() : .largeTitle.bold())
                .foregroundStyle(.primary)
        }
        .padding(.top, isCompact ? 8 : 16)
    }
}

// MARK: - Mode Selection View
struct ModeSelectionView: View {
    @Binding var mode: GradeMode
    let isCompact: Bool
    let onChange: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 10 : 12) {
            Label("Modus auswählen", systemImage: "switch.2")
                .font(isCompact ? .subheadline : .headline)
                .foregroundStyle(.secondary)
            
            Picker("Modus", selection: $mode) {
                ForEach(GradeMode.allCases) { gradeMode in
                    Label(gradeMode.title, systemImage: gradeMode.iconName).tag(gradeMode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _ in onChange() }
        }
        .padding(isCompact ? 16 : 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Input Section View
struct InputSectionView: View {
    let mode: GradeMode
    @Binding var pointsText: String
    @Binding var maxPointsText: String
    @FocusState.Binding var focusedField: InputField?
    let isCompact: Bool
    
    var body: some View {
        VStack(spacing: isCompact ? 12 : 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Erreichte Punkte", systemImage: "number.circle.fill")
                    .font(isCompact ? .subheadline : .headline)
                    .foregroundStyle(.secondary)
                
                TextField("Punkte eingeben", text: $pointsText)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .focused($focusedField, equals: .points)
                    .onChange(of: pointsText) { newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            pointsText = filtered
                        }
                    }
                    #if os(macOS)
                    .onSubmit {
                        if mode == .normal {
                            focusedField = .maxPoints
                        } else {
                            focusedField = nil
                        }
                    }
                    #endif
                    .overlay(alignment: .trailing) {
                        if mode == .ihk {
                            Text("/ 100")
                                .foregroundStyle(.secondary)
                                .padding(.trailing, 8)
                        }
                    }
            }
            
            if mode == .normal {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Maximale Punkte", systemImage: "number.square.fill")
                        .font(isCompact ? .subheadline : .headline)
                        .foregroundStyle(.secondary)
                    
                    TextField("Maximum eingeben", text: $maxPointsText)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .focused($focusedField, equals: .maxPoints)
                        .onChange(of: maxPointsText) { newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue {
                                maxPointsText = filtered
                            }
                        }
                        #if os(macOS)
                        .onSubmit {
                            focusedField = nil
                        }
                        #endif
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
            }
        }
        .padding(isCompact ? 16 : 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Calculate Button View
struct CalculateButtonView: View {
    let inputsValid: Bool
    let isCompact: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "function")
                    .symbolEffect(.pulse, options: .repeating, value: inputsValid)
                Text("Note berechnen")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: isCompact ? 44 : 50)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(isCompact ? .regular : .large)
        .disabled(!inputsValid)
        .animation(.easeInOut, value: inputsValid)
        #if os(macOS)
        .keyboardShortcut(.return, modifiers: .command)
        #endif
    }
}

// MARK: - Result Card
struct ResultCard: View {
    let noteText: String
    let mode: GradeMode
    let verbalText: String
    let percentageText: String?
    let isCompact: Bool
    
    var body: some View {
        VStack(spacing: isCompact ? 12 : 16) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(isCompact ? .title3 : .title2)
                Text("Ergebnis")
                    .font(isCompact ? .subheadline : .headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            // Note Display
            VStack(spacing: 8) {
                Text("Note")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(noteText)
                    .font(.system(size: isCompact ? 36 : 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }
            
            // Details
            VStack(spacing: isCompact ? 8 : 12) {
                if !verbalText.isEmpty {
                    HStack {
                        Text("Bewertung")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(verbalText.capitalized(with: Locale(identifier: "de_DE")))
                            .padding(.horizontal, isCompact ? 8 : 12)
                            .padding(.vertical, isCompact ? 4 : 6)
                            .background(
                                Capsule()
                                    .fill(badgeColorFor(verbalText).opacity(0.15))
                            )
                            .foregroundStyle(badgeColorFor(verbalText))
                            .fontWeight(.medium)
                            .font(isCompact ? .caption : .subheadline)
                    }
                }
                
                HStack {
                    Text("Modus")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label(mode.title, systemImage: mode.iconName)
                        .foregroundStyle(.primary)
                        .font(isCompact ? .caption : .subheadline)
                }
                
                if let percentageText = percentageText {
                    HStack {
                        Text("Punkte")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(percentageText)
                            .foregroundStyle(.primary)
                            .fontWeight(.medium)
                            .font(isCompact ? .caption : .subheadline)
                    }
                }
            }
        }
        .padding(isCompact ? 16 : 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(badgeColorFor(verbalText).opacity(0.3), lineWidth: 1)
        )
    }
    
    private func badgeColorFor(_ verbal: String) -> Color {
        switch verbal.lowercased() {
        case "sehr gut": return Color(.systemGreen)
        case "gut": return Color(.systemTeal)
        case "befriedigend": return Color(.systemOrange)
        case "ausreichend": return Color(.systemYellow)
        case "mangelhaft": return Color(.systemRed)
        case "ungenügend": return Color(.systemRed)
        default: return Color.accentColor
        }
    }
}

// MARK: - History Section
struct HistorySection: View {
    let history: [HistoryEntry]
    let onRemove: (HistoryEntry) -> Void
    let onClearAll: () -> Void
    let isCompact: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 12 : 16) {
            HStack {
                Label("Verlauf", systemImage: "clock.fill")
                    .font(isCompact ? .subheadline : .headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(action: onClearAll) {
                    Label("Alle löschen", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            LazyVStack(spacing: isCompact ? 6 : 8) {
                ForEach(history.sorted(by: { $0.timestamp > $1.timestamp })) { entry in
                    HistoryRowModern(entry: entry, isCompact: isCompact)
                        .onTapGesture {
                            #if os(iOS)
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            #endif
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation(.easeInOut) {
                                    onRemove(entry)
                                }
                            } label: {
                                Label("Entfernen", systemImage: "trash")
                            }
                        }
                        #if os(macOS)
                        .contextMenu {
                            Button("Entfernen", role: .destructive) {
                                withAnimation(.easeInOut) {
                                    onRemove(entry)
                                }
                            }
                        }
                        #endif
                }
            }
        }
        .padding(isCompact ? 16 : 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Modern History Row
struct HistoryRowModern: View {
    let entry: HistoryEntry
    let isCompact: Bool

    private static let gradeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()

    var body: some View {
        HStack(spacing: isCompact ? 8 : 12) {
            // Mode Icon
            Image(systemName: entry.mode.iconName)
                .font(isCompact ? .subheadline : .title3)
                .foregroundStyle(entry.mode.accentColor)
                .frame(width: isCompact ? 20 : 24, height: isCompact ? 20 : 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(isCompact ? .subheadline : .headline)
                    .foregroundStyle(.primary)
                
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Grade Badge
            Text(gradeText)
                .font(isCompact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .padding(.horizontal, isCompact ? 6 : 8)
                .padding(.vertical, isCompact ? 3 : 4)
                .background(
                    Capsule()
                        .fill(badgeColorFor(entry.verbalAssessment).opacity(0.15))
                )
                .foregroundStyle(badgeColorFor(entry.verbalAssessment))
        }
        .padding(isCompact ? 8 : 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var titleText: String {
        let verbal = entry.verbalAssessment.capitalized(with: Locale(identifier: "de_DE"))
        return "\(entry.mode.title) — \(verbal)"
    }

    private var detailText: String {
        let points = "\(entry.points)/\(entry.maxPoints ?? 100)"
        let dateText = Self.dateFormatter.string(from: entry.timestamp)
        return "Punkte: \(points) • \(dateText)"
    }
    
    private var gradeText: String {
        return Self.gradeFormatter.string(from: NSNumber(value: entry.grade)) ?? 
               String(format: "%.1f", locale: Locale(identifier: "de_DE"), entry.grade)
    }
    
    private func badgeColorFor(_ verbal: String) -> Color {
        switch verbal.lowercased() {
        case "sehr gut": return Color(.systemGreen)
        case "gut": return Color(.systemTeal)
        case "befriedigend": return Color(.systemOrange)
        case "ausreichend": return Color(.systemYellow)
        case "mangelhaft": return Color(.systemRed)
        case "ungenügend": return Color(.systemRed)
        default: return Color.accentColor
        }
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry

    private static let gradeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titleText)
                .font(.headline)
            Text(detailText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var titleText: String {
        let note = Self.gradeFormatter.string(from: NSNumber(value: entry.grade)) ?? String(format: "%.1f", locale: Locale(identifier: "de_DE"), entry.grade)
        let verbal = entry.verbalAssessment.capitalized(with: Locale(identifier: "de_DE"))
        return "\(entry.mode.title) • Note \(note) — \(verbal)"
    }

    private var detailText: String {
        let points = "\(entry.points)/\(entry.maxPoints ?? 100)"
        let dateText = Self.dateFormatter.string(from: entry.timestamp)
        return "Punkte: \(points) • \(dateText)"
    }
}
