import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:agenda_contatos/database/model/contact_model.dart';

class ContactHelper {
  static final ContactHelper _instance = ContactHelper.internal();
  factory ContactHelper() => _instance;

  ContactHelper.internal({this.factory, this.databasePath});

  final DatabaseFactory? factory;
  final String? databasePath;
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  Future<Database> initDb() async {
    final path =
        databasePath ??
        join(
          await (factory?.getDatabasesPath() ?? getDatabasesPath()),
          'contactsDB.db',
        );
    if (factory == null && databasePath != null) await getDatabasesPath();
    return await (factory ?? databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (Database db, int newVersion) async {
          await db.execute(
            'CREATE TABLE $contactTable('
            '$idColumn INTEGER PRIMARY KEY, '
            '$nameColumn TEXT, $emailColumn TEXT, $phoneColumn TEXT, '
            '$imgColumn TEXT, '
            '$cepColumn TEXT NOT NULL DEFAULT \'\', '
            '$streetColumn TEXT NOT NULL DEFAULT \'\', '
            '$neighborhoodColumn TEXT NOT NULL DEFAULT \'\', '
            '$cityColumn TEXT NOT NULL DEFAULT \'\', '
            '$stateColumn TEXT NOT NULL DEFAULT \'\', '
            '$numberColumn TEXT NOT NULL DEFAULT \'\', '
            '$complementColumn TEXT NOT NULL DEFAULT \'\')',
          );
        },
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          if (oldVersion < 2) {
            for (final column in [
              cepColumn,
              streetColumn,
              neighborhoodColumn,
              cityColumn,
              stateColumn,
              numberColumn,
              complementColumn,
            ]) {
              await db.execute(
                'ALTER TABLE $contactTable ADD COLUMN $column '
                'TEXT NOT NULL DEFAULT \'\'',
              );
            }
          }
        },
      ),
    );
  }

  Future<Contact> saveContact(Contact contact) async {
    final Database dbContact = await db;
    contact.id = await dbContact.insert(contactTable, contact.toMap());
    return contact;
  }

  Future<Contact?> getContact(int id) async {
    final Database dbContact = await db;
    final maps = await dbContact.query(
      contactTable,
      where: '$idColumn = ?',
      whereArgs: [id],
    );
    return maps.isEmpty ? null : Contact.fromMap(maps.first);
  }

  Future<List<Contact>> getAllContacts() async {
    final Database dbContact = await db;
    final listMap = await dbContact.query(contactTable);
    return listMap.map(Contact.fromMap).toList();
  }

  Future<int> deleteContact(int id) async {
    final Database dbContact = await db;
    return await dbContact.delete(
      contactTable,
      where: '$idColumn = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateContact(Contact contact) async {
    final Database dbContact = await db;
    return await dbContact.update(
      contactTable,
      contact.toMap(),
      where: '$idColumn = ?',
      whereArgs: [contact.id],
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
