import 'dart:io';
import 'dart:typed_data';

/// Pure-Dart binary delta patcher (`LDGDIFF1` format).
///
/// Uses a 64-byte rolling hash index over [oldBytes] with backward/forward
/// exact-match extension, emitting `COPY` / `INSERT` opcodes compressed with
/// gzip. Designed for self-hosted Android APK delta updates.
class ApkDelta {
  static const List<int> magic = [0x4C, 0x44, 0x47, 0x44, 0x49, 0x46, 0x46, 0x31]; // "LDGDIFF1"
  static const int headerSize = 16; // 8-byte magic + 8-byte uint64 newSize
  static const int _opEof = 0x00;
  static const int _opCopy = 0x01;
  static const int _opInsert = 0x02;

  static const int _blockSize = 64;
  static const int _base = 257;
  static const int _mask = 0xFFFFFFFF;

  static final int _basePow = _computeBasePow(_blockSize - 1);

  static int _computeBasePow(int exp) {
    int res = 1;
    for (int i = 0; i < exp; i++) {
      res = (res * _base) & _mask;
    }
    return res;
  }

  /// Creates a compressed `LDGDIFF1` binary patch transforming [oldBytes] into [newBytes].
  static Uint8List createPatch(Uint8List oldBytes, Uint8List newBytes) {
    final ops = BytesBuilder(copy: false);
    final oldLen = oldBytes.length;
    final newLen = newBytes.length;

    if (oldLen < _blockSize || newLen < _blockSize) {
      if (newLen > 0) {
        _writeInsert(ops, newBytes, 0, newLen);
      }
      ops.addByte(_opEof);
      return _finalizePatch(newLen, ops.takeBytes());
    }

    // Index non-overlapping _blockSize chunks of oldBytes using 32-bit rolling hash.
    final Map<int, int> index = <int, int>{};
    for (int pos = 0; pos + _blockSize <= oldLen; pos += _blockSize) {
      final h = _hashWindow(oldBytes, pos);
      index.putIfAbsent(h, () => pos);
    }

    int literalStart = 0;
    int i = 0;
    int hash = _hashWindow(newBytes, 0);
    bool hashValid = true;

    while (i + _blockSize <= newLen) {
      if (!hashValid) {
        hash = _hashWindow(newBytes, i);
        hashValid = true;
      }

      final oldPos = index[hash];
      if (oldPos != null && _windowsEqual(oldBytes, oldPos, newBytes, i)) {
        // Extend match backward up to literalStart.
        int matchOldStart = oldPos;
        int matchNewStart = i;
        while (matchOldStart > 0 &&
            matchNewStart > literalStart &&
            oldBytes[matchOldStart - 1] == newBytes[matchNewStart - 1]) {
          matchOldStart--;
          matchNewStart--;
        }

        // Extend match forward as far as bytes match.
        int matchOldEnd = oldPos + _blockSize;
        int matchNewEnd = i + _blockSize;
        while (matchOldEnd < oldLen &&
            matchNewEnd < newLen &&
            oldBytes[matchOldEnd] == newBytes[matchNewEnd]) {
          matchOldEnd++;
          matchNewEnd++;
        }

        // Flush any preceding unmatched bytes as INSERT.
        if (matchNewStart > literalStart) {
          _writeInsert(ops, newBytes, literalStart, matchNewStart - literalStart);
        }

        // Emit COPY opcode.
        _writeCopy(ops, matchOldStart, matchNewEnd - matchNewStart);

        i = matchNewEnd;
        literalStart = matchNewEnd;
        hashValid = false;
      } else {
        // Slide rolling hash by 1 byte in O(1).
        if (i + _blockSize < newLen) {
          final outByte = newBytes[i];
          final inByte = newBytes[i + _blockSize];
          hash = (hash - ((outByte * _basePow) & _mask)) & _mask;
          hash = ((hash * _base) + inByte) & _mask;
        }
        i++;
      }
    }

    // Flush trailing unmatched bytes.
    if (literalStart < newLen) {
      _writeInsert(ops, newBytes, literalStart, newLen - literalStart);
    }

    ops.addByte(_opEof);
    return _finalizePatch(newLen, ops.takeBytes());
  }

  /// Applies a `LDGDIFF1` [patchBytes] to [oldBytes] and returns the exact reconstructed bytes.
  static Uint8List applyPatch(Uint8List oldBytes, Uint8List patchBytes) {
    if (patchBytes.length < headerSize) {
      throw const FormatException('Patch file is too small to contain header.');
    }

    for (int i = 0; i < magic.length; i++) {
      if (patchBytes[i] != magic[i]) {
        throw const FormatException('Invalid patch magic header.');
      }
    }

    final headerData = ByteData.sublistView(patchBytes, 0, headerSize);
    final newSize = headerData.getUint64(8, Endian.little);
    if (newSize < 0) {
      throw const FormatException('Invalid target size in patch header.');
    }

    final compressedBody = Uint8List.sublistView(patchBytes, headerSize);
    final rawOps = Uint8List.fromList(gzip.decode(compressedBody));
    final opsData = ByteData.sublistView(rawOps);

    final out = Uint8List(newSize);
    int outPos = 0;
    int pos = 0;
    bool sawEof = false;

    while (pos < rawOps.length) {
      final op = rawOps[pos++];
      if (op == _opEof) {
        sawEof = true;
        break;
      } else if (op == _opCopy) {
        if (pos + 8 > rawOps.length) {
          throw const FormatException('Truncated COPY opcode in patch.');
        }
        final oldOffset = opsData.getUint32(pos, Endian.little);
        final length = opsData.getUint32(pos + 4, Endian.little);
        pos += 8;

        if (oldOffset + length > oldBytes.length) {
          throw FormatException(
            'COPY out of bounds (offset=$oldOffset, len=$length, oldLen=${oldBytes.length}).',
          );
        }
        if (outPos + length > newSize) {
          throw FormatException(
            'Output overflow during COPY (outPos=$outPos, len=$length, newSize=$newSize).',
          );
        }

        out.setRange(outPos, outPos + length, oldBytes, oldOffset);
        outPos += length;
      } else if (op == _opInsert) {
        if (pos + 4 > rawOps.length) {
          throw const FormatException('Truncated INSERT opcode in patch.');
        }
        final length = opsData.getUint32(pos, Endian.little);
        pos += 4;

        if (pos + length > rawOps.length) {
          throw const FormatException('Truncated INSERT payload in patch.');
        }
        if (outPos + length > newSize) {
          throw FormatException(
            'Output overflow during INSERT (outPos=$outPos, len=$length, newSize=$newSize).',
          );
        }

        out.setRange(outPos, outPos + length, rawOps, pos);
        pos += length;
        outPos += length;
      } else {
        throw FormatException('Unknown patch opcode: 0x${op.toRadixString(16)}');
      }
    }

    if (!sawEof) {
      throw const FormatException('Patch stream missing EOF marker.');
    }
    if (outPos != newSize) {
      throw FormatException(
        'Reconstructed size mismatch: expected $newSize bytes, got $outPos.',
      );
    }

    return out;
  }

  static int _hashWindow(Uint8List data, int offset) {
    int h = 0;
    final end = offset + _blockSize;
    for (int j = offset; j < end; j++) {
      h = ((h * _base) + data[j]) & _mask;
    }
    return h;
  }

  static bool _windowsEqual(Uint8List a, int aOff, Uint8List b, int bOff) {
    for (int k = 0; k < _blockSize; k++) {
      if (a[aOff + k] != b[bOff + k]) return false;
    }
    return true;
  }

  static void _writeCopy(BytesBuilder builder, int oldOffset, int length) {
    final buf = Uint8List(9);
    buf[0] = _opCopy;
    final bd = ByteData.sublistView(buf);
    bd.setUint32(1, oldOffset, Endian.little);
    bd.setUint32(5, length, Endian.little);
    builder.add(buf);
  }

  static void _writeInsert(
    BytesBuilder builder,
    Uint8List source,
    int offset,
    int length,
  ) {
    final header = Uint8List(5);
    header[0] = _opInsert;
    ByteData.sublistView(header).setUint32(1, length, Endian.little);
    builder.add(header);
    builder.add(Uint8List.sublistView(source, offset, offset + length));
  }

  static Uint8List _finalizePatch(int newSize, Uint8List rawOps) {
    final compressed = GZipCodec(level: 6).encode(rawOps);
    final result = Uint8List(headerSize + compressed.length);
    result.setRange(0, magic.length, magic);
    ByteData.sublistView(result, 0, headerSize)
        .setUint64(8, newSize, Endian.little);
    result.setRange(headerSize, result.length, compressed);
    return result;
  }
}
