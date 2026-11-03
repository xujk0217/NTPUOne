import Foundation
import CoreGraphics

/// Window-local geometry only. No model names, screen sizes or hinge-angle thresholds.
enum DuoWorkspaceMode: Equatable { case overlay, columns, rows }
struct DuoWorkspacePlan: Equatable {
    var mode: DuoWorkspaceMode
    var page: CGRect
    var assistant: CGRect
}
enum DuoWorkspacePolicy {
    static func plan(size: CGSize, divisions: [CGRect] = [], occlusions: [CGRect] = [],
                     assistantOpen: Bool, preferDocked: Bool, rightToLeft: Bool = false) -> DuoWorkspacePlan {
        let bounds = CGRect(origin: .zero, size: CGSize(width: max(0, size.width), height: max(0, size.height)))
        var page = bounds
        var mode = DuoWorkspaceMode.overlay
        let margin: CGFloat = 12
        var assistant = CGRect(x: max(0, (bounds.width - min(620, max(0, bounds.width - 24))) / 2),
                               y: max(0, (bounds.height - min(820, max(0, bounds.height - 24))) / 2),
                               width: min(620, max(0, bounds.width - 24)), height: min(820, max(0, bounds.height - 24)))
        let regions = divisions.map { $0.intersection(bounds) }.filter { !$0.isNull && $0.width > 0 && $0.height > 0 }
        if assistantOpen {
            if let fold = regions.first(where: { $0.height >= bounds.height * 0.5 && $0.width < bounds.width * 0.4 }) {
                let left = CGRect(x: 0, y: 0, width: max(0, fold.minX - 8), height: bounds.height)
                let right = CGRect(x: min(bounds.width, fold.maxX + 8), y: 0, width: max(0, bounds.width - fold.maxX - 8), height: bounds.height)
                if preferDocked && min(left.width, right.width) >= 280 && bounds.height >= 240 {
                    mode = .columns; page = rightToLeft ? right : left; assistant = rightToLeft ? left : right
                } else {
                    assistant = (rightToLeft ? left : right).insetBy(dx: margin, dy: margin)
                }
            } else if let fold = regions.first(where: { $0.width >= bounds.width * 0.5 && $0.height < bounds.height * 0.4 }) {
                let upper = CGRect(x: 0, y: 0, width: bounds.width, height: max(0, fold.minY - 8))
                let lower = CGRect(x: 0, y: min(bounds.height, fold.maxY + 8), width: bounds.width, height: max(0, bounds.height - fold.maxY - 8))
                if preferDocked && min(upper.height, lower.height) >= 220 && bounds.width >= 320 {
                    mode = .rows; page = upper; assistant = lower
                } else { assistant = (upper.height >= lower.height ? upper : lower).insetBy(dx: margin, dy: margin) }
            } else if preferDocked && bounds.width >= 820 && bounds.height >= 280 {
                mode = .columns
                let chatWidth = min(480, max(340, bounds.width * 0.4))
                let mainWidth = bounds.width - chatWidth - 12
                page = CGRect(x: rightToLeft ? chatWidth + 12 : 0, y: 0, width: mainWidth, height: bounds.height)
                assistant = CGRect(x: rightToLeft ? 0 : mainWidth + 12, y: 0, width: chatWidth, height: bounds.height)
            }
        }
        assistant = freeRectangle(assistant.intersection(bounds), avoiding: occlusions)
        if assistant.isNull || assistant.width < 0 || assistant.height < 0 { assistant = .zero }
        return DuoWorkspacePlan(mode: mode, page: page, assistant: assistant)
    }

    /// The floating entry stays in the lower-right usable region, away from folds and cameras.
    static func floatingArea(size: CGSize, divisions: [CGRect] = [], occlusions: [CGRect] = []) -> CGRect {
        let bounds = CGRect(origin: .zero, size: CGSize(width: max(0, size.width), height: max(0, size.height)))
        var area = bounds
        for raw in divisions {
            let fold = raw.intersection(area)
            guard !fold.isNull, fold.width > 0, fold.height > 0 else { continue }
            if fold.height >= area.height * 0.5 && fold.width < area.width * 0.4 {
                let right = CGRect(x: min(area.maxX, fold.maxX + 8), y: area.minY,
                                   width: max(0, area.maxX - fold.maxX - 8), height: area.height)
                let left = CGRect(x: area.minX, y: area.minY, width: max(0, fold.minX - area.minX - 8), height: area.height)
                area = right.width >= 72 ? right : left
            } else if fold.width >= area.width * 0.5 && fold.height < area.height * 0.4 {
                let lower = CGRect(x: area.minX, y: min(area.maxY, fold.maxY + 8),
                                   width: area.width, height: max(0, area.maxY - fold.maxY - 8))
                let upper = CGRect(x: area.minX, y: area.minY, width: area.width, height: max(0, fold.minY - area.minY - 8))
                area = lower.height >= 72 ? lower : upper
            }
        }
        return freeRectangle(area, avoiding: occlusions)
    }
    static func floatingButton(in area: CGRect, occlusions: [CGRect] = []) -> CGRect {
        guard !area.isNull, area.width >= 56, area.height >= 56 else { return .zero }
        let side: CGFloat = 56
        let right = max(0, min(16, area.width - side))
        let bottom = max(0, min(76, area.height - side))
        let button = CGRect(x: area.maxX - right - side, y: area.maxY - bottom - side, width: side, height: side)
        return occlusions.contains(where: { $0.insetBy(dx: -8, dy: -8).intersects(button) }) ? .zero : button
    }

    /// Normalized anchor for the actual floating button, including fold/camera adjustments.
    static func buttonAnchor(size: CGSize, divisions: [CGRect] = [], occlusions: [CGRect] = []) -> CGPoint {
        let area = floatingArea(size: size, divisions: divisions, occlusions: occlusions)
        let button = floatingButton(in: area, occlusions: occlusions)
        guard size.width > 0, size.height > 0, !button.isEmpty else { return CGPoint(x: 1, y: 1) }
        return CGPoint(x: max(0, min(1, button.midX / size.width)), y: max(0, min(1, button.midY / size.height)))
    }

    /// Keep custom chat controls out of camera regions; native page containers adapt themselves.
    private static func freeRectangle(_ frame: CGRect, avoiding occlusions: [CGRect]) -> CGRect {
        var result = frame
        for obstruction in occlusions {
            let blocked = result.intersection(obstruction.insetBy(dx: -8, dy: -8))
            guard !blocked.isNull, blocked.width > 0, blocked.height > 0 else { continue }
            let candidates = [
                CGRect(x: result.minX, y: result.minY, width: max(0, blocked.minX - result.minX), height: result.height),
                CGRect(x: blocked.maxX, y: result.minY, width: max(0, result.maxX - blocked.maxX), height: result.height),
                CGRect(x: result.minX, y: result.minY, width: result.width, height: max(0, blocked.minY - result.minY)),
                CGRect(x: result.minX, y: blocked.maxY, width: result.width, height: max(0, result.maxY - blocked.maxY))
            ]
            result = candidates.filter { $0.width >= min(240, frame.width) && $0.height >= min(120, frame.height) }
                .max(by: { $0.width * $0.height < $1.width * $1.height }) ?? .zero
        }
        return result
    }
}
