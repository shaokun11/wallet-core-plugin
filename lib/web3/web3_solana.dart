import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_trust_wallet_core/protobuf/Solana.pb.dart' as Solana;
import 'package:flutter_trust_wallet_core/web3/http_helper.dart';
import 'package:solana/metaplex.dart';
import 'package:solana/solana.dart';
import '../flutter_trust_wallet_core.dart';
import '../trust_wallet_core_ffi.dart';
import 'package:fixnum/fixnum.dart' as $fixed_num;

class Web3Solana {
  late final String url;
  int coin = TWCoinType.TWCoinTypeSolana;
  late RpcClient client;

  Web3Solana(String url) {
    this.url = url;
    this.client = RpcClient(url);
  }

  PrivateKey _hexToPrivateKey(String privateKey) {
    return PrivateKey.createWithData(
        Uint8List.fromList(hex.decode(privateKey)));
  }

  getNonce() {
    return HttpHelper.sendRpc(url, "getRecentBlockhash", '');
  }

  getSOLBalance(String account) {
    return HttpHelper.sendRpc(url, "getBalance", account);
  }

  getSPLTokenBalance(String account, String token) {
    var tokenAddress =
        SolanaAddress.createWithString(account).defaultTokenAddress(token);
    return HttpHelper.sendRpc(url, "getTokenAccountBalance", tokenAddress!);
  }

  getTokenMetadata(String token) {
    GetMetaplexMetadata(client)
        .getMetadata(mint: Ed25519HDPublicKey.fromBase58(token));
  }

  sendSOl(String nonce, String to, BigInt amount, String privateKey) {
    final pk = _hexToPrivateKey(privateKey);
    final signInput = Solana.SigningInput(
        recentBlockhash: nonce,
        privateKey: pk.data().toList(),
        transferTransaction: Solana.Transfer(
            recipient: to,
            value: $fixed_num.Int64.parseInt(amount.toString())));
    final sign = AnySigner.sign(signInput.writeToBuffer(), coin);
    final signOutput = Solana.SigningOutput.fromBuffer(sign.toList());
    final signTx = signOutput.encoded;
    return HttpHelper.sendRpc(url, "sendTransaction", signTx);
  }

  sendToken(String from, String to, String token, BigInt amount, int decimals,
      String nonce, String privateKey) {
    var fromTokenAddress =
        SolanaAddress.createWithString(from).defaultTokenAddress(token);
    var toTokenAddress =
        SolanaAddress.createWithString(to).defaultTokenAddress(token);
    final pk = _hexToPrivateKey(privateKey);
    final signInput2 = Solana.SigningInput(
        recentBlockhash: nonce,
        privateKey: pk.data().toList(),
        tokenTransferTransaction: Solana.TokenTransfer(
            tokenMintAddress: token,
            senderTokenAddress: fromTokenAddress,
            recipientTokenAddress: toTokenAddress,
            amount: $fixed_num.Int64.parseInt(amount.toString()),
            decimals: decimals));
    final sign =
        AnySigner.sign(signInput2.writeToBuffer(), TWCoinType.TWCoinTypeSolana);
    final signOutput = Solana.SigningOutput.fromBuffer(sign.toList());
    final signTx = signOutput.encoded;
    return HttpHelper.sendRpc(url, "sendTransaction", signTx);
  }
}
