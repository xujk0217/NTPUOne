//
//  FeaturesView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/27.
//

import SwiftUI

struct FeaturesView: View {
    var body: some View {
        ReportBugView(suggestFeature: true)
    }
}

#Preview {
    NavigationStack { FeaturesView() }
        .environmentObject(AdFreeService())
}
