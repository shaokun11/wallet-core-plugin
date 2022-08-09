import 'dart:typed_data';
import 'package:http/http.dart';
import 'package:convert/convert.dart';
import 'package:flutter_trust_wallet_core/protobuf/Ethereum.pb.dart'
as Ethereum;
import 'package:flutter_trust_wallet_core/web3/hex_utils.dart';
import 'package:web3dart/web3dart.dart';
import '../flutter_trust_wallet_core.dart';
import '../trust_wallet_core_ffi.dart';
import 'contract_abi.dart';

enum SupportToken { ERC20, ERC721, ERC1155 }

class Web3Eth {
  late final String url;
  late final int chainId;
  late Web3Client _ethClient;

  Web3Eth(String url, int _chainId) {
    this.url = url;
    this.chainId = _chainId;
    this._ethClient = Web3Client(url, Client());
  }

  PrivateKey _hexToPrivateKey(String privateKey) {
    return PrivateKey.createWithData(
        Uint8List.fromList(hex.decode(privateKey)));
  }

  DeployedContract _getContract(String token, SupportToken st) {
    var abiStr = ERC20Token;
    switch (st) {
      case SupportToken.ERC20:
        abiStr = ERC20Token;
        break;
      case SupportToken.ERC721:
        abiStr = ERC721Token;
        break;
      case SupportToken.ERC1155:
        abiStr = ERC1155Token;
        break;
    }
    final contract = DeployedContract(
        ContractAbi.fromJson(abiStr, st.name), EthereumAddress.fromHex(token));
    return contract;
  }

  getNonce(String address) {
    return this
        ._ethClient
        .getTransactionCount(EthereumAddress.fromHex(address));
  }

  EthereumAddress encodingAddress(String address) {
    return EthereumAddress.fromHex(address);
  }

  getBalance(String address) {
    return this._ethClient.getBalance(EthereumAddress.fromHex(address));
  }

  buildContractHexData(SupportToken st, String _contract, String method,
      List<dynamic> params) {
    final contract = this._getContract(_contract, st);
    final function = contract.function(method);
    return HexUtils.bytesToHex(function.encodeCall(params));
  }

  estimateGas(String from, String to, BigInt gasPrice,
      String hexData, {BigInt? value}) {
    value = value != null ? value : BigInt.from(0);
    return this._ethClient.estimateGas(
        to: EthereumAddress.fromHex(to),
        sender: EthereumAddress.fromHex(from),
        gasPrice: EtherAmount.inWei(value),
        value: EtherAmount.inWei(value),
        data: HexUtils.hexToBytes(hexData));
  }

  transferEth(String to, BigInt value, BigInt gasPrice, BigInt nonce,
      BigInt gasLimit, String privateKey) async {
    int coin = TWCoinType.TWCoinTypeEthereum;
    var pk =
    PrivateKey.createWithData(Uint8List.fromList(hex.decode(privateKey)));
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
    final signTx = "0x" + hex.encode(output.encoded);
    return this._ethClient.sendRawTransaction(HexUtils.hexToBytes(signTx));
  }

  call(String from, String token, SupportToken st, String method,
      List<dynamic> params) {
    final contract = this._getContract(token, st);
    final fun = contract.function(method);
    return this._ethClient.call(
        contract: this._getContract(token, st),
        function: fun,
        params: params,
        sender: EthereumAddress.fromHex(from));
  }

  send(String from,
      String contract,
      String hexData,
      BigInt gasPrice,
      BigInt gasLimit,
      BigInt nonce,
      String privateKey,
      {BigInt? value}) async {
    int coin = TWCoinType.TWCoinTypeEthereum;
    var ethValue;
    var key = this._hexToPrivateKey(privateKey).data();
    if (value != null) {
      ethValue = hex.decode(hexData);
    }
    var signerInput = Ethereum.SigningInput(
        chainId: HexUtils.int2Bytes(BigInt.from(this.chainId)),
        privateKey: key,
        gasPrice: HexUtils.int2Bytes(gasPrice),
        toAddress: contract,
        gasLimit: HexUtils.int2Bytes(gasLimit),
        nonce: HexUtils.int2Bytes(nonce),
        transaction: Ethereum.Transaction(
            contractGeneric: Ethereum.Transaction_ContractGeneric(
                amount: ethValue, data: hex.decode(hexData))));
    final output = Ethereum.SigningOutput.fromBuffer(AnySigner.sign(
      signerInput.writeToBuffer(),
      coin,
    ));
    final signTx = "0x" + hex.encode(output.encoded);
    return this._ethClient.sendRawTransaction(HexUtils.hexToBytes(signTx));
  }
}
