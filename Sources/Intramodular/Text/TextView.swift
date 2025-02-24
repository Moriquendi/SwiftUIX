//
// Copyright (c) Vatsal Manot
//

import Swift
import SwiftUI

#if os(iOS) || os(macOS) || os(tvOS) || targetEnvironment(macCatalyst)

/// A control that displays an editable text interface.
public struct TextView<Label: View>: View {
    struct _Configuration {
        var isConstant: Bool
        var onEditingChanged: (Bool) -> Void
        var onCommit: () -> Void
        
        var isInitialFirstResponder: Bool?
        var isFirstResponder: Bool?
        
        var isEditable: Bool = true
        var isSelectable: Bool = true
        
        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        var autocapitalization: UITextAutocapitalizationType?
        #endif
        var font: AppKitOrUIKitFont?
        var textColor: AppKitOrUIKitColor?
        var textContainerInset: AppKitOrUIKitInsets = .zero
        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        var textContentType: UITextContentType?
        #endif
        var dismissKeyboardOnReturn: Bool = false
        var enablesReturnKeyAutomatically: Bool?
        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        var keyboardType: UIKeyboardType = .default
        var returnKeyType: UIReturnKeyType?
        #endif
    }
    
    @Environment(\.preferredMaximumLayoutWidth) var preferredMaximumLayoutWidth
    
    private var label: Label
    private var text: Binding<String>?
    private var attributedText: Binding<NSAttributedString>?
    private var configuration: _Configuration
    
    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    private var customAppKitOrUIKitClass: UITextView.Type = UIHostingTextView<Label>.self
    #endif
    
    private var isEmpty: Bool {
        text?.wrappedValue.isEmpty ?? attributedText!.wrappedValue.string.isEmpty
    }
    
    public var body: some View {
        return ZStack(alignment: Alignment(horizontal: .leading, vertical: .top)) {
            label
                .visible(isEmpty)
                .animation(.none)
                .padding(configuration.textContainerInset.edgeInsets)
            
            #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
            _TextView<Label>(
                text: text,
                attributedText: attributedText,
                configuration: configuration,
                customAppKitOrUIKitClass: customAppKitOrUIKitClass
            )
            #else
            _TextView<Label>(
                text: text,
                attributedText: attributedText,
                configuration: configuration
            )
            #endif
        }
    }
}

// MARK: - Implementation -

fileprivate struct _TextView<Label: View> {
    typealias Configuration = TextView<Label>._Configuration
    
    let text: Binding<String>?
    let attributedText: Binding<NSAttributedString>?
    let configuration: Configuration
    
    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    var customAppKitOrUIKitClass: UITextView.Type
    #endif
}

#if os(iOS) || os(tvOS)

import UIKit

extension _TextView: UIViewRepresentable {
    typealias UIViewType = UITextView
    
    func makeUIView(context: Context) -> UIViewType {
        let uiView = customAppKitOrUIKitClass.init()
        
        uiView.delegate = context.coordinator
        uiView.backgroundColor = nil
        
        if let isFirstResponder = configuration.isInitialFirstResponder, isFirstResponder, context.environment.isEnabled {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        }
        
        return uiView
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        var cursorOffset: Int?
        
        // Record the current cursor offset.
        if let selectedRange = uiView.selectedTextRange {
            cursorOffset = uiView.offset(from: uiView.beginningOfDocument, to: selectedRange.start)
        }
        
        updateUserInteractability: do {
            #if !os(tvOS)
            if !configuration.isEditable {
                uiView.isEditable = false
            } else {
                uiView.isEditable = configuration.isConstant
                    ? false
                    : context.environment.isEnabled && configuration.isEditable
            }
            #endif
            uiView.isScrollEnabled = context.environment.isScrollEnabled
            uiView.isSelectable = configuration.isSelectable
        }
        
        updateLayoutConfiguration: do {
            (uiView as? UIHostingTextView<Label>)?.preferredMaximumDimensions = context.environment.preferredMaximumLayoutDimensions
        }
        
        updateTextAndGeneralConfiguration: do {
            uiView.autocapitalizationType = configuration.autocapitalization ?? .sentences
            
            let font: UIFont = configuration.font ?? context.environment.font?.toUIFont() ?? .preferredFont(forTextStyle: .body)
            
            if let textColor = configuration.textColor {
                uiView.textColor = textColor
            }
            
            uiView.textContentType = configuration.textContentType
            
            uiView.textContainer.lineFragmentPadding = .zero
            uiView.textContainer.maximumNumberOfLines = context.environment.lineLimit ?? 0
            uiView.textContainerInset = configuration.textContainerInset
            
            if context.environment.requiresAttributedText || attributedText != nil {
                let paragraphStyle = NSMutableParagraphStyle()
                
                paragraphStyle.lineBreakMode = context.environment.lineBreakMode
                paragraphStyle.lineSpacing = context.environment.lineSpacing
                
                context.environment._paragraphSpacing.map {
                    paragraphStyle.paragraphSpacing = $0
                }
                
                if let text = text {
                    uiView.attributedText = NSAttributedString(
                        string: text.wrappedValue,
                        attributes: [
                            NSAttributedString.Key.paragraphStyle: paragraphStyle,
                            NSAttributedString.Key.font: font
                        ]
                    )
                } else if let attributedText = attributedText {
                    if uiView.attributedText != attributedText.wrappedValue {
                        uiView.attributedText = attributedText.wrappedValue
                    }
                }
            } else {
                uiView.text = text!.wrappedValue
                uiView.font = font
            }
        }
        
        correctCursorOffset: do {
            // Reset the cursor offset if possible.
            if let cursorOffset = cursorOffset, let position = uiView.position(from: uiView.beginningOfDocument, offset: cursorOffset), let textRange = uiView.textRange(from: position, to: position) {
                uiView.selectedTextRange = textRange
            }
        }
        
        updateKeyboardConfiguration: do {
            uiView.enablesReturnKeyAutomatically = configuration.enablesReturnKeyAutomatically ?? false
            uiView.keyboardType = configuration.keyboardType
            uiView.returnKeyType = configuration.returnKeyType ?? .default
        }
        
        updateResponderChain: do {
            DispatchQueue.main.async {
                if let isFirstResponder = configuration.isFirstResponder, uiView.window != nil {
                    if isFirstResponder && !uiView.isFirstResponder, context.environment.isEnabled {
                        uiView.becomeFirstResponder()
                    } else if !isFirstResponder && uiView.isFirstResponder {
                        uiView.resignFirstResponder()
                    }
                }
            }
        }
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>?
        var attributedText: Binding<NSAttributedString>?
        var configuration: Configuration
        
        init(
            text: Binding<String>?,
            attributedText: Binding<NSAttributedString>?,
            configuration: Configuration
        ) {
            self.text = text
            self.attributedText = attributedText
            self.configuration = configuration
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            configuration.onEditingChanged(true)
        }
        
        func textViewDidChange(_ textView: UITextView) {
            if let text = text {
                text.wrappedValue = textView.text
            } else {
                attributedText?.wrappedValue = textView.attributedText
            }
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if configuration.dismissKeyboardOnReturn {
                if text == "\n" {
                    configuration.onCommit()
                    
                    return false
                }
            }
            
            return true
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            configuration.onEditingChanged(false)
            configuration.onCommit()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        .init(text: text, attributedText: attributedText, configuration: configuration)
    }
}

#elseif canImport(AppKit)

import AppKit

extension _TextView: NSViewRepresentable {
    typealias NSViewType = _NSTextView
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var view: _TextView
        
        init(_ view: _TextView) {
            self.view = view
        }
        
        func textDidBeginEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            
            if let text = view.text {
                text.wrappedValue = textView.string
            } else if let attributedText = view.attributedText {
                attributedText.wrappedValue = textView.attributedString()
            } else {
                assertionFailure()
            }
            
            view.configuration.onEditingChanged(true)
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            
            if let text = view.text {
                text.wrappedValue = textView.string
            } else if let attributedText = view.attributedText {
                attributedText.wrappedValue = textView.attributedString()
            } else {
                assertionFailure()
            }
        }
        
        func textDidEndEditing(_ notification: Notification) {
            view.configuration.onEditingChanged(false)
            view.configuration.onCommit()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSViewType {
        let nsView = _NSTextView()
        
        nsView.delegate = context.coordinator
        
        nsView.backgroundColor = .clear
        nsView.textContainerInset = configuration.textContainerInset
        
        return nsView
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        if let text = text {
            if nsView.string != text.wrappedValue {
                nsView.string = text.wrappedValue
            }
        } else if let attributedText = attributedText {
            nsView.textStorage?.setAttributedString(attributedText.wrappedValue)
        }
        
        nsView.textColor = configuration.textColor
    }
}

class _NSTextView: NSTextView {
    
}

#endif

// MARK: - API -

extension TextView where Label == EmptyView {
    public init(
        text: Binding<String>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        onCommit: @escaping () -> Void = { }
    ) {
        self.label = EmptyView()
        self.text = text
        self.configuration = .init(
            isConstant: false,
            onEditingChanged: onEditingChanged,
            onCommit: onCommit
        )
    }
    
    public init(
        text: Binding<String?>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        onCommit: @escaping () -> Void = { }
    ) {
        self.init(
            text: text.withDefaultValue(String()),
            onEditingChanged: onEditingChanged,
            onCommit: onCommit
        )
    }
    
    public init(
        _ text: NSAttributedString
    ) {
        self.label = EmptyView()
        self.attributedText = .constant(text)
        self.configuration = .init(
            isConstant: true,
            onEditingChanged: { _ in },
            onCommit: { }
        )
    }
}

extension TextView: DefaultTextInputType where Label == Text {
    public init<S: StringProtocol>(
        _ title: S,
        text: Binding<String>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        onCommit: @escaping () -> Void = { }
    ) {
        self.label = Text(title).foregroundColor(.placeholderText)
        self.text = text
        self.configuration = .init(
            isConstant: false,
            onEditingChanged: onEditingChanged,
            onCommit: onCommit
        )
    }
    
    public init<S: StringProtocol>(
        _ title: S,
        text: Binding<String?>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        onCommit: @escaping () -> Void = { }
    ) {
        self.init(
            title,
            text: text.withDefaultValue(String()),
            onEditingChanged: onEditingChanged,
            onCommit: onCommit
        )
    }
}

extension TextView {
    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    public func customAppKitOrUIKitClass(_ type: UITextView.Type) -> Self {
        then({ $0.customAppKitOrUIKitClass = type })
    }
    #endif
}

extension TextView {
    public func isInitialFirstResponder(_ isInitialFirstResponder: Bool) -> Self {
        then({ $0.configuration.isInitialFirstResponder = isInitialFirstResponder })
    }
    
    public func isFirstResponder(_ isFirstResponder: Bool) -> Self {
        then({ $0.configuration.isFirstResponder = isFirstResponder })
    }
}

extension TextView {
    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    public func autocapitalization(_ autocapitalization: UITextAutocapitalizationType) -> Self {
        then({ $0.configuration.autocapitalization = autocapitalization })
    }
    
    public func foregroundColor(_ foregroundColor: Color) -> Self {
        then({ $0.configuration.textColor = foregroundColor.toUIColor() })
    }
    #endif
    
    public func font(_ font: AppKitOrUIKitFont) -> Self {
        then({ $0.configuration.font = font })
    }
    
    @_disfavoredOverload
    public func foregroundColor(_ foregroundColor: AppKitOrUIKitColor) -> Self {
        then({ $0.configuration.textColor = foregroundColor })
    }
    
    public func textContainerInset(_ textContainerInset: AppKitOrUIKitInsets) -> Self {
        then({ $0.configuration.textContainerInset = textContainerInset })
    }
    
    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    public func textContentType(_ textContentType: UITextContentType?) -> Self {
        then({ $0.configuration.textContentType = textContentType })
    }
    #endif
}

extension TextView {
    public func isEditable(_ isEditable: Bool) -> Self {
        then({ $0.configuration.isEditable = isEditable })
    }
    
    public func isSelectable(_ isSelectable: Bool) -> Self {
        then({ $0.configuration.isSelectable = isSelectable })
    }
}

extension TextView {
    public func dismissKeyboardOnReturn(_ dismissKeyboardOnReturn: Bool) -> Self {
        then({ $0.configuration.dismissKeyboardOnReturn = dismissKeyboardOnReturn })
    }
    
    public func enablesReturnKeyAutomatically(_ enablesReturnKeyAutomatically: Bool) -> Self {
        then({ $0.configuration.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically })
    }
    
    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    public func keyboardType(_ keyboardType: UIKeyboardType) -> Self {
        then({ $0.configuration.keyboardType = keyboardType })
    }
    
    public func returnKeyType(_ returnKeyType: UIReturnKeyType) -> Self {
        then({ $0.configuration.returnKeyType = returnKeyType })
    }
    #endif
}

#endif

// MARK: - Auxiliary Implementation -

extension EnvironmentValues {
    struct _ParagraphSpacing: EnvironmentKey {
        static let defaultValue: CGFloat? = nil
    }
    
    var _paragraphSpacing: CGFloat? {
        get {
            self[_ParagraphSpacing.self]
        } set {
            self[_ParagraphSpacing.self] = newValue
        }
    }
}

extension View {
    /// Sets the amount of space between paragraphs of text in this view.
    ///
    /// Use `paragraphSpacing(_:)` to set the amount of spacing from the bottom of one paragraph to the top of the next for text elements in the view.
    public func paragraphSpacing(_ paragraphSpacing: CGFloat) -> some View {
        environment(\._paragraphSpacing, paragraphSpacing)
    }
}

// MARK: - Helpers -

extension EnvironmentValues {
    fileprivate var requiresAttributedText: Bool {
        _paragraphSpacing != nil
    }
}

private extension CGSize {
    var edgeInsets: EdgeInsets {
        .init(
            top: height / 2,
            leading: width / 2,
            bottom: height / 2,
            trailing: width / 2
        )
    }
}
