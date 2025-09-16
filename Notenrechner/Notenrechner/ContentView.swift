import SwiftUI
import Foundation

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

    private let gradeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("Modus") {
                    Picker("Modus", selection: $mode) {
                        ForEach(GradeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { newMode in
                        noteText = ""
                        verbalText = ""
                        if newMode == .ihk {
                            maxPointsText = ""
                        }
                    }
                }

                Section("Punkte") {
                    TextField("Erreichte Punkte", text: $pointsText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .points)
                        .onChange(of: pointsText) { newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue {
                                pointsText = filtered
                            }
                        }
                        .accessibilityLabel("Erreichte Punkte")

                    if mode == .normal {
                        TextField("Maximale Punkte", text: $maxPointsText)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .maxPoints)
                            .onChange(of: maxPointsText) { newValue in
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered != newValue {
                                    maxPointsText = filtered
                                }
                            }
                            .accessibilityLabel("Maximale Punkte")
                    }
                }

                Section {
                    Button("Berechnen", action: calculate)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .disabled(!inputsValid)
                }

                if !noteText.isEmpty {
                    Section("Ergebnis") {
                        LabeledContent("Note") {
                            Text(noteText)
                                .font(.title3)
                                .bold()
                        }

                        LabeledContent("Modus") {
                            Text(mode.title)
                        }

                        if let percentageText = percentageSummary() {
                            LabeledContent("Punkte") {
                                Text(percentageText)
                            }
                        }

                        if !verbalText.isEmpty {
                            LabeledContent("Bewertung") {
                                Text(verbalText.capitalized(with: Locale(identifier: "de_DE")))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(badgeColor(for: verbalText).opacity(0.12))
                                    )
                                    .foregroundStyle(badgeColor(for: verbalText))
                            }
                        }
                    }
                }

                if !history.isEmpty {
                    Section("Verlauf") {
                        ForEach(history.sorted(by: { $0.timestamp > $1.timestamp })) { entry in
                            HistoryRow(entry: entry)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        remove(entry)
                                    } label: {
                                        Label("Entfernen", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Notenrechner")
            .toolbar {
                if !history.isEmpty {
                    Button {
                        showClearAlert = true
                    } label: {
                        Label("Verlauf löschen", systemImage: "trash")
                    }
                }
            }
            .alert("Verlauf löschen?", isPresented: $showClearAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Ja", role: .destructive) {
                    history.removeAll()
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
        case "sehr gut": return Color.green
        case "gut": return Color.teal
        case "befriedigend": return Color.orange
        case "ausreichend": return Color.yellow
        case "mangelhaft": return Color.red
        case "ungenügend": return Color.red.opacity(0.8)
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
