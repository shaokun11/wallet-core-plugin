import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_trust_wallet_core/flutter_trust_wallet_core.dart';
import 'package:flutter_trust_wallet_core/trust_wallet_core_ffi.dart';

import 'package:flutter_trust_wallet_core/protobuf/Bitcoin.pb.dart' as Bitcoin;
import 'package:fixnum/fixnum.dart' as $fixed_num;
import 'package:flutter_trust_wallet_core/web3/hex_utils.dart';
import '../protobuf/Bitcoin.pb.dart';
import 'btc_wif.dart';
import 'http_helper.dart';

class Web3BtcUTXO {
  const Web3BtcUTXO(this.txid, this.vout, this.value);

  final String txid;
  final int vout;
  final BigInt value;
}

class Web3Btc {
  late final String url;
  late final String url2;
  late final int coin;

  Web3Btc(
    String url,
    bool isTestNet, {
    String? url2_,
  }) {
    this.url = url;
    if (isTestNet) {
      coin = TWCoinType.TWCoinTypeBitcoinTestnet;
    } else {
      coin = TWCoinType.TWCoinTypeBitcoin;
    }
    if (url2_ != null) {
      if (isTestNet) {
        this.url2 = "https://mempool.space/testnet/api";
      } else {
        this.url2 = "https://mempool.space/api";
      }
    }
  }

  getUTXO(String address) async {
    final url = this.url2 + "/$address/utxo";
    final result = await HttpHelper.get(url);
    return result;
  }

  calcSendFee(String from, String exchangeAddress, String to, BigInt amount,
      BigInt byteFee, List<Web3BtcUTXO> utxos, String wif) {
    final pk = PrivateKey.createWithData(
        Uint8List.fromList(hex.decode(WIF.decode(wif)!).toList()));
    final script =
        BitcoinScript.lockScriptForAddress(from, coin).data().toList();
    List<UnspentTransaction> utxo = [];
    utxos.forEach((element) {
      utxo.add(Bitcoin.UnspentTransaction(
        amount: $fixed_num.Int64.parseInt(element.value.toString()),
        outPoint: Bitcoin.OutPoint(
          hash: hex.decode(element.txid).reversed.toList(),
          index: element.vout,
        ),
        script: script,
      ));
    });

    final signingInput = Bitcoin.SigningInput(
      amount: $fixed_num.Int64.parseInt(amount.toString()),
      hashType: BitcoinScript.hashTypeForCoin(coin),
      toAddress: to,
      changeAddress: exchangeAddress,
      byteFee: $fixed_num.Int64.parseInt(byteFee.toString()),
      coinType: coin,
      utxo: utxo,
      privateKey: [pk.data().toList()],
    );
    final transactionPlan = Bitcoin.TransactionPlan.fromBuffer(
        AnySigner.signerPlan(signingInput.writeToBuffer(), coin).toList());
    return json.encode({
      "input": HexUtils.bytesToHex(signingInput.writeToBuffer()),
      "amount": transactionPlan.amount,
      "fee": transactionPlan.fee,
      "change": transactionPlan.change,
    });
  }

  send(String input) {
    final sign = AnySigner.sign(HexUtils.hexToBytes(input), coin);
    final output = Bitcoin.SigningOutput.fromBuffer(sign);
    final signTx = hex.encode(output.encoded);
    return HttpHelper.sendRpc(url, "sendrawtransaction", signTx);
  }
}
