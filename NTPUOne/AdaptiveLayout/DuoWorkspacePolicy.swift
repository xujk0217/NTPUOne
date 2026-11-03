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
