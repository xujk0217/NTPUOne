//
//  extention.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/10.
//

import Foundation
import SwiftUI

extension String {
    func substring(from: Int, length: Int) -> String {
        let start = index(startIndex, offsetBy: from)
        let end = index(start, offsetBy: length)
        return String(self[start..<end])
    }
    func substring(from: Int) -> String {
        let start = index(startIndex, offsetBy: from)
        return String(self[start...])
    }
}
// textfield 擴增器
struct AutoSizingTF: UIViewRepresentable {
    var hint: String
    @Binding var text: String
    @Binding var containerHeight: CGFloat
    var onEnd: () -> ()
    
    func makeCoordinator() -> Coordinator {
        return AutoSizingTF.Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        
        // 设置默认样式
        textView.text = hint
        textView.textColor = .lightGray
        textView.font = .systemFont(ofSize: 17)
        
        // 背景颜色与 TextField 保持一致
        textView.backgroundColor = UIColor.systemBackground
        
        // 添加边框
        textView.layer.borderColor = UIColor.systemGray5.cgColor
        textView.layer.borderWidth = 1.0
        textView.layer.cornerRadius = 5.0
        
        textView.delegate = context.coordinator
        
        // 添加工具栏
        let toolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        toolBar.barStyle = .default
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: context.coordinator, action: #selector(context.coordinator.closeKeyBoard))
        toolBar.items = [spacer, doneButton]
        toolBar.sizeToFit()
        textView.inputAccessoryView = toolBar
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        DispatchQueue.main.async {
            if containerHeight == 0 {
                containerHeight = uiView.contentSize.height
            }
        }
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: AutoSizingTF
        init(parent: AutoSizingTF) {
            self.parent = parent
        }
        
        @objc func closeKeyBoard() {
            parent.onEnd()
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.text == parent.hint {
                textView.text = ""
                textView.textColor = UIColor(Color.primary)
            }
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.containerHeight = textView.contentSize.height
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                textView.text = parent.hint
                textView.textColor = .gray
            }
        }
    }
}
