const String idColumn = 'idColumn';
const String nameColumn = 'nameColumn';
const String emailColumn = 'emailColumn';
const String phoneColumn = 'phoneColumn';
const String imgColumn = 'imgColumn';
const String contactTable = 'contactTable';
const String cepColumn = 'cepColumn';
const String streetColumn = 'streetColumn';
const String neighborhoodColumn = 'neighborhoodColumn';
const String cityColumn = 'cityColumn';
const String stateColumn = 'stateColumn';
const String numberColumn = 'numberColumn';
const String complementColumn = 'complementColumn';

class Contact {
  Contact({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.img,
    this.cep = '',
    this.street = '',
    this.neighborhood = '',
    this.city = '',
    this.state = '',
    this.number = '',
    this.complement = '',
  });

  int? id;
  String name;
  String email;
  String phone;
  String? img;
  String cep;
  String street;
  String neighborhood;
  String city;
  String state;
  String number;
  String complement;

  Contact.fromMap(Map<String, dynamic> map)
    : id = map[idColumn] as int?,
      name = map[nameColumn] as String? ?? '',
      email = map[emailColumn] as String? ?? '',
      phone = map[phoneColumn] as String? ?? '',
      img = map[imgColumn] as String?,
      cep = map[cepColumn] as String? ?? '',
      street = map[streetColumn] as String? ?? '',
      neighborhood = map[neighborhoodColumn] as String? ?? '',
      city = map[cityColumn] as String? ?? '',
      state = map[stateColumn] as String? ?? '',
      number = map[numberColumn] as String? ?? '',
      complement = map[complementColumn] as String? ?? '';

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      nameColumn: name,
      emailColumn: email,
      phoneColumn: phone,
      imgColumn: img,
      cepColumn: cep,
      streetColumn: street,
      neighborhoodColumn: neighborhood,
      cityColumn: city,
      stateColumn: state,
      numberColumn: number,
      complementColumn: complement,
    };
    if (id != null) map[idColumn] = id;
    return map;
  }

  String get formattedAddress {
    final location = [
      city,
      state,
    ].where((value) => value.isNotEmpty).join(' - ');
    return [
      street,
      number,
      complement,
      neighborhood,
      location,
      if (cep.isNotEmpty) 'CEP $cep',
    ].where((value) => value.isNotEmpty).join(', ');
  }

  @override
  String toString() =>
      'Contact(id: $id, name: $name, email: $email, '
      'phone: $phone, img: $img, address: $formattedAddress)';
}
