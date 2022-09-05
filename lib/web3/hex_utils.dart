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

  static int? hexToInt(String hex) {
    int? val;
    if (hex.toUpperCase().contains("0X")) {
      String desString = hex.substring(2);
      val = int.tryParse("0x$desString");
    } else {
      val = int.tryParse("0x$hex");
    }
    return val;
  }

  static String bytesToHex(
    List<int> bytes, {
    bool include0x = false,
    bool padToEvenLength = true,
  }) {
    var encoded = hex.encode(bytes);
    if (padToEvenLength && encoded.length % 2 != 0) {
      encoded = '0$encoded';
    }
    return (include0x ? '0x' : '') + encoded;
  }
}
