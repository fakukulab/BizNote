import Foundation
import UIKit
import CoreText

final class ExcelExportService {

    func exportBusinessCards(
        _ cards: [BusinessCard],
        fileName: String = "biznote_businessCards"
    ) throws -> URL {
        let headers = [
            String(localized: "export.header.name"),
            String(localized: "export.header.company"),
            String(localized: "export.header.department"),
            String(localized: "export.header.jobTitle"),
            String(localized: "export.header.email"),
            String(localized: "export.header.mobile"),
            String(localized: "export.header.office"),
            String(localized: "export.header.fax"),
            String(localized: "export.header.address"),
            String(localized: "export.header.website"),
            String(localized: "export.header.memo"),
            String(localized: "export.header.language"),
            String(localized: "export.header.date")
        ]

        var csv = "\u{FEFF}"
        csv += headers.map(escape).joined(separator: ",") + "\r\n"

        for card in cards {
            let row = [
                card.name, card.company, card.department,
                card.jobTitle, card.email, card.phone,
                card.officePhone, card.fax, card.address,
                card.website, card.memo, card.scannedLanguage,
                DateFormatter.exportTimestamp.string(from: card.createdAt)
            ].map(escape)
            csv += row.joined(separator: ",") + "\r\n"
        }

        return try write(csv: csv, fileName: fileName)
    }

    func exportNotes(
        _ notes: [Note],
        fileName: String = "biznote_notes"
    ) throws -> URL {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 36
        let contentRect = pageBounds.insetBy(dx: margin, dy: margin)

        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        let ts = DateFormatter.filenameSafe.string(from: Date())
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("\(fileName)_\(ts).pdf")

        try renderer.writePDF(to: url) { context in
            for note in notes {
                drawPaginated(
                    noteAttributedString(note),
                    contentRect: contentRect,
                    pageBounds: pageBounds,
                    context: context
                )
            }
        }

        return url
    }

    private func noteAttributedString(_ note: Note) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let titleFont = UIFont.boldSystemFont(ofSize: 20)
        let metaFont = UIFont.systemFont(ofSize: 11)
        let bodyFont = UIFont.systemFont(ofSize: 13)
        let metaColor = UIColor.darkGray

        result.append(NSAttributedString(
            string: (note.title.isEmpty ? String(localized: "export.untitledNote") : note.title) + "\n",
            attributes: [.font: titleFont]
        ))

        let favorite = note.isFavorite ? "  ★" : ""
        let meta = "\(note.categoryName) · \(DateFormatter.exportTimestamp.string(from: note.createdAt))" +
            String(format: String(localized: "export.updatedAt"), DateFormatter.exportTimestamp.string(from: note.updatedAt)) + favorite
        result.append(NSAttributedString(
            string: meta + "\n",
            attributes: [.font: metaFont, .foregroundColor: metaColor]
        ))

        if !note.tags.isEmpty {
            result.append(NSAttributedString(
                string: String(format: String(localized: "export.tags"), note.tags.joined(separator: ", ")) + "\n",
                attributes: [.font: metaFont, .foregroundColor: metaColor]
            ))
        }

        result.append(NSAttributedString(string: "\n"))
        result.append(NSAttributedString(
            string: note.content.isEmpty ? String(localized: "export.emptyContent") : note.content,
            attributes: [.font: bodyFont]
        ))
        result.append(NSAttributedString(string: "\n\n"))

        return result
    }

    private func drawPaginated(
        _ attributed: NSAttributedString,
        contentRect: CGRect,
        pageBounds: CGRect,
        context: UIGraphicsPDFRendererContext
    ) {
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let fullLength = attributed.length
        var location = 0

        while location < fullLength {
            context.beginPage()

            let cgContext = context.cgContext
            cgContext.saveGState()
            cgContext.translateBy(x: 0, y: pageBounds.height)
            cgContext.scaleBy(x: 1, y: -1)

            let flippedRect = CGRect(
                x: contentRect.minX,
                y: pageBounds.height - contentRect.maxY,
                width: contentRect.width,
                height: contentRect.height
            )
            let path = CGPath(rect: flippedRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: location, length: 0), path, nil)
            CTFrameDraw(frame, cgContext)
            cgContext.restoreGState()

            let visibleRange = CTFrameGetVisibleStringRange(frame)
            guard visibleRange.length > 0 else { break }
            location += visibleRange.length
        }
    }

    private func escape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func write(csv: String, fileName: String) throws -> URL {
        let ts = DateFormatter.filenameSafe.string(from: Date())
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("\(fileName)_\(ts).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
