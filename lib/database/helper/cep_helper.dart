import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:agenda_contatos/database/model/cep_address_model.dart';

class CepLookupException implements Exception {
  const CepLookupException(this.message, {this.invalidCep = false});
  final String message;
  final bool invalidCep;
  @override
  String toString() => message;
}

class CepHelper {
  CepHelper({http.Client? client, this.timeout = const Duration(seconds: 20)})
    : _client = client ?? http.Client();
  final http.Client _client;
  final Duration timeout;

  static String digits(String cep) => cep.replaceAll(RegExp(r'[-\s]'), '');

  Future<CepAddress> lookup(String cep) async {
    final value = digits(cep);
    if (!RegExp(r'^\d{8}$').hasMatch(value)) {
      throw const CepLookupException(
        'O CEP deve ter 8 dígitos.',
        invalidCep: true,
      );
    }
    try {
      final response = await _client
          .get(Uri.https('viacep.com.br', '/ws/$value/json/'))
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw const CepLookupException(
          'Não foi possível consultar o CEP. Tente novamente.',
        );
      }
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic>) throw const FormatException();
      if (json['erro'] == true || json['erro'] == 'true') {
        throw const CepLookupException('CEP não encontrado.', invalidCep: true);
      }
      final address = CepAddress.fromJson(json);
      if (address.city.isEmpty || address.state.isEmpty) {
        throw const FormatException();
      }
      return address;
    } on TimeoutException {
      throw const CepLookupException(
        'A consulta demorou demais. Tente novamente ou preencha o endereço manualmente.',
      );
    } on SocketException {
      throw const CepLookupException(
        'Sem conexão. Preencha o endereço manualmente ou tente novamente.',
      );
    } on http.ClientException {
      throw const CepLookupException(
        'Não foi possível conectar. Verifique a internet ou preencha o endereço manualmente.',
      );
    } on FormatException {
      throw const CepLookupException(
        'A consulta retornou um endereço inválido. Tente novamente.',
      );
    }
  }

  void close() => _client.close();
}
