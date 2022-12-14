import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:eth_sig_util/eth_sig_util.dart';
import 'package:http/http.dart';
import 'package:convert/convert.dart';
import 'package:flutter_trust_wallet_core/protobuf/Ethereum.pb.dart'
    as Ethereum;
import 'package:flutter_trust_wallet_core/web3/hex_utils.dart';
import 'package:web3dart/web3dart.dart';
import '../flutter_trust_wallet_core.dart';
import '../trust_wallet_core_ffi.dart';
export './contract_abi.dart';
import 'dart:math';

class Web3EthContract {
  const Web3EthContract(this.abi, this.name, this.address);

  final String abi;
  final String name;
  final String address;
}

class Web3Eth {
  late final String url;
  late final int chainId;
  final String currentAddress = "0xE4beD49Fe64Ca88b990F2C51328f09291F7F50eb";

  late Web3Client _ethClient;

  Web3Eth(String url, int _chainId) {
    this.url = url;
    this.chainId = _chainId;
    this._ethClient = Web3Client(url, Client());
  }

  checkNftInfo(String tokenAddress) async {
    var type = "unknown";
    var name = "unknown";
    var symbol = "unknown";
    try {
      DeployedContract contract = DeployedContract(
          ContractAbi.fromJson(ERC721Token, 'ERC721Token'),
          EthereumAddress.fromHex(tokenAddress));
      final bool support = (await call(contract, 'supportsInterface',
          [HexUtils.hexToBytes('0x80ac58cd')], currentAddress))[0];
      if (support) {
        type = "erc721";
      }
    } catch (e) {
      print("e$e");
    }
    if (type == "unknown") {
      try {
        DeployedContract contract = DeployedContract(
            ContractAbi.fromJson(ERC1155Token, 'ERC1155Token'),
            EthereumAddress.fromHex(tokenAddress));
        final bool support = (await call(contract, 'supportsInterface',
            [HexUtils.hexToBytes('0xd9b67a26')], currentAddress))[0];
        if (support) {
          type = "erc1155";
        }
      } catch (e) {}
    }
    try {
      DeployedContract contract = DeployedContract(
          ContractAbi.fromJson(ERC20Token, 'ERC721Token'),
          EthereumAddress.fromHex(tokenAddress));
      name = (await call(contract, 'name', [], currentAddress))[0];
      symbol = (await call(contract, 'symbol', [], currentAddress))[0];
    } catch (e) {}
    return {"name": name, "symbol": symbol, "type": type};
  }

  transferERC1155(
      String from,
      String to,
      String privateKey,
      String token,
      int tokenId,
      int amount,
      double maxFee,
      double gasValue,
      double gasLimit) async {
    int nonce = await _ethClient.getTransactionCount(
        EthereumAddress.fromHex(from),
        atBlock: const BlockNum.pending());
    DeployedContract contract =
        newContract(Web3EthContract(ERC1155Token, 'ERC1155', token));
    final credentials = EthPrivateKey.fromHex(privateKey);
    if (maxFee > gasValue) {
      return _ethClient.sendTransaction(
        credentials,
        Transaction(
            from: EthereumAddress.fromHex(from),
            to: EthereumAddress.fromHex(token),
            maxFeePerGas: EtherAmount.inWei(BigInt.from(maxFee * 1e9)),
            maxPriorityFeePerGas:
                EtherAmount.inWei(BigInt.from(gasValue * 1e9)),
            nonce: nonce,
            data: contract.function("safeTransferFrom").encodeCall([
              EthereumAddress.fromHex(from),
              EthereumAddress.fromHex(to),
              BigInt.from(tokenId),
              BigInt.from(amount),
              Uint8List.fromList("".codeUnits)
            ])),
        chainId: chainId,
      );
    } else {
      return _ethClient.sendTransaction(
        credentials,
        Transaction(
            from: EthereumAddress.fromHex(from),
            to: EthereumAddress.fromHex(token),
            gasPrice: EtherAmount.inWei(BigInt.from(gasValue * 1e9)),
            maxGas: gasLimit.toInt(),
            nonce: nonce,
            data: contract.function("safeTransferFrom").encodeCall([
              EthereumAddress.fromHex(from),
              EthereumAddress.fromHex(to),
              BigInt.from(tokenId),
              BigInt.from(amount),
              Uint8List.fromList("".codeUnits)
            ])),
        chainId: chainId,
      );
    }
  }

  transferERC1155Batch(
      String from,
      String to,
      String privateKey,
      String token,
      List<BigInt> ids,
      List<BigInt> amounts,
      double maxFee,
      double gasValue,
      double gasLimit) async {
    int nonce = await _ethClient.getTransactionCount(
        EthereumAddress.fromHex(from),
        atBlock: const BlockNum.pending());
    DeployedContract contract =
    newContract(Web3EthContract(ERC1155Token, 'ERC1155', token));
    final credentials = EthPrivateKey.fromHex(privateKey);

    if (maxFee > gasValue) {
      return _ethClient.sendTransaction(

        credentials,
        Transaction(
            from: EthereumAddress.fromHex(from),
            to: EthereumAddress.fromHex(token),
            maxFeePerGas: EtherAmount.inWei(BigInt.from(maxFee * 1e9)),
            maxPriorityFeePerGas:
            EtherAmount.inWei(BigInt.from(gasValue * 1e9)),
            nonce: nonce,
            data: contract.function("safeBatchTransferFrom").encodeCall([
              EthereumAddress.fromHex(from),
              EthereumAddress.fromHex(to),
              ids,
              amounts,
              Uint8List.fromList("".codeUnits)
            ])),
        chainId: chainId,
      );
    } else {
      return _ethClient.sendTransaction(
        credentials,
        Transaction(
            from: EthereumAddress.fromHex(from),
            to: EthereumAddress.fromHex(token),
            gasPrice: EtherAmount.inWei(BigInt.from(gasValue * 1e9)),
            maxGas: gasLimit.toInt(),
            nonce: nonce,
            data: contract.function("safeBatchTransferFrom").encodeCall([
              EthereumAddress.fromHex(from),
              EthereumAddress.fromHex(to),
              ids,
              amounts,
              Uint8List.fromList("".codeUnits)
            ])),
        chainId: chainId,
      );
    }
  }

  transferERC721(String sender, String to, String privateKey, String erc721,
      int tokenId, double maxFee, double gasValue, double gasLimit) async {
    int nonce = await _ethClient.getTransactionCount(
        EthereumAddress.fromHex(sender),
        atBlock: const BlockNum.pending());
    DeployedContract contract =
        newContract(Web3EthContract(ERC721Token, 'ERC721', erc721));
    final credentials = EthPrivateKey.fromHex(privateKey);

    if (maxFee > gasValue) {
      return _ethClient.sendTransaction(
          credentials,
          Transaction(
              from: EthereumAddress.fromHex(sender),
              to: EthereumAddress.fromHex(erc721),
              maxFeePerGas: EtherAmount.inWei(BigInt.from(maxFee * 1e9)),
              maxPriorityFeePerGas:
                  EtherAmount.inWei(BigInt.from(gasValue * 1e9)),
              nonce: nonce,
              data: contract.function("transferFrom").encodeCall([
                EthereumAddress.fromHex(sender),
                EthereumAddress.fromHex(to),
                BigInt.from(tokenId)
              ])),
          chainId: chainId);
    } else {
      return _ethClient.sendTransaction(
          credentials,
          Transaction(
              from: EthereumAddress.fromHex(sender),
              to: EthereumAddress.fromHex(erc721),
              gasPrice: EtherAmount.inWei(BigInt.from(gasValue * 1e9)),
              maxGas: gasLimit.toInt(),
              nonce: nonce,
              data: contract.function("transferFrom").encodeCall([
                EthereumAddress.fromHex(sender),
                EthereumAddress.fromHex(to),
                BigInt.from(tokenId)
              ])),
          chainId: chainId);
    }
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

  ethSign(m, data, pk) {
    final payload = data["data"];
    if (m == "personal_ecRecover") {
      return EthSigUtil.recoverPersonalSignature(
          signature: data['signature'],
          message: HexUtils.hexToBytes(data['message']));
    }
    if (m == "eth_sign") {
      return EthSigUtil.signMessage(message: payload, privateKey: pk);
    }
    if (m == "personal_sign") {
      return EthSigUtil.signPersonalMessage(
          message: HexUtils.hexToBytes(payload), privateKey: pk);
    }
    if (m == "eth_signTypedData_v3") {
      return EthSigUtil.signTypedData(
          jsonData: jsonEncode(payload),
          version: TypedDataVersion.V3,
          privateKey: pk);
    }
    if (m == "eth_signTypedData_v4") {
      return EthSigUtil.signTypedData(
          jsonData: jsonEncode(payload),
          version: TypedDataVersion.V4,
          privateKey: pk);
    }
    if (m == "eth_signTypedData") {
      return EthSigUtil.signTypedData(
          jsonData: jsonEncode(payload),
          version: TypedDataVersion.V1,
          privateKey: pk);
    }
    return "";
  }

  parseWebBrowserObj(payload) async {
    var from = payload["from"];
    var to = payload["to"];
    var data = HexUtils.strip0x(payload["data"]);
    var value = payload["value"];
    var gasLimit = BigInt.from(HexUtils.hexToInt(payload["gas"])!);
    if (value != null) {
      value = BigInt.from(HexUtils.hexToInt(payload["value"])!);
    } else {
      value = BigInt.zero;
    }
    var send = new Map();
    send["from"] = from;
    send["to"] = to;
    send["data"] = data;
    send["gasLimit"] = gasLimit;
    send["value"] = value;
    var parseRes = {};
    var dio = Dio();
    try {
      var response = await dio.post('https://wallet.csfun.io/api/abi/decode',
          data: {'data': payload["data"]});
      if (response.statusCode == 200) {
        var data = response.data;
        if (data["code"] == 2000) {
          var parse = data["data"];
          var action = parse["action"];
          if (action.length > 0) {
            // parse success
            parseRes = parse["data"];
            parseRes["token"] = to;
            if (action == "transfer" || action == "approve") {
              parseRes["from"] = from;
            }
            try {
              var symbol = await this.call(
                  DeployedContract(
                      ContractAbi.fromJson(ERC20Token, 'erc721_erc20'),
                      encodingAddress(to)),
                  "symbol",
                  [],
                  from);
              parseRes["symbol"] = symbol[0];
            } catch (e) {}
            // more metadata
            try {
              // erc20
              var decimals = await this.call(
                  DeployedContract(ContractAbi.fromJson(ERC20Token, 'erc20'),
                      encodingAddress(to)),
                  "decimals",
                  [],
                  from);
              // transfer and approve
              if (parseRes["amount"] != null) {
                parseRes["amount"] = (BigInt.parse(parseRes["amount"]) /
                        BigInt.from(pow(10, decimals[0])))
                    .toString();
              }
            } catch (e) {}
          }
        }
      }
    } catch (e) {}
    return {"send": send, "meta": parseRes};
  }

  send(String from, String to, String hexData, BigInt baseFee,
      BigInt priorityFee, BigInt gasLimit, BigInt nonce, String privateKey,
      {BigInt? value, BigInt? gasPrice}) async {
    int coin = TWCoinType.TWCoinTypeEthereum;
    var ethValue;
    var key = _hexToPrivateKey(privateKey);
    if (value != null) {
      ethValue = HexUtils.int2Bytes(value);
    }
    var signerInput;
    if (gasPrice != null) {
      signerInput = Ethereum.SigningInput(
          chainId: HexUtils.int2Bytes(BigInt.from(chainId)),
          privateKey: key.data(),
          toAddress: to,
          txMode: Ethereum.TransactionMode.Legacy,
          gasPrice: HexUtils.int2Bytes(gasPrice),
          gasLimit: HexUtils.int2Bytes(gasLimit),
          nonce: HexUtils.int2Bytes(nonce),
          transaction: Ethereum.Transaction(
              contractGeneric: Ethereum.Transaction_ContractGeneric(
                  amount: ethValue, data: hex.decode(hexData))));
    } else {
      final maxFee = baseFee + priorityFee;
      signerInput = Ethereum.SigningInput(
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
    }
    final output = Ethereum.SigningOutput.fromBuffer(AnySigner.sign(
      signerInput.writeToBuffer(),
      coin,
    ));
    final signTx = "0x${hex.encode(output.encoded)}";
    return _ethClient.sendRawTransaction(HexUtils.hexToBytes(signTx));
  }
}
