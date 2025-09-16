import SwiftUI
import Foundation
#if os(macOS)
import AppKit
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

    private let gradeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    @ViewBuilder
    private var liquidBackground: some View {
        let gradient = LinearGradient(colors: [Color.blue.opacity(0.18), Color.purple.opacity(0.16), Color.cyan.opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ZStack {
#if os(iOS)
            Color(.systemBackground)
#elseif os(macOS)
            Color(nsColor: NSColor.windowBackgroundColor)
#else
            Color.gray.opacity(0.05)
#endif
            gradient
                .blur(radius: 120)
                .opacity(0.6)

            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 320, height: 320)
                .offset(x: -160, y: -120)
                .blur(radius: 80)

            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 280, height: 280)
                .offset(x: 220, y: -80)
                .blur(radius: 70)

            Circle()
                .fill(Color.indigo.opacity(0.18))
                .frame(width: 360, height: 360)
                .offset(x: 120, y: 280)
                .blur(radius: 90)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Notenrechner")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(
                            LinearGradient(colors: [Color.primary, Color.cyan.opacity(0.8), Color.purple.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Modus:")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Picker("Modus", selection: $mode) {
                            ForEach(GradeMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(6)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                .blendMode(.overlay)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
                        .onChange(of: mode) { newMode in
                            noteText = ""
                            verbalText = ""
                            if newMode == .ihk {
                                maxPointsText = ""
                            }
                        }
                    }

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Erreichte Punkte", text: $pointsText)
                                .platformTextFieldStyle()
                                .platformNumberPad()
                                .focused($focusedField, equals: .points)
                                .onChange(of: pointsText) { newValue in
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue {
                                        pointsText = filtered
                                    }
                                }
                                .glassField()
                            if mode == .ihk {
                                Text("0–100")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if mode == .normal {
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Maximale Punkte", text: $maxPointsText)
                                    .platformTextFieldStyle()
                                    .platformNumberPad()
                                    .focused($focusedField, equals: .maxPoints)
                                    .onChange(of: maxPointsText) { newValue in
                                        let filtered = newValue.filter { $0.isNumber }
                                        if filtered != newValue {
                                            maxPointsText = filtered
                                        }
                                    }
                                    .glassField()
                            }
                        }
                    }

                    Button("Berechnen", action: calculate)
                        .buttonStyle(GlassButtonStyle())
                        .disabled(!inputsValid)

                    if !noteText.isEmpty {
                        resultCard
                    }

                    if !history.isEmpty {
                        historySection
                    }
                }
                .padding(24)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Notenrechner")
            .toolbar {
                if !history.isEmpty {
                    Button {
                        showClearAlert = true
                    } label: {
                        Label("Verlauf löschen", systemImage: "trash")
                    }
#if os(macOS)
                    .keyboardShortcut(.delete, modifiers: [.command])
#endif
                    .tint(Color.red.opacity(0.85))
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
            .background(liquidBackground.ignoresSafeArea())
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

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ergebnis")
                .font(.title2)
                .foregroundStyle(.primary)
            Text("Modus: \(mode.title)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .center, spacing: 12) {
                Text("Note: \(noteText)")
                    .font(.title)
                    .foregroundStyle(.primary)
                if !verbalText.isEmpty {
                    let color = badgeColor(for: verbalText)
                    Text(verbalText.capitalized(with: Locale(identifier: "de_DE")))
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            color.opacity(0.12),
                            in: Capsule(style: .continuous)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(color.opacity(0.35), lineWidth: 1)
                        )
                        .foregroundStyle(color)
                }
            }

            if let percentageText = percentageSummary() {
                Text(percentageText)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if !verbalText.isEmpty {
                Text("Bewertung: \(verbalText.capitalized(with: Locale(identifier: "de_DE")))")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
    }

    private var historySection: some View {
        let entries = Array(history.reversed())
        return VStack(alignment: .leading, spacing: 12) {
            Text("Verlauf")
                .font(.title2)
                .foregroundStyle(.primary)
            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    HistoryRow(entry: entry) {
                        remove(entry)
                    }
                    if entry.id != entries.last?.id {
                        Divider()
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func appendHistory(points: Int, maxPoints: Int, grade: Double) {
        let verbal = verbalText
        let entry = HistoryEntry(mode: mode,
                                 points: points,
                                 maxPoints: maxPoints,
                                 grade: grade,
                                 verbalAssessment: verbal,
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
            let percentString = String(format: "%.1f%%", locale: Locale(identifier: "de_DE"), percent)
            return "\(points)/100 = \(percentString)"
        case .normal:
            guard let maxPoints = Int(maxPointsText), maxPoints > 0 else { return nil }
            let percent = (Double(points) * 100.0) / Double(maxPoints)
            let percentString = String(format: "%.1f%%", locale: Locale(identifier: "de_DE"), percent)
            return "\(points)/\(maxPoints) = \(percentString)"
        }
    }

    private func badgeColor(for verbal: String) -> Color {
        switch verbal.lowercased() {
        case "sehr gut": return Color(red: 0.18, green: 0.49, blue: 0.20)
        case "gut": return Color(red: 0.22, green: 0.56, blue: 0.24)
        case "befriedigend": return Color(red: 0.98, green: 0.66, blue: 0.14)
        case "ausreichend": return Color(red: 0.96, green: 0.49, blue: 0.00)
        case "mangelhaft": return Color(red: 0.83, green: 0.18, blue: 0.18)
        case "ungenügend": return Color(red: 0.72, green: 0.11, blue: 0.11)
        default: return Color.accentColor
        }
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry
    let onRemove: () -> Void

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
            HStack {
                let note = Self.gradeFormatter.string(from: NSNumber(value: entry.grade)) ?? String(format: "%.1f", locale: Locale(identifier: "de_DE"), entry.grade)
                Text("\(entry.mode.title) • Note \(note) — \(entry.verbalAssessment.capitalized(with: Locale(identifier: "de_DE")))")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: onRemove) {
                    Label("Entfernen", systemImage: "trash")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Color.red.opacity(0.08),
                    in: Capsule(style: .continuous)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
                )
                .foregroundStyle(Color.red)
            }

            let maxPointsText = "\(entry.points)/\(entry.maxPoints ?? 100)"
            let dateText = Self.dateFormatter.string(from: entry.timestamp)
            Text("Punkte: \(maxPointsText) • \(dateText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}

private extension View {
    @ViewBuilder
    func platformNumberPad() -> some View {
#if os(iOS)
        self.keyboardType(.numberPad)
#else
        self
#endif
    }

    @ViewBuilder
    func platformTextFieldStyle() -> some View {
#if os(macOS)
        self.textFieldStyle(.roundedBorder)
#else
        self
#endif
    }

    func glassCard(cornerRadius: CGFloat) -> some View {
        self
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 12)
    }

    func glassField(cornerRadius: CGFloat = 18) -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GlassButton(configuration: configuration)
    }

    private struct GlassButton: View {
        @Environment(\.isEnabled) private var isEnabled
        let configuration: Configuration

        var body: some View {
            configuration.label
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Capsule(style: .continuous)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.blue.opacity(isEnabled ? 0.25 : 0.1), radius: 18, x: 0, y: 10)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .opacity(isEnabled ? 1 : 0.6)
                .foregroundStyle(.white)
        }

        private var gradientColors: [Color] {
            if isEnabled {
                return [Color.cyan.opacity(0.8), Color.blue.opacity(0.75), Color.purple.opacity(0.7)]
            } else {
                return [Color.cyan.opacity(0.35), Color.blue.opacity(0.3)]
            }
        }
    }
}

#Preview {
    ContentView()
}
