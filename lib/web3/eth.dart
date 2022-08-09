import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_trust_wallet_core/protobuf/Ethereum.pb.dart'
    as Ethereum;
import 'package:flutter_trust_wallet_core/web3/hex_utils.dart';
import 'package:flutter_trust_wallet_core/web3/http_helper.dart';

import '../flutter_trust_wallet_core.dart';
import '../trust_wallet_core_ffi.dart';

class EthHelper {
  late final String url;
  late final int chainId;
  final methodSendTx = "eth_sendRawTransaction";

  EthHelper(String _url, int _chainId) {
    url = _url;
    chainId = _chainId;
  }

  transferEth(String to, BigInt value, BigInt gasPrice, BigInt nonce,
      BigInt gasLimit, String privateKey) async {
    int coin = TWCoinType.TWCoinTypeEthereum;
    var pk =
        PrivateKey.createWithData(Uint8List.fromList(hex.decode(privateKey)));
    var publicKeyFalse = pk.getPublicKeySecp256k1(false);
    var from = AnyAddress.createWithPublicKey(publicKeyFalse, coin);
    var signerInput = Ethereum.SigningInput(
        chainId: HexUtils.int2Bytes(BigInt.from(this.chainId)),
        nonce: HexUtils.int2Bytes(nonce),
        toAddress: to,
        gasLimit: HexUtils.int2Bytes(gasLimit),
        transaction: Ethereum.Transaction(
            transfer: Ethereum.Transaction_Transfer(
                amount: HexUtils.int2Bytes(value))),
        gasPrice: HexUtils.int2Bytes(gasPrice),
        privateKey: pk.data());
    final signed = AnySigner.sign(
      signerInput.writeToBuffer(),
      coin,
    );
    final output = Ethereum.SigningOutput.fromBuffer(signed);
    final signTx = hex.encode(output.encoded);
    return HttpHelper.sendRpc(this.url, methodSendTx, signTx);
  }

  transferErc20(String token, String to, BigInt amount, BigInt gasPrice,
      BigInt nonce, BigInt gasLimit, String privateKey) async {
    int coin = TWCoinType.TWCoinTypeEthereum;
    var pk =
        PrivateKey.createWithData(Uint8List.fromList(hex.decode(privateKey)));
    var publicKeyFalse = pk.getPublicKeySecp256k1(false);
    var from = AnyAddress.createWithPublicKey(publicKeyFalse, coin);
    var signerInput = Ethereum.SigningInput(
        chainId: HexUtils.int2Bytes(BigInt.from(this.chainId)),
        nonce: HexUtils.int2Bytes(nonce),
        toAddress: token,
        gasLimit: HexUtils.int2Bytes(gasLimit),
        transaction: Ethereum.Transaction(
            erc20Transfer: Ethereum.Transaction_ERC20Transfer(
                to: to, amount: HexUtils.int2Bytes(amount))),
        gasPrice: HexUtils.int2Bytes(gasPrice),
        privateKey: pk.data());
    final signed = AnySigner.sign(
      signerInput.writeToBuffer(),
      coin,
    );
    final output = Ethereum.SigningOutput.fromBuffer(signed);
    final signTx = hex.encode(output.encoded);
    return HttpHelper.sendRpc(this.url, methodSendTx, signTx);
  }
}
