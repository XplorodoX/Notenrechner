import Foundation
import SwiftUI

enum GradeMode: String, CaseIterable, Identifiable {
    case ihk = "IHK"
    case normal = "Normal"

    var id: Self { self }

    var title: String { rawValue }
    
    var iconName: String {
        switch self {
        case .ihk: return "building.2.fill"
        case .normal: return "function"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .ihk: return .blue
        case .normal: return .purple
        }
    }
}

struct HistoryEntry: Identifiable, Equatable {
    let id = UUID()
    let mode: GradeMode
    let points: Int
    let maxPoints: Int?
    let grade: Double
    let verbalAssessment: String
    let timestamp: Date
}

struct GradeCalculator {
    static func calculateIHK(points: Int) -> Double {
        let clamped = max(0, min(points, 100))
        switch clamped {
        case 100: return 1.0
        case 99, 98: return 1.1
        case 97, 96: return 1.2
        case 95, 94: return 1.3
        case 93, 92: return 1.4
        case 91: return 1.5
        case 90: return 1.6
        case 89: return 1.7
        case 88: return 1.8
        case 87: return 1.9
        case 86, 85: return 2.0
        case 84: return 2.1
        case 83: return 2.2
        case 82: return 2.3
        case 81: return 2.4
        case 80: return 2.5
        case 79: return 2.6
        case 78, 77: return 2.7
        case 76: return 2.8
        case 75, 74: return 2.9
        case 73: return 3.0
        case 72, 71: return 3.1
        case 70: return 3.2
        case 69, 68: return 3.3
        case 67: return 3.4
        case 66: return 3.5
        case 65, 64: return 3.6
        case 63, 62: return 3.7
        case 61: return 3.8
        case 60, 59: return 3.9
        case 58, 57: return 4.0
        case 56, 55: return 4.1
        case 54: return 4.2
        case 53, 52: return 4.3
        case 51, 50: return 4.4
        case 49: return 4.5
        case 48, 47: return 4.6
        case 46, 45: return 4.7
        case 44, 43: return 4.8
        case 42, 41: return 4.9
        case 40, 39, 38: return 5.0
        case 37, 36: return 5.1
        case 35, 34: return 5.2
        case 33, 32: return 5.3
        case 31, 30: return 5.4
        case 29: return 5.5
        case 23...28: return 5.6
        case 17...22: return 5.7
        case 12...16: return 5.8
        case 6...11: return 5.9
        default: return 6.0
        }
    }

    static func calculateIHK(points: Int, maxPoints: Int) -> Double {
        guard maxPoints > 0 else { return .nan }
        let ratio = (Double(points) / Double(maxPoints)) * 100.0
        let scaled = max(0, min(Int(ratio), 100))
        return calculateIHK(points: scaled)
    }

    static func calculateNormal(points: Int, maxPoints: Int) -> Double {
        guard maxPoints > 0 else { return .nan }
        let percentage = (Double(points) * 100.0) / Double(maxPoints)
        return ((6.0 - 1.0) * (100.0 - percentage) / 100.0) + 1.0
    }

    static func verbalAssessment(for grade: Double) -> String {
        let normalized = (grade * 10.0).rounded() / 10.0

        switch normalized {
        case ...1.5: return "sehr gut"
        case ...2.5: return "gut"
        case ...3.5: return "befriedigend"
        case ...4.0: return "ausreichend"
        case ...4.9: return "mangelhaft"
        default: return "ungenügend"
        }
    }
}
