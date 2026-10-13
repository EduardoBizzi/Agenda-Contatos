import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:agenda_contatos/database/helper/cep_helper.dart';

void main() {
  test('Consulta ViaCEP por HTTPS e preserva os acentos do endereço', () async {
    final helper = CepHelper(
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://viacep.com.br/ws/01001000/json/',
        );
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'cep': '01001-000',
              'logradouro': 'Praça da Sé',
              'bairro': 'Sé',
              'localidade': 'São Paulo',
              'uf': 'SP',
              'complemento': 'lado ímpar',
            }),
          ),
          200,
        );
      }),
    );
    addTearDown(helper.close);
    final address = await helper.lookup('01001-000');
    expect(address.street, 'Praça da Sé');
    expect(address.neighborhood, 'Sé');
    expect(address.city, 'São Paulo');
    expect(address.state, 'SP');
    expect(address.complement, 'lado ímpar');
  });

  test(
    'CEP inválido não faz requisição e CEP inexistente tem erro claro',
    () async {
      var calls = 0;
      final helper = CepHelper(
        client: MockClient((request) async {
          calls++;
          return http.Response('{"erro":true}', 200);
        }),
      );
      addTearDown(helper.close);
      for (final value in ['123', '123456789', '1234A678']) {
        await expectLater(
          helper.lookup(value),
          throwsA(
            isA<CepLookupException>().having(
              (error) => error.invalidCep,
              'invalid',
              true,
            ),
          ),
        );
      }
      expect(calls, 0);
      await expectLater(
        helper.lookup('99999999'),
        throwsA(
          isA<CepLookupException>().having(
            (error) => error.message,
            'message',
            'CEP não encontrado.',
          ),
        ),
      );
    },
  );

  test(
    'Trata falha de internet, erro HTTP e resposta fora do formato',
    () async {
      final clients = [
        MockClient((_) async => throw http.ClientException('offline')),
        MockClient((_) async => http.Response('erro', 503)),
        MockClient((_) async => http.Response('não é JSON', 200)),
        MockClient((_) async => http.Response('{}', 200)),
      ];
      for (final client in clients) {
        final helper = CepHelper(client: client);
        addTearDown(helper.close);
        await expectLater(
          helper.lookup('01001000'),
          throwsA(isA<CepLookupException>()),
        );
      }
    },
  );

  test('Consulta tem limite de tempo', () async {
    final helper = CepHelper(
      timeout: const Duration(milliseconds: 10),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    addTearDown(helper.close);
    await expectLater(
      helper.lookup('01001000'),
      throwsA(
        isA<CepLookupException>().having(
          (error) => error.message,
          'timeout',
          contains('demorou'),
        ),
      ),
    );
  });
}
