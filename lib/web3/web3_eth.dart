import 'dart:typed_data';
import 'package:http/http.dart';
import 'package:convert/convert.dart';
import 'package:flutter_trust_wallet_core/protobuf/Ethereum.pb.dart'
    as Ethereum;
import 'package:flutter_trust_wallet_core/web3/hex_utils.dart';
import 'package:web3dart/web3dart.dart';
import '../flutter_trust_wallet_core.dart';
import '../trust_wallet_core_ffi.dart';
export './contract_abi.dart';

class Web3EthContract {
  const Web3EthContract(this.abi, this.name, this.address);

  final String abi;
  final String name;
  final String address;
}

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

  getNonce(String address) {
    return _ethClient.getTransactionCount(EthereumAddress.fromHex(address));
  }

  getBalance(String address) {
    return _ethClient.getBalance(EthereumAddress.fromHex(address));
  }

  EthereumAddress encodingAddress(String address) {
    return EthereumAddress.fromHex(address);
  }

  DeployedContract newContract(Web3EthContract contract) {
    return DeployedContract(ContractAbi.fromJson(contract.abi, contract.name),
        EthereumAddress.fromHex(contract.address));
  }

  buildContractHexData(
      DeployedContract contract, String method, List<dynamic> params) {
    final function = contract.function(method);
    return HexUtils.bytesToHex(function.encodeCall(params));
  }

  estimateGas(String from, String to, BigInt baseFeePerGas,
      BigInt maxPriorityFeePerGas, String hexData,
      {BigInt? value}) {
    final maxFeePerGas = baseFeePerGas + maxPriorityFeePerGas;
    value = value != null ? value : BigInt.from(0);
    return _ethClient.estimateGas(
        to: EthereumAddress.fromHex(to),
        sender: EthereumAddress.fromHex(from),
        maxFeePerGas: EtherAmount.inWei(maxFeePerGas),
        maxPriorityFeePerGas: EtherAmount.inWei(maxPriorityFeePerGas),
        value: EtherAmount.inWei(value),
        data: HexUtils.hexToBytes(hexData));
  }

  transferEth(
      String to,
      BigInt value,
      BigInt baseFeePerGas,
      BigInt maxInclusionFeePerGas,
      BigInt nonce,
      BigInt gasLimit,
      String privateKey) async {
    int coin = TWCoinType.TWCoinTypeEthereum;
    final maxFeePerGas = baseFeePerGas + maxInclusionFeePerGas;
    var pk = _hexToPrivateKey(privateKey);
    var signerInput = Ethereum.SigningInput(
        chainId: HexUtils.int2Bytes(BigInt.from(chainId)),
        nonce: HexUtils.int2Bytes(nonce),
        toAddress: to,
        txMode: Ethereum.TransactionMode.Enveloped,
        maxFeePerGas: HexUtils.int2Bytes(maxFeePerGas),
        maxInclusionFeePerGas: HexUtils.int2Bytes(maxInclusionFeePerGas),
        gasLimit: HexUtils.int2Bytes(gasLimit),
        transaction: Ethereum.Transaction(
            transfer: Ethereum.Transaction_Transfer(
                amount: HexUtils.int2Bytes(value))),
        privateKey: pk.data());
    final signed = AnySigner.sign(
      signerInput.writeToBuffer(),
      coin,
    );
    final output = Ethereum.SigningOutput.fromBuffer(signed);
    final signTx = "0x${hex.encode(output.encoded)}";
    return _ethClient.sendRawTransaction(HexUtils.hexToBytes(signTx));
  }

  call(DeployedContract contract, String method, List<dynamic> params,
      String from) {
    final fun = contract.function(method);
    return _ethClient.call(
        contract: contract,
        function: fun,
        params: params,
        sender: EthereumAddress.fromHex(from));
  }

  send(String from, String to, String hexData, BigInt baseFee,
      BigInt priorityFee, BigInt gasLimit, BigInt nonce, String privateKey,
      {BigInt? value}) async {
    int coin = TWCoinType.TWCoinTypeEthereum;
    var ethValue;
    var key = _hexToPrivateKey(privateKey);
    if (value != null) {
      ethValue = HexUtils.int2Bytes(value);
    } else {
      ethValue = null;
    }
    final maxFee = baseFee + priorityFee;
    var signerInput = Ethereum.SigningInput(
        chainId: HexUtils.int2Bytes(BigInt.from(chainId)),
        privateKey: key.data(),
        toAddress: to,
        txMode: Ethereum.TransactionMode.Enveloped,
        maxInclusionFeePerGas: HexUtils.int2Bytes(priorityFee),
        maxFeePerGas: HexUtils.int2Bytes(maxFee),
        gasLimit: HexUtils.int2Bytes(gasLimit),
        nonce: HexUtils.int2Bytes(nonce),
        transaction: Ethereum.Transaction(
            contractGeneric: Ethereum.Transaction_ContractGeneric(
                amount: ethValue, data: hex.decode(hexData))));
    final output = Ethereum.SigningOutput.fromBuffer(AnySigner.sign(
      signerInput.writeToBuffer(),
      coin,
    ));
    final signTx = "0x${hex.encode(output.encoded)}";
    return _ethClient.sendRawTransaction(HexUtils.hexToBytes(signTx));
  }
}
