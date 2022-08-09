import 'dart:typed_data';
import 'package:http/http.dart';
import 'package:convert/convert.dart';
import 'package:flutter_trust_wallet_core/protobuf/Ethereum.pb.dart'
    as Ethereum;
import 'package:flutter_trust_wallet_core/web3/hex_utils.dart';
import 'package:web3dart/web3dart.dart';
import '../flutter_trust_wallet_core.dart';
import '../protobuf/Ethereum.pbenum.dart';
import '../trust_wallet_core_ffi.dart';
import 'contract_abi.dart';

class Web3Eth {
  late final String url;
  late final int chainId;
  late Web3Client _ethClient;

  Web3Eth(String url, int _chainId) {
    this.url = url;
    this.chainId = _chainId;
    this._ethClient = Web3Client(url, Client());
  }

  DeployedContract _getContract(String token) {
    final contract = DeployedContract(ContractAbi.fromJson(ERC20Token, "ERC20"),
        EthereumAddress.fromHex(token));
    return contract;
  }

  getNonce(String address) {
    return this
        ._ethClient
        .getTransactionCount(EthereumAddress.fromHex(address));
  }

  getBalance(String address) {
    return this._ethClient.getBalance(EthereumAddress.fromHex(address));
  }

  _buildContractData(String _contract, String method, List<dynamic> params) {
    final contract = this._getContract(_contract);
    final function = contract.function(method);
    return function.encodeCall(params);
  }

  estimateErc20Gas(String token, String from, String to, BigInt value,
      String method, List<dynamic> params) {
    return this._ethClient.estimateGas(
        to: EthereumAddress.fromHex(token),
        sender: EthereumAddress.fromHex(from),
        value: EtherAmount.fromUnitAndValue(EtherUnit.wei, value),
        data: this._buildContractData(token, method, params));
  }

  getTokenBalance(String token, String owner) async {
    final contract = this._getContract(token);
    final function = contract.function("balanceOf");
    return await this._ethClient.call(
        contract: contract,
        function: function,
        params: [EthereumAddress.fromHex(owner)]);
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
        txMode: TransactionMode.Legacy,
        maxFeePerGas: HexUtils.int2Bytes(nonce),
        maxInclusionFeePerGas: HexUtils.int2Bytes(nonce),
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

  transferErc20(String token, String to, BigInt amount, BigInt gasPrice,
      BigInt nonce, BigInt gasLimit, String privateKey) async {
    int coin = TWCoinType.TWCoinTypeEthereum;
    var pk =
        PrivateKey.createWithData(Uint8List.fromList(hex.decode(privateKey)));
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
    return this._ethClient.sendRawTransaction(HexUtils.hexToBytes(signTx));
  }
}
