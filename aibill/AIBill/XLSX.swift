import Foundation

enum XLSX {
    static func file(from txns: [Txn]) -> URL? {
        guard !txns.isEmpty else { return nil }
        let workbook = archive([
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("_rels/.rels", Data(rootRels.utf8)),
            ("xl/workbook.xml", Data(workbookXML.utf8)),
            ("xl/_rels/workbook.xml.rels", Data(workbookRels.utf8)),
            ("xl/styles.xml", Data(stylesXML.utf8)),
            ("xl/worksheets/sheet1.xml", Data(sheetXML(txns).utf8)),
        ])

        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("智账-\(stamp.string(from: Date())).xlsx")

        do {
            try workbook.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Sheet

    private static let columns = ["A", "B", "C", "D", "E", "F", "G", "H"]

    private static func sheetXML(_ txns: [Txn]) -> String {
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        let time = DateFormatter()
        time.locale = Locale(identifier: "en_US_POSIX")
        time.dateFormat = "HH:mm"

        let header = ["日期", "时间", "类型", "金额", "分类", "账户", "商户", "备注"]
        var rows: [String] = []

        let headerCells = header.enumerated()
            .map { cell(columns[$0.offset] + "1", $0.element, style: 1) }
            .joined()
        rows.append("<row r=\"1\">\(headerCells)</row>")

        let sorted = txns.sorted { $0.date < $1.date }
        for (i, t) in sorted.enumerated() {
            let r = i + 2
            var line = ""
            line += cell("A\(r)", day.string(from: t.date))
            line += cell("B\(r)", time.string(from: t.date))
            line += cell("C\(r)", t.amount < 0 ? "收入" : "支出")
            line += numberCell("D\(r)", t.amount)
            line += cell("E\(r)", t.category)
            line += cell("F\(r)", t.account)
            line += cell("G\(r)", t.merchant)
            line += cell("H\(r)", t.note)
            rows.append("<row r=\"\(r)\">\(line)</row>")
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>
        <cols>
        <col min="1" max="1" width="12" customWidth="1"/>
        <col min="2" max="2" width="8" customWidth="1"/>
        <col min="3" max="3" width="8" customWidth="1"/>
        <col min="4" max="4" width="12" customWidth="1"/>
        <col min="5" max="5" width="10" customWidth="1"/>
        <col min="6" max="6" width="10" customWidth="1"/>
        <col min="7" max="7" width="26" customWidth="1"/>
        <col min="8" max="8" width="32" customWidth="1"/>
        </cols>
        <sheetData>\(rows.joined())</sheetData>
        </worksheet>
        """
    }

    private static func cell(_ ref: String, _ text: String, style: Int = 0) -> String {
        "<c r=\"\(ref)\" t=\"inlineStr\" s=\"\(style)\"><is><t xml:space=\"preserve\">\(escape(text))</t></is></c>"
    }

    private static func numberCell(_ ref: String, _ value: Double) -> String {
        let v = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
        return "<c r=\"\(ref)\" s=\"2\"><v>\(v)</v></c>"
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "\u{0000}", with: "")
    }

    // MARK: - Package parts

    private static let contentTypes = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
    <Default Extension="xml" ContentType="application/xml"/>
    <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
    <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
    <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
    </Types>
    """

    private static let rootRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
    </Relationships>
    """

    private static let workbookXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
    <sheets><sheet name="账目" sheetId="1" r:id="rId1"/></sheets>
    </workbook>
    """

    private static let workbookRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
    <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
    </Relationships>
    """

    private static let stylesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
    <fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>
    <fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFE8F0FE"/><bgColor indexed="64"/></patternFill></fill></fills>
    <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
    <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
    <cellXfs count="3">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>
    <xf numFmtId="4" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
    </cellXfs>
    </styleSheet>
    """

    // MARK: - ZIP (store only)

    private static let crcTable: [UInt32] = (0..<256).map { i in
        var c = UInt32(i)
        for _ in 0..<8 {
            c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
        }
        return c
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        for byte in data {
            c = crcTable[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8)
        }
        return c ^ 0xFFFFFFFF
    }

    private static func archive(_ files: [(String, Data)]) -> Data {
        var out = Data()
        var central = Data()
        let (dosTime, dosDate) = dosStamp()

        for (fileName, fileData) in files {
            let name = Array(fileName.utf8)
            let crc = crc32(fileData)
            let size = UInt32(fileData.count)
            let offset = UInt32(out.count)

            out.append(contentsOf: [0x50, 0x4B, 0x03, 0x04])
            out.le16(20)
            out.le16(0x0800)
            out.le16(0)
            out.le16(dosTime)
            out.le16(dosDate)
            out.le32(crc)
            out.le32(size)
            out.le32(size)
            out.le16(UInt16(name.count))
            out.le16(0)
            out.append(contentsOf: name)
            out.append(fileData)

            central.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])
            central.le16(20)
            central.le16(20)
            central.le16(0x0800)
            central.le16(0)
            central.le16(dosTime)
            central.le16(dosDate)
            central.le32(crc)
            central.le32(size)
            central.le32(size)
            central.le16(UInt16(name.count))
            central.le16(0)
            central.le16(0)
            central.le16(0)
            central.le16(0)
            central.le32(0)
            central.le32(offset)
            central.append(contentsOf: name)
        }

        let cdOffset = UInt32(out.count)
        out.append(central)
        out.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])
        out.le16(0)
        out.le16(0)
        out.le16(UInt16(files.count))
        out.le16(UInt16(files.count))
        out.le32(UInt32(central.count))
        out.le32(cdOffset)
        out.le16(0)
        return out
    }

    private static func dosStamp() -> (UInt16, UInt16) {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        let year = UInt16(max(1980, c.year ?? 2020) - 1980)
        let month = UInt16(c.month ?? 1)
        let day = UInt16(c.day ?? 1)
        let hour = UInt16(c.hour ?? 0)
        let minute = UInt16(c.minute ?? 0)
        let second = UInt16((c.second ?? 0) / 2)
        return ((hour << 11) | (minute << 5) | second, (year << 9) | (month << 5) | day)
    }
}

private extension Data {
    mutating func le16(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func le32(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}
