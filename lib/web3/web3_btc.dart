import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_trust_wallet_core/flutter_trust_wallet_core.dart';
import 'package:flutter_trust_wallet_core/trust_wallet_core_ffi.dart';

import 'package:flutter_trust_wallet_core/protobuf/Bitcoin.pb.dart' as Bitcoin;
import 'package:fixnum/fixnum.dart' as $fixed_num;
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
  late final int coin;

  Web3Btc(String endpoint, bool isTestNet) {
    if (isTestNet) {
      coin = TWCoinType.TWCoinTypeBitcoinTestnet;
    } else {
      coin = TWCoinType.TWCoinTypeBitcoin;
    }
    url = endpoint;
  }

  calcSendFee(String from, String exchangeAddress, String to, BigInt amount,
      BigInt byteFee, List<Web3BtcUTXO> utxos) {
    final script =
    BitcoinScript.lockScriptForAddress(from, coin).data().toList();
    List<Bitcoin.UnspentTransaction> utxo = [];
    for (var element in utxos) {
      utxo.add(Bitcoin.UnspentTransaction(
        amount: $fixed_num.Int64.parseInt(element.value.toString()),
        outPoint: Bitcoin.OutPoint(
          hash: hex.decode(element.txid).reversed.toList(),
          index: element.vout,
        ),
        script: script,
      ));
    }
    final signingInput = Bitcoin.SigningInput(
      amount: $fixed_num.Int64.parseInt(amount.toString()),
      hashType: BitcoinScript.hashTypeForCoin(coin),
      toAddress: to,
      changeAddress: exchangeAddress,
      byteFee: $fixed_num.Int64.parseInt(byteFee.toString()),
      coinType: coin,
      utxo: utxo,
    );
    final transactionPlan = Bitcoin.TransactionPlan.fromBuffer(
        AnySigner.signerPlan(signingInput.writeToBuffer(), coin).toList());
    return {
      "amount": transactionPlan.amount,
      "fee": transactionPlan.fee,
      "change": transactionPlan.change,
    };
  }

  send(String from, String exchangeAddress, String to, BigInt amount,
      BigInt byteFee, List<Web3BtcUTXO> utxos, String wif) {
    final pk = PrivateKey.createWithData(
        Uint8List.fromList(hex.decode(WIF.decode(wif)!).toList()));
    final script =
    BitcoinScript.lockScriptForAddress(from, coin).data().toList();
    List<Bitcoin.UnspentTransaction> utxo = [];
    for (var element in utxos) {
      utxo.add(Bitcoin.UnspentTransaction(
        amount: $fixed_num.Int64.parseInt(element.value.toString()),
        outPoint: Bitcoin.OutPoint(
          hash: hex.decode(element.txid).reversed.toList(),
          index: element.vout,
        ),
        script: script,
      ));
    }

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
    final sign = AnySigner.sign(signingInput.writeToBuffer(), coin);
    final output = Bitcoin.SigningOutput.fromBuffer(sign);
    final signTx = hex.encode(output.encoded);
    return HttpHelper.sendRpc(url, "sendrawtransaction", signTx);
  }
}

