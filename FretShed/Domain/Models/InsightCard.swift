// InsightCard.swift
// FretShed — Domain Layer
//
// Model for pedagogically grounded insight cards shown after sessions
// and on the Shed page.

import Foundation

// MARK: - InsightCard

struct InsightCard {
    let type: InsightType
    let headline: String
    let body: String?
    let isPositive: Bool
    let isMilestone: Bool
}

// MARK: - InsightType

enum InsightType: String, CaseIterable {
    case weakString
    case strongString
    case hardestNote
    case tierTransition
    case consistencyTrend
    case closeToLevelUp
    case coldSpot
    case coverage
    case sessionDelta
    case knowledgeShapeMilestone
}

// MARK: - InsightSurface

enum InsightSurface: String {
    case summary
    case shed
}

// MARK: - MasteryStage

enum MasteryStage {
    case exploring      // >60% of accessible cells are Untried
    case consolidating  // majority in Struggling/Learning tiers, few Mastered
    case refining       // significant Proficient/Mastered cells, small residual gaps
}

// MARK: - CellKey

struct CellKey: Hashable {
    let noteRaw: Int
    let string: Int
}

// MARK: - TierTransition

struct TierTransition {
    let note: MusicalNote
    let string: Int
    let oldTier: MasteryLevel
    let newTier: MasteryLevel
    let totalAttempts: Int
}
