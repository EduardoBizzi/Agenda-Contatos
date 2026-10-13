import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:agenda_contatos/database/helper/contact_helper.dart';
import 'package:agenda_contatos/database/model/contact_model.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late String dbPath;
  late ContactHelper helper;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('agenda-db-test-');
    dbPath = path.join(directory.path, 'contactsDB.db');
    helper = ContactHelper.internal(
      factory: databaseFactoryFfi,
      databasePath: dbPath,
    );
  });
  tearDown(() async {
    await helper.close();
    assert(
      path.isWithin(
        Directory.systemTemp.absolute.path,
        directory.absolute.path,
      ),
    );
    await directory.delete(recursive: true);
  });

  test('Migra o banco da aula sem perder os contatos ou as fotos', () async {
    final old = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE contactTable(idColumn INTEGER PRIMARY KEY, '
            'nameColumn TEXT, emailColumn TEXT, phoneColumn TEXT, imgColumn TEXT)',
          );
        },
      ),
    );
    await old.insert('contactTable', {
      'idColumn': 7,
      'nameColumn': 'João da Silva',
      'emailColumn': 'joao@email.com',
      'phoneColumn': '(42) 99999-9999',
      'imgColumn': '/foto-existente.jpg',
    });
    await old.close();
    final contact = await helper.getContact(7);
    expect((await helper.db).getVersion(), completion(2));
    expect(contact!.name, 'João da Silva');
    expect(contact.email, 'joao@email.com');
    expect(contact.img, '/foto-existente.jpg');
    expect(contact.cep, '');
    expect(contact.street, '');
    expect((await helper.getAllContacts()).length, 1);

    contact.cep = '01001-000';
    contact.street = 'Praça da Sé';
    contact.neighborhood = 'Sé';
    contact.city = 'São Paulo';
    contact.state = 'SP';
    contact.number = '123';
    contact.complement = 'Apto 2';
    await helper.updateContact(contact);
    await helper.close();
    final reloaded = await helper.getContact(7);
    expect(reloaded!.number, '123');
    expect(reloaded.complement, 'Apto 2');
    expect(reloaded.formattedAddress, contains('São Paulo - SP'));
    expect(reloaded.img, '/foto-existente.jpg');
  });

  test(
    'Criação, atualização, reabertura e exclusão persistem todos os campos',
    () async {
      final contact = Contact(
        name: "Ana D'Ávila",
        email: 'ana@email.com',
        phone: '(11) 98765-4321',
        img: '/contact_photos/foto.png',
        cep: '01001-000',
        street: 'Praça da Sé',
        neighborhood: 'Sé',
        city: 'São Paulo',
        state: 'SP',
        number: 's/n',
        complement: 'Bloco B',
      );
      await helper.saveContact(contact);
      expect(contact.id, isNotNull);
      await helper.close();
      final loaded = await helper.getContact(contact.id!);
      expect(loaded!.toMap(), contact.toMap());
      loaded.email = 'ana+novo@email.com';
      loaded.number = '200';
      expect(await helper.updateContact(loaded), 1);
      expect((await helper.getAllContacts()).single.number, '200');
      expect(await helper.deleteContact(loaded.id!), 1);
      expect(await helper.getContact(loaded.id!), isNull);
      expect(await helper.getAllContacts(), isEmpty);
    },
  );
}
