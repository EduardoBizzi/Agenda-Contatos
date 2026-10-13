import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agenda_contatos/database/helper/cep_helper.dart';
import 'package:agenda_contatos/database/helper/contact_helper.dart';
import 'package:agenda_contatos/database/helper/contact_photo_helper.dart';
import 'package:agenda_contatos/database/model/contact_model.dart';
import 'package:agenda_contatos/view/contact_page.dart';

class RecordingHelper extends ContactHelper {
  RecordingHelper() : super.internal();
  int creates = 0;
  int updates = 0;
  Contact? saved;
  @override
  Future<Contact> saveContact(Contact contact) async {
    creates++;
    contact.id = 1;
    saved = Contact.fromMap(contact.toMap());
    return contact;
  }

  @override
  Future<int> updateContact(Contact contact) async {
    updates++;
    saved = Contact.fromMap(contact.toMap());
    return 1;
  }
}

class RecordingPhotos extends ContactPhotoHelper {
  ImageSource? source;
  bool cancelled = false;
  @override
  Future<XFile?> pickImage(ImageSource source, {required Contact draft}) async {
    this.source = source;
    return cancelled
        ? null
        : XFile(File('assets/imgs/image.png').absolute.path);
  }

  @override
  Future<String?> persistPhoto(String? sourcePath) async =>
      sourcePath == null ? null : '/contact_photos/captured.png';
}

http.Response addressResponse({String street = 'Praça da Sé'}) =>
    http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'cep': '01001-000',
          'logradouro': street,
          'bairro': 'Sé',
          'localidade': 'São Paulo',
          'uf': 'SP',
          'complemento': 'lado ímpar',
        }),
      ),
      200,
    );

Future<void> openPage(WidgetTester tester, ContactPage page) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            child: const Text('Abrir'),
            onPressed: () {
              Navigator.push<Contact>(
                context,
                MaterialPageRoute(builder: (_) => page),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Future<void> enter(
  WidgetTester tester,
  String key,
  String text, {
  bool settle = true,
}) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.pump();
  await tester.enterText(field, text);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

String value(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(ValueKey(key))).controller!.text;

void main() {
  late RecordingHelper helper;
  late RecordingPhotos photos;
  late CepHelper cep;
  setUp(() {
    helper = RecordingHelper();
    photos = RecordingPhotos();
    cep = CepHelper(client: MockClient((_) async => addressResponse()));
  });
  tearDown(() => cep.close());

  ContactPage page({Contact? contact}) => ContactPage(
    contact: contact,
    helper: helper,
    photoHelper: photos,
    cepHelper: cep,
  );

  testWidgets('Bloqueia nome vazio e e-mail inválido antes de cadastrar', (
    tester,
  ) async {
    await openPage(tester, page());
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    expect(find.text('Nome é obrigatório!'), findsOneWidget);
    expect(find.text('E-mail é obrigatório!'), findsOneWidget);
    await enter(tester, 'name', 'Ana');
    await enter(tester, 'email', 'endereco-invalido');
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    expect(
      find.text('Informe um e-mail válido, como nome@dominio.com.'),
      findsOneWidget,
    );
    expect(helper.creates, 0);
    expect(find.byType(ContactPage), findsOneWidget);
  });

  testWidgets(
    'E-mail também é validado ao editar e descartar preserva o original',
    (tester) async {
      final original = Contact(
        id: 7,
        name: 'João',
        email: 'joao@email.com',
        phone: '(42) 99999-9999',
        img: null,
        city: 'São Paulo',
        state: 'SP',
      );
      await openPage(tester, page(contact: original));
      expect(value(tester, 'city'), 'São Paulo');
      await enter(tester, 'email', 'joao@');
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();
      expect(helper.updates, 0);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(original.email, 'joao@email.com');
      expect(original.city, 'São Paulo');
    },
  );

  testWidgets('Formata e-mail e telefone e salva endereço retornado pela API', (
    tester,
  ) async {
    await openPage(tester, page());
    await enter(tester, 'name', 'Ana');
    await enter(tester, 'email', ' Ana+Trabalho@EXAMPLE.COM.BR ');
    await enter(tester, 'phone', '11987654321');
    expect(value(tester, 'email'), 'Ana+Trabalho@example.com.br');
    expect(value(tester, 'phone'), '(11) 98765-4321');
    await enter(tester, 'number', '123');
    await enter(tester, 'complement', 'Apartamento 2');
    await enter(tester, 'cep', '01001000');
    expect(value(tester, 'cep'), '01001-000');
    expect(value(tester, 'street'), 'Praça da Sé');
    expect(value(tester, 'neighborhood'), 'Sé');
    expect(value(tester, 'city'), 'São Paulo');
    expect(value(tester, 'state'), 'SP');
    expect(value(tester, 'number'), '123');
    expect(value(tester, 'complement'), 'Apartamento 2');
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    expect(helper.creates, 1);
    expect(helper.saved!.street, 'Praça da Sé');
    expect(helper.saved!.complement, 'Apartamento 2');
    expect(helper.saved!.email, 'Ana+Trabalho@example.com.br');
    expect(find.byType(ContactPage), findsNothing);
  });

  testWidgets('Preenche complemento da API quando o usuário não o informou', (
    tester,
  ) async {
    await openPage(tester, page());
    await enter(tester, 'cep', '01001000');
    expect(value(tester, 'complement'), 'lado ímpar');
  });

  testWidgets(
    'CEP inexistente tem mensagem e impede salvar endereço incorreto',
    (tester) async {
      cep.close();
      cep = CepHelper(
        client: MockClient((_) async => http.Response('{"erro":true}', 200)),
      );
      await openPage(tester, page());
      await enter(tester, 'name', 'Ana');
      await enter(tester, 'email', 'ana@email.com');
      await enter(tester, 'cep', '99999999');
      expect(find.text('CEP não encontrado.'), findsWidgets);
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();
      expect(helper.creates, 0);
    },
  );

  testWidgets('Sem internet permite preencher manualmente e guardar o endereço', (
    tester,
  ) async {
    cep.close();
    cep = CepHelper(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await openPage(tester, page());
    await enter(tester, 'name', 'Ana');
    await enter(tester, 'email', 'ana@email.com');
    await enter(tester, 'cep', '01001000');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Não foi possível conectar. Verifique a internet ou preencha o endereço manualmente.',
      ),
      findsOneWidget,
    );
    await enter(tester, 'street', 'Rua preenchida manualmente');
    await enter(tester, 'neighborhood', 'Centro');
    await enter(tester, 'city', 'São Paulo');
    await enter(tester, 'state', 'SP');
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    expect(helper.creates, 1);
    expect(helper.saved!.street, 'Rua preenchida manualmente');
  });

  testWidgets('Ignora a resposta antiga quando o CEP muda durante a consulta', (
    tester,
  ) async {
    final first = Completer<http.Response>();
    final second = Completer<http.Response>();
    cep.close();
    cep = CepHelper(
      client: MockClient(
        (request) => request.url.path.contains('01001000')
            ? first.future
            : second.future,
      ),
    );
    await openPage(tester, page());
    await enter(tester, 'cep', '01001000', settle: false);
    await enter(tester, 'cep', '02002000', settle: false);
    second.complete(addressResponse(street: 'Rua do segundo CEP'));
    await tester.pumpAndSettle();
    first.complete(addressResponse(street: 'Rua do primeiro CEP'));
    await tester.pumpAndSettle();
    expect(value(tester, 'street'), 'Rua do segundo CEP');
  });

  testWidgets('Câmera associa a foto capturada ao contato salvo', (
    tester,
  ) async {
    await openPage(tester, page());
    await tester.tap(find.text('Alterar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();
    expect(photos.source, ImageSource.camera);
    await enter(tester, 'name', 'Ana');
    await enter(tester, 'email', 'ana@email.com');
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    expect(helper.saved!.img, '/contact_photos/captured.png');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Galeria continua disponível e cancelar não altera a foto', (
    tester,
  ) async {
    photos.cancelled = true;
    await openPage(tester, page());
    await tester.tap(find.text('Alterar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecionar da galeria'));
    await tester.pumpAndSettle();
    expect(photos.source, ImageSource.gallery);
    expect(helper.creates, 0);
    expect(find.byType(ContactPage), findsOneWidget);
  });
  testWidgets(
    'CEP digitado número por número e concluir do teclado consultam',
    (tester) async {
      cep.close();
      var calls = 0;
      String? requestedPath;
      cep = CepHelper(
        client: MockClient((request) async {
          calls++;
          requestedPath = request.url.path;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'cep': '16400-510',
                'logradouro': 'Rua da Constituição',
                'bairro': 'Vila Alta',
                'localidade': 'Lins',
                'uf': 'SP',
                'complemento': '',
              }),
            ),
            200,
          );
        }),
      );
      await openPage(tester, page());
      const digits = '16400510';
      for (var length = 1; length <= digits.length; length++) {
        await enter(tester, 'cep', value(tester, 'cep') + digits[length - 1]);
        expect(calls, length < digits.length ? 0 : 1);
      }
      expect(value(tester, 'cep'), '16400-510');
      expect(requestedPath, '/ws/16400510/json/');
      expect(value(tester, 'street'), 'Rua da Constituição');
      expect(value(tester, 'neighborhood'), 'Vila Alta');
      expect(value(tester, 'city'), 'Lins');
      expect(value(tester, 'state'), 'SP');
      expect(find.text('Endereço preenchido automaticamente.'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(value(tester, 'city'), 'Lins');
    },
  );
}
