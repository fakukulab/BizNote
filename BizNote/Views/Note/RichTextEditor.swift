import SwiftUI
import UIKit

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var rtfData: String

    func makeUIView(context: Context) -> EditorContainerView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = .clear
        textView.allowsEditingTextAttributes = true
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        context.coordinator.textView = textView
        textView.attributedText = attributedText()
        return EditorContainerView(toolbar: context.coordinator.makeToolbar(), textView: textView)
    }

    func updateUIView(_ container: EditorContainerView, context: Context) {
        context.coordinator.parent = self
        let textView = container.textView
        guard !context.coordinator.isUpdatingFromView else { return }

        if textView.text != text, !textView.isFirstResponder {
            textView.attributedText = attributedText()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func attributedText() -> NSAttributedString {
        if let data = Data(base64Encoded: rtfData),
           let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
           ) {
            return attributed
        }

        return NSAttributedString(
            string: text,
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
    }

    final class EditorContainerView: UIView {
        let textView: UITextView

        init(toolbar: UIToolbar, textView: UITextView) {
            self.textView = textView
            super.init(frame: .zero)

            backgroundColor = .clear
            toolbar.translatesAutoresizingMaskIntoConstraints = false
            textView.translatesAutoresizingMaskIntoConstraints = false
            toolbar.setContentHuggingPriority(.required, for: .vertical)
            toolbar.setContentCompressionResistancePriority(.required, for: .vertical)
            addSubview(toolbar)
            addSubview(textView)

            NSLayoutConstraint.activate([
                toolbar.topAnchor.constraint(equalTo: topAnchor),
                toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
                toolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
                toolbar.heightAnchor.constraint(equalToConstant: 44),
                textView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
                textView.leadingAnchor.constraint(equalTo: leadingAnchor),
                textView.trailingAnchor.constraint(equalTo: trailingAnchor),
                textView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        weak var textView: UITextView?
        var isUpdatingFromView = false

        init(parent: RichTextEditor) {
            self.parent = parent
        }

        func makeToolbar() -> UIToolbar {
            let toolbar = UIToolbar()
            let formatButton = UIBarButtonItem(
                image: UIImage(systemName: "textformat"),
                style: .plain,
                target: nil,
                action: nil
            )
            formatButton.menu = makeFormatMenu()

            let listButton = UIBarButtonItem(
                image: UIImage(systemName: "list.bullet.rectangle"),
                style: .plain,
                target: nil,
                action: nil
            )
            listButton.menu = makeListMenu()

            toolbar.items = [
                formatButton,
                listButton,
                UIBarButtonItem(
                    image: UIImage(systemName: "checklist"),
                    style: .plain,
                    target: self,
                    action: #selector(insertChecklist)
                ),
                UIBarButtonItem.flexibleSpace(),
                UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
                    self?.textView?.resignFirstResponder()
                })
            ]
            toolbar.sizeToFit()
            return toolbar
        }

        func textViewDidChange(_ textView: UITextView) {
            persist(textView)
        }

        private func makeFormatMenu() -> UIMenu {
            UIMenu(children: [
                UIAction(title: String(localized: "note.editor.title", defaultValue: "Title")) { [weak self] _ in
                    self?.applyTextStyle(.title1, weight: .bold)
                },
                UIAction(title: String(localized: "note.editor.heading", defaultValue: "Heading")) { [weak self] _ in
                    self?.applyTextStyle(.title2, weight: .semibold)
                },
                UIAction(title: String(localized: "note.editor.subheading", defaultValue: "Subheading")) { [weak self] _ in
                    self?.applyTextStyle(.title3, weight: .semibold)
                },
                UIAction(title: String(localized: "note.editor.body", defaultValue: "Body")) { [weak self] _ in
                    self?.applyTextStyle(.body)
                },
                UIMenu(options: .displayInline, children: [
                    UIAction(title: String(localized: "note.editor.bold", defaultValue: "Bold"), image: UIImage(systemName: "bold")) { [weak self] _ in
                        self?.toggleFontTrait(.traitBold)
                    },
                    UIAction(title: String(localized: "note.editor.italic", defaultValue: "Italic"), image: UIImage(systemName: "italic")) { [weak self] _ in
                        self?.toggleFontTrait(.traitItalic)
                    },
                    UIAction(title: String(localized: "note.editor.underline", defaultValue: "Underline"), image: UIImage(systemName: "underline")) { [weak self] _ in
                        self?.toggleAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue)
                    },
                    UIAction(title: String(localized: "note.editor.strikethrough", defaultValue: "Strikethrough"), image: UIImage(systemName: "strikethrough")) { [weak self] _ in
                        self?.toggleAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue)
                    }
                ])
            ])
        }

        private func makeListMenu() -> UIMenu {
            UIMenu(children: [
                UIAction(title: String(localized: "note.editor.bulletedList", defaultValue: "Bulleted List"), image: UIImage(systemName: "list.bullet")) { [weak self] _ in
                    self?.insertLinePrefix("• ")
                },
                UIAction(title: String(localized: "note.editor.numberedList", defaultValue: "Numbered List"), image: UIImage(systemName: "list.number")) { [weak self] _ in
                    self?.insertNumberedListPrefix()
                },
                UIAction(title: String(localized: "note.editor.dashedList", defaultValue: "Dashed List"), image: UIImage(systemName: "list.dash")) { [weak self] _ in
                    self?.insertLinePrefix("- ")
                }
            ])
        }

        private func applyTextStyle(_ textStyle: UIFont.TextStyle, weight: UIFont.Weight = .regular) {
            guard let textView else { return }
            let preferredFont = UIFont.preferredFont(forTextStyle: textStyle)
            let font = UIFont.systemFont(ofSize: preferredFont.pointSize, weight: weight)
            applyFont(font, in: textView)
        }

        private func applyFont(_ font: UIFont, in textView: UITextView) {
            let range = textView.selectedRange
            if range.length == 0 {
                textView.typingAttributes[.font] = font
            } else {
                let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
                mutable.addAttribute(.font, value: font, range: range)
                textView.attributedText = mutable
                textView.selectedRange = range
            }
            persist(textView)
        }

        private func toggleFontTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
            guard let textView else { return }
            let range = textView.selectedRange
            if range.length == 0 {
                let currentFont = (textView.typingAttributes[.font] as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
                textView.typingAttributes[.font] = toggledFont(from: currentFont, trait: trait)
            } else {
                let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
                mutable.enumerateAttribute(.font, in: range) { value, subrange, _ in
                    let currentFont = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
                    mutable.addAttribute(.font, value: toggledFont(from: currentFont, trait: trait), range: subrange)
                }
                textView.attributedText = mutable
                textView.selectedRange = range
            }
            persist(textView)
        }

        private func toggleAttribute(_ key: NSAttributedString.Key, value: Int) {
            guard let textView else { return }
            let range = textView.selectedRange
            if range.length == 0 {
                let isActive = textView.typingAttributes[key] != nil
                textView.typingAttributes[key] = isActive ? nil : value
            } else {
                let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
                let effectiveRange = NSRange(location: range.location, length: 1)
                let isActive = mutable.attribute(key, at: range.location, effectiveRange: nil) != nil
                if isActive {
                    mutable.removeAttribute(key, range: range)
                } else {
                    mutable.addAttribute(key, value: value, range: range)
                }
                textView.attributedText = mutable
                textView.selectedRange = NSUnionRange(range, effectiveRange)
            }
            persist(textView)
        }

        @objc private func insertChecklist() {
            insertLinePrefix("☐ ")
        }

        private func insertNumberedListPrefix() {
            guard let textView else { return }
            let lineNumber = currentLineNumber(in: textView) + 1
            insertLinePrefix("\(lineNumber). ")
        }

        private func insertLinePrefix(_ prefix: String) {
            guard let textView else { return }
            let insertion = needsLeadingNewline(in: textView) ? "\n\(prefix)" : prefix
            textView.insertText(insertion)
            persist(textView)
        }

        private func needsLeadingNewline(in textView: UITextView) -> Bool {
            guard textView.selectedRange.location > 0 else { return false }
            let text = textView.text as NSString
            return text.substring(with: NSRange(location: textView.selectedRange.location - 1, length: 1)) != "\n"
        }

        private func currentLineNumber(in textView: UITextView) -> Int {
            let textBeforeCursor = (textView.text as NSString).substring(to: textView.selectedRange.location)
            let numberedLines = textBeforeCursor
                .split(separator: "\n")
                .filter { $0.range(of: #"^\d+\. "#, options: .regularExpression) != nil }
            return numberedLines.count
        }

        private func toggledFont(from font: UIFont, trait: UIFontDescriptor.SymbolicTraits) -> UIFont {
            var traits = font.fontDescriptor.symbolicTraits
            if traits.contains(trait) {
                traits.remove(trait)
            } else {
                traits.insert(trait)
            }
            let descriptor = font.fontDescriptor.withSymbolicTraits(traits) ?? font.fontDescriptor
            return UIFont(descriptor: descriptor, size: font.pointSize)
        }

        private func persist(_ textView: UITextView) {
            isUpdatingFromView = true
            parent.text = textView.text
            if let data = try? textView.attributedText.data(
                from: NSRange(location: 0, length: textView.attributedText.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            ) {
                parent.rtfData = data.base64EncodedString()
            }
            isUpdatingFromView = false
        }
    }
}
