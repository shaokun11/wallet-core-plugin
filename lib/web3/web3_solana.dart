import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_trust_wallet_core/protobuf/Solana.pb.dart' as Solana;
import 'package:flutter_trust_wallet_core/web3/hex_utils.dart';
import 'package:flutter_trust_wallet_core/web3/http_helper.dart';
import 'package:solana/base58.dart';
import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/src/encoder/instruction.dart' as Instruction1;
import 'package:solana/metaplex.dart';
import 'package:solana/solana.dart';
import 'package:web3dart/crypto.dart';
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
    this.signMsg("hello world",
        "273a3e657f718e7e978a674597e6f53250cd8618dd4c2cb42fba07e8857b3a76");
  }

  signTx2(String rawData) async {
    print("--------keys---start sign ");
    var obj = jsonDecode(rawData);
    List<Instruction1.Instruction> insArr = [];
    obj["instructions"].forEach((element) {
      List<AccountMeta> accounts = [];
      element["keys"].forEach((ele) {
        accounts.add(AccountMeta(
            pubKey: Ed25519HDPublicKey.fromBase58(ele["pubkey"]),
            isWriteable: ele["isSigner"],
            isSigner: ele["isWritable"]));
      });
      var ins = Instruction1.Instruction(
          programId: Ed25519HDPublicKey.fromBase58(element["programId"]),
          accounts: accounts,
          data: ByteArray.fromString(element['data'].toString()));
      insArr.add(ins);
    });
    final pk3 = await Ed25519HDKeyPair.fromPrivateKeyBytes(
        privateKey: hexToBytes(
            "273a3e657f718e7e978a674597e6f53250cd8618dd4c2cb42fba07e8857b3a76"));
    var message = Message(instructions: insArr);

    var msg2 = Message(
      instructions: [
        Instruction1.Instruction(
            programId: Ed25519HDPublicKey.fromBase58(
                "11111111111111111111111111111111"),
            accounts: [
              AccountMeta(
                  pubKey: Ed25519HDPublicKey.fromBase58(
                      "26A6Yb36eFUvtpny2kvWV21QXuounRAHUc2ZKyWkD3r9"),
                  isWriteable: true,
                  isSigner: true),
              AccountMeta(
                  pubKey: Ed25519HDPublicKey.fromBase58(
                      "26A6Yb36eFUvtpny2kvWV21QXuounRAHUc2ZKyWkD3r9"),
                  isWriteable: false,
                  isSigner: true)
            ],
            data: ByteArray.fromString("[2, 0, 0, 0, 15, 0, 0, 0, 0, 0, 0, 0]"))
      ],
    );
    var res = await pk3.signMessage(
        message: msg2,
        recentBlockhash: "CDhyoW3tTya7RJ74XFyj92XYd1wgccobo8jR2wG4qYtq");

    return base58encode(base64Decode(res.encode()));
    // return this.client.signAndSendTransaction(msg2, [pk3]);

    // print("sign tx ${res.signatures.first.toBase58()}");
    // print("sign tx ${base58encode(base64Decode(res.encode()))}");

    // final keys = await Ed25519HDKeyPair.random();
    // final pk1 = await keys.extract();
    // final pk2 = HexUtils.bytesToHex(pk1.bytes);
    // print("--------keys----${keys.address}  ${pk2}");
    // print("--------keys----${pk3.address} ");
    // final signRes = await pk3.sign("hello world".codeUnits);
    // print('--------xxx---${HexUtils.bytesToHex(signRes.bytes)}');
  }

  signAndSend() {
    // return this.client.signAndSendTransaction(message, signers);
  }

  signTx(Iterable<int> msg, String pk) async {
    final pk3 =
        await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: hexToBytes(pk));
    final signer = await pk3.sign(msg);
    final ret = HexUtils.bytesToHex(signer.bytes);
    print("signMsg---$ret");
    return ret;
    // return sign(messageHash, privateKey);
  }

  signMsg(String msg, String pk) async {
    final pk3 =
        await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: hexToBytes(pk));
    final signer = await pk3.sign(msg.codeUnits);
    final ret = HexUtils.bytesToHex(signer.bytes);
    print("signMsg---$ret");
    return ret;
    // return sign(messageHash, privateKey);
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
    return GetMetaplexMetadata(client)
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
      String nonce, String privateKey) async {
    var fromTokenAddress =
        SolanaAddress.createWithString(from).defaultTokenAddress(token);
    var toTokenAddress =
        SolanaAddress.createWithString(to).defaultTokenAddress(token);
    final pk = _hexToPrivateKey(privateKey);
    var signInput;
    try {
      await client.getAccountInfo(toTokenAddress!, encoding: Encoding.base64);
      signInput = Solana.SigningInput(
          recentBlockhash: nonce,
          privateKey: pk.data().toList(),
          tokenTransferTransaction: Solana.TokenTransfer(
              tokenMintAddress: token,
              senderTokenAddress: fromTokenAddress,
              recipientTokenAddress: toTokenAddress,
              amount: $fixed_num.Int64.parseInt(amount.toString()),
              decimals: decimals));
    } on NoSuchMethodError {
      signInput = Solana.SigningInput(
          recentBlockhash: nonce,
          privateKey: pk.data().toList(),
          createAndTransferTokenTransaction: Solana.CreateAndTransferToken(
              recipientMainAddress: to,
              tokenMintAddress: token,
              senderTokenAddress: fromTokenAddress,
              recipientTokenAddress: toTokenAddress,
              amount: $fixed_num.Int64.parseInt(amount.toString()),
              decimals: decimals));
    }
    final sign =
        AnySigner.sign(signInput.writeToBuffer(), TWCoinType.TWCoinTypeSolana);
    final signOutput = Solana.SigningOutput.fromBuffer(sign.toList());
    final signTx = signOutput.encoded;
    return HttpHelper.sendRpc(url, "sendTransaction", signTx);
  }
}
