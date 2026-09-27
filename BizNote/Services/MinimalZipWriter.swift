import Foundation

struct MinimalZipEntry {
    let name: String
    let data: Data
}

/// Writes a minimal ZIP archive using the stored method.
/// This is enough to produce an OOXML .xlsx file without third-party dependencies.
enum MinimalZipWriter {
    static func write(_ entries: [MinimalZipEntry]) -> Data {
        var output = Data()
        var centralDirectory = Data()
        var records: [(name: [UInt8], offset: UInt32, crc: UInt32, size: UInt32)] = []

        for entry in entries {
            let nameBytes = Array(entry.name.utf8)
            let fileBytes = [UInt8](entry.data)
            let crc = crc32(fileBytes)
            let offset = UInt32(output.count)

            output.append(le32(0x04034b50))
            output.append(le16(20))
            output.append(le16(0))
            output.append(le16(0))
            output.append(le16(0))
            output.append(le16(0))
            output.append(le32(crc))
            output.append(le32(UInt32(fileBytes.count)))
            output.append(le32(UInt32(fileBytes.count)))
            output.append(le16(UInt16(nameBytes.count)))
            output.append(le16(0))
            output.append(Data(nameBytes))
            output.append(Data(fileBytes))

            records.append((nameBytes, offset, crc, UInt32(fileBytes.count)))
        }

        for record in records {
            centralDirectory.append(le32(0x02014b50))
            centralDirectory.append(le16(20))
            centralDirectory.append(le16(20))
            centralDirectory.append(le16(0))
            centralDirectory.append(le16(0))
            centralDirectory.append(le16(0))
            centralDirectory.append(le16(0))
            centralDirectory.append(le32(record.crc))
            centralDirectory.append(le32(record.size))
            centralDirectory.append(le32(record.size))
            centralDirectory.append(le16(UInt16(record.name.count)))
            centralDirectory.append(le16(0))
            centralDirectory.append(le16(0))
            centralDirectory.append(le16(0))
            centralDirectory.append(le16(0))
            centralDirectory.append(le32(0))
            centralDirectory.append(le32(record.offset))
            centralDirectory.append(Data(record.name))
        }

        var end = Data()
        end.append(le32(0x06054b50))
        end.append(le16(0))
        end.append(le16(0))
        end.append(le16(UInt16(records.count)))
        end.append(le16(UInt16(records.count)))
        end.append(le32(UInt32(centralDirectory.count)))
        end.append(le32(UInt32(output.count)))
        end.append(le16(0))

        output.append(centralDirectory)
        output.append(end)
        return output
    }

    private static func le16(_ value: UInt16) -> Data {
        Data([UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)])
    }

    private static func le32(_ value: UInt32) -> Data {
        Data([
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF)
        ])
    }

    private static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in bytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
        }
        return ~crc
    }
}
