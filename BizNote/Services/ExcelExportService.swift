import Foundation
import UIKit
import CoreText

enum SpreadsheetFormat: String, CaseIterable, Identifiable {
    case csv
    case xlsx

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .csv:
            return String(localized: "export.format.csv", defaultValue: "CSV")
        case .xlsx:
            return String(localized: "export.format.xlsx", defaultValue: "Excel (XLSX)")
        }
    }
}

final class ExcelExportService {

    func exportBusinessCards(
        _ cards: [BusinessCard],
        format: SpreadsheetFormat = .csv,
        fileName: String = "biznote_businessCards"
    ) throws -> URL {
        let headers = [
            String(localized: "export.header.name"),
            String(localized: "export.header.phonetic", defaultValue: "Phonetic"),
            String(localized: "export.header.company"),
            String(localized: "export.header.department"),
            String(localized: "export.header.jobTitle"),
            String(localized: "export.header.email"),
            String(localized: "export.header.mobile"),
            String(localized: "export.header.office"),
            String(localized: "export.header.website"),
            String(localized: "export.header.memo"),
            String(localized: "export.header.language"),
            String(localized: "export.header.date")
        ]

        let rows = cards.map { card in
            [
                card.name,
                card.namePhonetic,
                card.company,
                card.department,
                card.jobTitle,
                card.email,
                card.phone,
                card.officePhone,
                card.website,
                card.memo,
                card.scannedLanguage,
                DateFormatter.exportTimestamp.string(from: card.createdAt)
            ]
        }

        switch format {
        case .csv:
            return try exportBusinessCardsCSV(headers: headers, rows: rows, fileName: fileName)
        case .xlsx:
            return try exportBusinessCardsXLSX(headers: headers, rows: rows, fileName: fileName)
        }
    }

    private func exportBusinessCardsCSV(
        headers: [String],
        rows: [[String]],
        fileName: String
    ) throws -> URL {
        var csv = "\u{FEFF}"
        csv += headers.map(escape).joined(separator: ",") + "\r\n"

        for rowValues in rows {
            let row = rowValues.map(escape)
            csv += row.joined(separator: ",") + "\r\n"
        }

        return try write(csv: csv, fileName: fileName)
    }

    private func exportBusinessCardsXLSX(
        headers: [String],
        rows: [[String]],
        fileName: String
    ) throws -> URL {
        let ts = DateFormatter.filenameSafe.string(from: Date())
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("\(fileName)_\(ts).xlsx")
        try buildXLSX(headers: headers, rows: rows).write(to: url, options: .atomic)
        return url
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

    private func buildXLSX(headers: [String], rows: [[String]]) -> Data {
        func rowXML(_ values: [String], rowIndex: Int) -> String {
            var cells = ""
            for (index, value) in values.enumerated() {
                let ref = "\(columnLetter(index))\(rowIndex)"
                cells += "<c r=\"\(ref)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(xmlEscape(value))</t></is></c>"
            }
            return "<row r=\"\(rowIndex)\">\(cells)</row>"
        }

        var sheetRows = rowXML(headers, rowIndex: 1)
        for (index, row) in rows.enumerated() {
            sheetRows += rowXML(row, rowIndex: index + 2)
        }

        let sheetXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>\(sheetRows)</sheetData></worksheet>
        """

        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>
        """

        let rootRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
        """

        let workbookXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Business Cards" sheetId="1" r:id="rId1"/></sheets></workbook>
        """

        let workbookRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>
        """

        let entries = [
            MinimalZipEntry(name: "[Content_Types].xml", data: Data(contentTypes.utf8)),
            MinimalZipEntry(name: "_rels/.rels", data: Data(rootRels.utf8)),
            MinimalZipEntry(name: "xl/workbook.xml", data: Data(workbookXML.utf8)),
            MinimalZipEntry(name: "xl/_rels/workbook.xml.rels", data: Data(workbookRels.utf8)),
            MinimalZipEntry(name: "xl/worksheets/sheet1.xml", data: Data(sheetXML.utf8))
        ]
        return MinimalZipWriter.write(entries)
    }

    private func columnLetter(_ index: Int) -> String {
        var currentIndex = index
        var letters = ""
        repeat {
            let scalar = UnicodeScalar(65 + currentIndex % 26)!
            letters = String(scalar) + letters
            currentIndex = currentIndex / 26 - 1
        } while currentIndex >= 0
        return letters
    }

    private func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private func write(csv: String, fileName: String) throws -> URL {
        let ts = DateFormatter.filenameSafe.string(from: Date())
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("\(fileName)_\(ts).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
