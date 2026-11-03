import Foundation
import CoreGraphics

@main struct DuoWorkspaceChecks {
    static func main() {
        let cases: [CGSize] = [.init(width: 320, height: 640), .init(width: 740, height: 320),
            .init(width: 900, height: 700), .init(width: 700, height: 900), .init(width: 360, height: 700),
            .init(width: 500, height: 340), .init(width: 1200, height: 700), .init(width: 320, height: 160)]
        for size in cases {
            for opened in [true, false] {
                let p = DuoWorkspacePolicy.plan(size: size, assistantOpen: opened, preferDocked: true)
                let bounds = CGRect(origin: .zero, size: size)
                precondition(bounds.contains(p.page) && bounds.contains(p.assistant))
                if p.mode != .overlay { precondition(!p.page.intersects(p.assistant)) }
            }
        }
        let wide = DuoWorkspacePolicy.plan(size: .init(width: 1000, height: 700), assistantOpen: true, preferDocked: true)
        precondition(wide.mode == .columns && wide.page.minX == 0 && wide.assistant.minX > wide.page.maxX)
        let rtl = DuoWorkspacePolicy.plan(size: .init(width: 1000, height: 700), assistantOpen: true, preferDocked: true, rightToLeft: true)
        precondition(rtl.assistant.minX == 0 && rtl.page.minX > rtl.assistant.maxX)
        let vertical = CGRect(x: 390, y: 0, width: 20, height: 700)
        let book = DuoWorkspacePolicy.plan(size: .init(width: 800, height: 700), divisions: [vertical], assistantOpen: true, preferDocked: true)
        precondition(book.mode == .columns && !book.page.intersects(vertical) && !book.assistant.intersects(vertical))
        let horizontal = CGRect(x: 0, y: 390, width: 700, height: 20)
        let table = DuoWorkspacePolicy.plan(size: .init(width: 700, height: 800), divisions: [horizontal], assistantOpen: true, preferDocked: true)
        precondition(table.mode == .rows && table.page.maxY < horizontal.minY && table.assistant.minY > horizontal.maxY)
        let camera = CGRect(x: 900, y: 0, width: 70, height: 42)
        let occluded = DuoWorkspacePolicy.plan(size: .init(width: 1000, height: 700), occlusions: [camera], assistantOpen: true, preferDocked: true)
        precondition(!occluded.assistant.intersects(camera))
        let floating = DuoWorkspacePolicy.plan(size: .init(width: 800, height: 700), divisions: [vertical], assistantOpen: true, preferDocked: false)
        precondition(floating.mode == .overlay && !floating.assistant.intersects(vertical))
        let closed = DuoWorkspacePolicy.plan(size: .init(width: 1000, height: 700), assistantOpen: false, preferDocked: true)
        precondition(closed.page.size == CGSize(width: 1000, height: 700))
        print("PASS: Duo compact, wide, book, tabletop, RTL, camera, floating and keyboard-sized geometry")
    }
}
