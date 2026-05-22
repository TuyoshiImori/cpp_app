import Foundation
import zlib

/// 最小限の ZIP ファイル生成クラス（圧縮なし・stored のみ）
/// ZIP 仕様: PKZIP Application Note 6.3.10 準拠
final class ZipWriter {
  private struct Entry {
    let path: String
    let data: Data
    let crc32: UInt32
    let localHeaderOffset: UInt32
  }

  private var entries: [Entry] = []
  private var buffer: Data = Data()

  /// ファイルを追加する
  /// - Parameters:
  ///   - data: ファイルの内容
  ///   - path: ZIP 内のパス（例: "page_001/answers.json"）
  func addFile(data: Data, path: String) {
    let crc = crc32Value(data)
    let offset = UInt32(buffer.count)
    let entry = Entry(path: path, data: data, crc32: crc, localHeaderOffset: offset)
    entries.append(entry)
    buffer.append(contentsOf: makeLocalHeader(entry: entry))
    buffer.append(data)
  }

  /// ZIP バイナリを返す
  func finalize() -> Data {
    let cdOffset = UInt32(buffer.count)
    var cdData = Data()
    for entry in entries {
      cdData.append(contentsOf: makeCentralDirectoryHeader(entry: entry))
    }
    buffer.append(cdData)
    buffer.append(contentsOf: makeEndOfCentralDirectory(
      entryCount: UInt16(entries.count),
      cdSize: UInt32(cdData.count),
      cdOffset: cdOffset
    ))
    return buffer
  }

  // MARK: - Private helpers

  private func crc32Value(_ data: Data) -> UInt32 {
    return data.withUnsafeBytes { ptr in
      guard let base = ptr.baseAddress else { return 0 }
      return UInt32(zlib.crc32(0, base.assumingMemoryBound(to: UInt8.self), uInt(data.count)))
    }
  }

  private func dosDateTime() -> (time: UInt16, date: UInt16) {
    let now = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
    let year = max(0, (now.year ?? 1980) - 1980)
    let month = now.month ?? 1
    let day = now.day ?? 1
    let hour = now.hour ?? 0
    let minute = now.minute ?? 0
    let second = (now.second ?? 0) / 2
    let time = UInt16((hour << 11) | (minute << 5) | second)
    let date = UInt16((year << 9) | (month << 5) | day)
    return (time, date)
  }

  private func makeLocalHeader(entry: Entry) -> [UInt8] {
    let (time, date) = dosDateTime()
    let nameBytes = Array(entry.path.utf8)
    let size = UInt32(entry.data.count)
    var h = [UInt8]()
    h += bytes(UInt32(0x04034b50))  // local file header signature
    h += bytes(UInt16(20))          // version needed to extract (2.0)
    h += bytes(UInt16(0))           // general purpose bit flag
    h += bytes(UInt16(0))           // compression method: stored
    h += bytes(time)
    h += bytes(date)
    h += bytes(entry.crc32)
    h += bytes(size)                // compressed size = uncompressed
    h += bytes(size)                // uncompressed size
    h += bytes(UInt16(nameBytes.count))
    h += bytes(UInt16(0))           // extra field length
    h += nameBytes
    return h
  }

  private func makeCentralDirectoryHeader(entry: Entry) -> [UInt8] {
    let (time, date) = dosDateTime()
    let nameBytes = Array(entry.path.utf8)
    let size = UInt32(entry.data.count)
    var h = [UInt8]()
    h += bytes(UInt32(0x02014b50))  // central directory signature
    h += bytes(UInt16(20))          // version made by
    h += bytes(UInt16(20))          // version needed to extract
    h += bytes(UInt16(0))           // general purpose bit flag
    h += bytes(UInt16(0))           // compression method: stored
    h += bytes(time)
    h += bytes(date)
    h += bytes(entry.crc32)
    h += bytes(size)                // compressed size
    h += bytes(size)                // uncompressed size
    h += bytes(UInt16(nameBytes.count))
    h += bytes(UInt16(0))           // extra field length
    h += bytes(UInt16(0))           // file comment length
    h += bytes(UInt16(0))           // disk number start
    h += bytes(UInt16(0))           // internal file attributes
    h += bytes(UInt32(0))           // external file attributes
    h += bytes(entry.localHeaderOffset)
    h += nameBytes
    return h
  }

  private func makeEndOfCentralDirectory(entryCount: UInt16, cdSize: UInt32, cdOffset: UInt32) -> [UInt8] {
    var h = [UInt8]()
    h += bytes(UInt32(0x06054b50))  // end of central directory signature
    h += bytes(UInt16(0))           // disk number
    h += bytes(UInt16(0))           // disk with start of central directory
    h += bytes(entryCount)          // entries on this disk
    h += bytes(entryCount)          // total entries
    h += bytes(cdSize)
    h += bytes(cdOffset)
    h += bytes(UInt16(0))           // comment length
    return h
  }

  // リトルエンディアンのバイト列に変換するヘルパー
  private func bytes<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
    withUnsafeBytes(of: value.littleEndian) { Array($0) }
  }
}
