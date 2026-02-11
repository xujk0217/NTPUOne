//
//  NextCourseWidgetBundle.swift
//  NextCourseWidget
//
//  Created by 許君愷 on 2024/8/21.
//

import WidgetKit
import SwiftUI

@main
struct NextCourseWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        NextCourseWidget()
        CourseLargeWidget()
        MemoWidget()
        NextTaskWidget()
    }
}
