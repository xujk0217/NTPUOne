//
//  SpinningWheelView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/8/6.
//

import SwiftUI

@available(iOS 17.0, *)
struct SpinningWheelView: View {
    let restaurants: [FDetail]
    @Binding var resetTrigger: Bool
    let onFinish: (FDetail) -> Void

    @State private var hasSpun = false
    @State private var rotation: Double = 0
    @State private var isSpinning = false
    
    let Ecolors: [Color] = [.orange.opacity(0.3), .white]
    let Ocolors: [Color] = [.orange.opacity(0.3), .white, .gray.opacity(0.3)]

    var body: some View {
        VStack(spacing: 16) {
            // MARK: - 圓形轉盤
            ZStack{
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                        .frame(width: 280, height: 280)

                    ForEach(restaurants.indices, id: \.self) { index in
                        let anglePerItem = 360.0 / Double(restaurants.count)
                        let startAngle = anglePerItem * Double(index)
                        let endAngle = anglePerItem * Double(index + 1)
                        let sliceColor = (restaurants.count % 2 == 0)
                                ? Ecolors[index % Ecolors.count]
                                : Ocolors[index % Ocolors.count]


                        // 每一塊披薩切片
                        PieSlice(startAngle: .degrees(startAngle), endAngle: .degrees(endAngle))
                            .fill(sliceColor)
                            .frame(width: 280, height: 280)

                        // 每一塊的文字
                        VStack {
                            Text(restaurants[index].store)
                                .font(.caption2)
                                .foregroundColor(.black)
                                .rotationEffect(.degrees(-startAngle - anglePerItem / 2))
                                .frame(width: 70)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                        }
                        .rotationEffect(.degrees(startAngle + anglePerItem / 2))
                        .padding(.top, 10)
                    }

                }
                .rotationEffect(.degrees(rotation))
                
                Triangle()
                    .fill(Color.red)
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(180))
                    .offset(y: -160)
            }

            // MARK: - 按鈕
            Button(action: {
                if hasSpun {
                    withAnimation(.easeIn(duration: 0.5)) {
                        rotation = 0
                    }
                    hasSpun = false
                } else {
                    spinWheel()
                }
            }) {
                Text(hasSpun ? "重置" :"開始轉盤")
                    .bold()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(hasSpun ? Color.gray : Color.orange)
                    .opacity(isSpinning ? 0.5 : 1)
                    .animation(nil, value: isSpinning)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(isSpinning)
            .buttonStyle(.plain)
        }
        .padding()
        .onChange(of: resetTrigger) { reset in
            if reset {
                withAnimation(.easeIn(duration: 0.5)) {
                    rotation = 0
                }
                isSpinning = false
                hasSpun = false
                resetTrigger = false
            }
        }
    }

    // MARK: - 抽選邏輯
    func spinWheel() {
        guard !restaurants.isEmpty else { return }
        isSpinning = true
        hasSpun = true

        let fullSpins = Double(Int.random(in: 4...6)) * 360
        let targetIndex = Int.random(in: 0..<restaurants.count)
        let anglePerItem = 360.0 / Double(restaurants.count)
        let finalAngle = anglePerItem * Double(targetIndex) + anglePerItem / 2
        let totalRotation = fullSpins + (360 - finalAngle)

        withAnimation(.easeOut(duration: 3.0)) {
            rotation += totalRotation
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
            isSpinning = false
            onFinish(restaurants[targetIndex])
        }
    }
}

struct PieSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: center)
        path.addArc(center: center,
                    radius: rect.width / 2,
                    startAngle: startAngle - .degrees(90),
                    endAngle: endAngle - .degrees(90),
                    clockwise: false)
        path.closeSubpath()
        return path
    }
}
