import 'dart:typed_data';

import 'package:convert/convert.dart';

class HexUtils {
  static String strip0x(String hex) {
    if (hex.startsWith('0x')) return hex.substring(2);
    return hex;
  }

  static Uint8List hexToBytes(String hexStr) {
    if (hexStr.length % 2 != 0) {
      hexStr = '0$hexStr';
    }
    final bytes = hex.decode(strip0x(hexStr));
    if (bytes is Uint8List) return bytes;
    return Uint8List.fromList(bytes);
  }

  static int2Bytes(BigInt num) {
    var _hex = num.toRadixString(16);
    if (_hex.length % 2 != 0) {
      _hex = '0$_hex';
    }
    return hex.decode(_hex);
  }

  static String bytesToHex(
    List<int> bytes, {
    bool include0x = false,
    int? forcePadLength,
    bool padToEvenLength = false,
  }) {
    var encoded = hex.encode(bytes);

    if (forcePadLength != null) {
      assert(forcePadLength >= encoded.length);

      final padding = forcePadLength - encoded.length;
      encoded = ('0' * padding) + encoded;
    }

    if (padToEvenLength && encoded.length % 2 != 0) {
      encoded = '0$encoded';
    }

    return (include0x ? '0x' : '') + encoded;
  }
}
