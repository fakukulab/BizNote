import Foundation
import UIKit
import CoreText

enum SpreadsheetFormat: String, CaseIterable, Identifiable {
    case csv
    case xlsx
    case pdf

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .csv:
            return String(localized: "export.format.csv", defaultValue: "CSV")
        case .xlsx:
            return String(localized: "export.format.xlsx", defaultValue: "Excel (XLSX)")
        case .pdf:
            return String(localized: "export.format.pdf", defaultValue: "PDF (카드별 1장)")
        }
    }
}

enum ExcelExportServiceError: LocalizedError {
    case unsupportedFormat

    var errorDescription: String? {
        String(localized: "export.error.unsupportedFormat", defaultValue: "지원하지 않는 내보내기 형식입니다.")
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
        case .pdf:
            return try exportBusinessCardsPDF(cards, fileName: fileName)
        }
    }

    func exportEventVisitors(
        _ visitors: [EventVisitor],
        format: SpreadsheetFormat = .xlsx,
        eventName: String
    ) throws -> URL {
        let headers = [
            String(localized: "export.header.no", defaultValue: "No"),
            String(localized: "export.header.registeredAt", defaultValue: "등록일시"),
            String(localized: "export.header.name"),
            String(localized: "export.header.company"),
            String(localized: "export.header.jobTitle"),
            String(localized: "export.header.email"),
            String(localized: "export.header.mobile"),
            String(localized: "export.header.phone", defaultValue: "전화번호"),
            String(localized: "export.header.country", defaultValue: "국가"),
            String(localized: "export.header.collectionMethod", defaultValue: "수집 방식"),
            String(localized: "export.header.interestArea", defaultValue: "관심분야"),
            String(localized: "export.header.wantsMaterials", defaultValue: "자료 요청"),
            String(localized: "export.header.memo")
        ]

        let rows = visitors.enumerated().map { index, visitor -> [String] in
            [
                "\(index + 1)",
                DateFormatter.exportTimestamp.string(from: visitor.createdAt),
                visitor.name,
                visitor.company,
                visitor.jobTitle,
                visitor.email,
                visitor.mobile,
                visitor.phone,
                visitor.countryCode.isEmpty ? "" : EventCountry(code: visitor.countryCode).localizedName,
                visitor.collectionMethod.localizedName,
                visitor.interestArea?.localizedName ?? "",
                wantsMaterialsText(visitor.wantsMaterials),
                visitor.memo
            ]
        }

        let safeEventName = sanitizedFileNameComponent(eventName.isEmpty ? String(localized: "note.untitled") : eventName)
        let visitorsLabel = String(localized: "eventMode.export.fileNameVisitors", defaultValue: "방문객")
        let dateString = DateFormatter.filenameDateOnly.string(from: Date())
        let fileName = "\(safeEventName)_\(visitorsLabel)_\(dateString)"
        let dir = FileManager.default.temporaryDirectory

        switch format {
        case .csv:
            var csv = "\u{FEFF}"
            csv += headers.map(escape).joined(separator: ",") + "\r\n"
            for rowValues in rows {
                csv += rowValues.map(escape).joined(separator: ",") + "\r\n"
            }
            let url = dir.appending(path: "\(fileName).csv")
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        case .xlsx:
            let url = dir.appending(path: "\(fileName).xlsx")
            try buildXLSX(headers: headers, rows: rows).write(to: url, options: .atomic)
            return url
        case .pdf:
            return try exportEventVisitorsPDF(visitors, fileName: fileName)
        }
    }

    /// Bundles each visitor's scanned business card image into a ZIP, named
    /// after the visitor so staff can match images back to spreadsheet rows.
    /// Returns `nil` when no visitor in the list has a card image.
    func exportEventVisitorCardImagesZip(_ visitors: [EventVisitor], eventName: String) throws -> URL? {
        let withImages = visitors.filter { !$0.cardImagePath.isEmpty }
        guard !withImages.isEmpty else { return nil }

        var usedNames = Set<String>()
        let entries: [MinimalZipEntry] = withImages.compactMap { visitor in
            let url = FileManager.cardImagesDirectory().appending(path: visitor.cardImagePath)
            guard let data = try? Data(contentsOf: url) else { return nil }

            let baseName = sanitizedFileNameComponent(
                visitor.name.isEmpty ? String(localized: "note.untitled") : visitor.name
            )
            var entryName = "\(baseName).jpg"
            var suffix = 2
            while usedNames.contains(entryName) {
                entryName = "\(baseName)_\(suffix).jpg"
                suffix += 1
            }
            usedNames.insert(entryName)

            return MinimalZipEntry(name: entryName, data: data)
        }

        guard !entries.isEmpty else { return nil }

        let safeEventName = sanitizedFileNameComponent(eventName.isEmpty ? String(localized: "note.untitled") : eventName)
        let imagesLabel = String(localized: "eventMode.export.fileNameCardImages", defaultValue: "명함이미지")
        let dateString = DateFormatter.filenameDateOnly.string(from: .now)
        let url = URL.temporaryDirectory.appending(path: "\(safeEventName)_\(imagesLabel)_\(dateString).zip")
        try MinimalZipWriter.write(entries).write(to: url, options: .atomic)
        return url
    }

    private func wantsMaterialsText(_ value: Bool?) -> String {
        switch value {
        case true: String(localized: "action.yes", defaultValue: "예")
        case false: String(localized: "action.no", defaultValue: "아니오")
        case nil: ""
        }
    }

    private func sanitizedFileNameComponent(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return value.components(separatedBy: invalidCharacters).joined(separator: "_")
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

    /// Renders exactly one PDF page per card — the scanned card image followed
    /// by every entered field — so each page is self-contained and printable
    /// on its own, unlike the spreadsheet formats.
    private func exportBusinessCardsPDF(
        _ cards: [BusinessCard],
        fileName: String
    ) throws -> URL {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 36
        let contentWidth = pageBounds.width - margin * 2

        let ts = DateFormatter.filenameSafe.string(from: Date())
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("\(fileName)_\(ts).pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        try renderer.writePDF(to: url) { context in
            for card in cards {
                context.beginPage()
                drawBusinessCardPage(card, pageBounds: pageBounds, margin: margin, contentWidth: contentWidth)
            }
        }
        return url
    }

    /// Renders exactly one PDF page per visitor — their scanned card image (if
    /// any) followed by every entered field — matching the one-page-per-record
    /// business card PDF export.
    private func exportEventVisitorsPDF(
        _ visitors: [EventVisitor],
        fileName: String
    ) throws -> URL {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 36
        let contentWidth = pageBounds.width - margin * 2

        let dir = FileManager.default.temporaryDirectory
        let url = dir.appending(path: "\(fileName).pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        try renderer.writePDF(to: url) { context in
            for visitor in visitors {
                context.beginPage()
                drawEventVisitorPage(visitor, pageBounds: pageBounds, margin: margin, contentWidth: contentWidth)
            }
        }
        return url
    }

    private func drawBusinessCardPage(
        _ card: BusinessCard,
        pageBounds: CGRect,
        margin: CGFloat,
        contentWidth: CGFloat
    ) {
        let fields: [(label: String, value: String)] = [
            (String(localized: "export.header.name"), card.name),
            (String(localized: "export.header.phonetic", defaultValue: "Phonetic"), card.namePhonetic),
            (String(localized: "export.header.company"), card.company),
            (String(localized: "export.header.department"), card.department),
            (String(localized: "export.header.jobTitle"), card.jobTitle),
            (String(localized: "export.header.email"), card.email),
            (String(localized: "export.header.mobile"), card.phone),
            (String(localized: "export.header.office"), card.officePhone),
            (String(localized: "export.header.fax"), card.fax),
            (String(localized: "export.header.website"), card.website),
            (String(localized: "export.header.address"), card.address),
            (String(localized: "export.header.memo"), card.memo),
            (String(localized: "export.header.language"), card.scannedLanguage),
            (String(localized: "export.header.date"), DateFormatter.exportTimestamp.string(from: card.createdAt))
        ]

        drawRecordPage(
            title: card.name.isEmpty ? String(localized: "businessCard.name") : card.name,
            subtitle: [card.company, card.jobTitle].filter { !$0.isEmpty }.joined(separator: " · "),
            imagePath: card.imagePath,
            fields: fields,
            pageBounds: pageBounds,
            margin: margin,
            contentWidth: contentWidth
        )
    }

    private func drawEventVisitorPage(
        _ visitor: EventVisitor,
        pageBounds: CGRect,
        margin: CGFloat,
        contentWidth: CGFloat
    ) {
        let fields: [(label: String, value: String)] = [
            (String(localized: "export.header.name"), visitor.name),
            (String(localized: "export.header.company"), visitor.company),
            (String(localized: "export.header.jobTitle"), visitor.jobTitle),
            (String(localized: "export.header.email"), visitor.email),
            (String(localized: "export.header.mobile"), visitor.mobile),
            (String(localized: "export.header.phone", defaultValue: "전화번호"), visitor.phone),
            (String(localized: "export.header.country", defaultValue: "국가"),
             visitor.countryCode.isEmpty ? "" : EventCountry(code: visitor.countryCode).localizedName),
            (String(localized: "export.header.collectionMethod", defaultValue: "수집 방식"), visitor.collectionMethod.localizedName),
            (String(localized: "export.header.interestArea", defaultValue: "관심분야"), visitor.interestArea?.localizedName ?? ""),
            (String(localized: "export.header.wantsMaterials", defaultValue: "자료 요청"), wantsMaterialsText(visitor.wantsMaterials)),
            (String(localized: "export.header.memo"), visitor.memo),
            (String(localized: "export.header.registeredAt", defaultValue: "등록일시"), DateFormatter.exportTimestamp.string(from: visitor.createdAt))
        ]

        drawRecordPage(
            title: visitor.name.isEmpty ? String(localized: "note.untitled") : visitor.name,
            subtitle: [visitor.company, visitor.jobTitle].filter { !$0.isEmpty }.joined(separator: " · "),
            imagePath: visitor.cardImagePath,
            fields: fields,
            pageBounds: pageBounds,
            margin: margin,
            contentWidth: contentWidth
        )
    }

    /// Shared one-record-per-page layout: title, subtitle, the record's card
    /// image (if any), a divider, then every non-empty field as "label: value".
    /// Fields that would overflow the page are dropped rather than spilling
    /// onto a second page, since each record must stay exactly one page.
    private func drawRecordPage(
        title: String,
        subtitle: String,
        imagePath: String,
        fields: [(label: String, value: String)],
        pageBounds: CGRect,
        margin: CGFloat,
        contentWidth: CGFloat
    ) {
        let titleFont = UIFont.boldSystemFont(ofSize: 20)
        let subtitleFont = UIFont.systemFont(ofSize: 13)
        let labelFont = UIFont.boldSystemFont(ofSize: 11)
        let valueFont = UIFont.systemFont(ofSize: 12)
        let metaColor = UIColor.darkGray

        var y = margin

        title.draw(
            in: CGRect(x: margin, y: y, width: contentWidth, height: 28),
            withAttributes: [.font: titleFont]
        )
        y += 28

        if !subtitle.isEmpty {
            subtitle.draw(
                at: CGPoint(x: margin, y: y),
                withAttributes: [.font: subtitleFont, .foregroundColor: metaColor]
            )
            y += 20
        }
        y += 8

        if !imagePath.isEmpty {
            let imageURL = FileManager.cardImagesDirectory().appendingPathComponent(imagePath)
            if let image = UIImage(contentsOfFile: imageURL.path), image.size.width > 0, image.size.height > 0 {
                let maxImageHeight: CGFloat = 220
                let aspectRatio = image.size.width / image.size.height
                var drawWidth = contentWidth
                var drawHeight = drawWidth / aspectRatio
                if drawHeight > maxImageHeight {
                    drawHeight = maxImageHeight
                    drawWidth = drawHeight * aspectRatio
                }
                image.draw(in: CGRect(x: margin, y: y, width: drawWidth, height: drawHeight))
                y += drawHeight + 16
            }
        }

        let dividerPath = UIBezierPath()
        dividerPath.move(to: CGPoint(x: margin, y: y))
        dividerPath.addLine(to: CGPoint(x: pageBounds.width - margin, y: y))
        dividerPath.lineWidth = 0.5
        UIColor.lightGray.setStroke()
        dividerPath.stroke()
        y += 16

        let labelWidth: CGFloat = 90
        let valueWidth = contentWidth - labelWidth - 8
        let valueAttributes: [NSAttributedString.Key: Any] = [.font: valueFont]

        for field in fields {
            guard !field.value.isEmpty else { continue }
            let boundingHeight = (field.value as NSString).boundingRect(
                with: CGSize(width: valueWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: valueAttributes,
                context: nil
            ).height
            let rowHeight = max(16, ceil(boundingHeight) + 4)

            guard y + rowHeight <= pageBounds.height - margin else { break }

            field.label.draw(
                at: CGPoint(x: margin, y: y),
                withAttributes: [.font: labelFont, .foregroundColor: metaColor]
            )
            (field.value as NSString).draw(
                with: CGRect(x: margin + labelWidth, y: y, width: valueWidth, height: rowHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: valueAttributes,
                context: nil
            )
            y += rowHeight + 6
        }
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
