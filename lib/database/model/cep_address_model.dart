class CepAddress {
  const CepAddress({
    required this.cep,
    required this.street,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.complement,
  });

  final String cep;
  final String street;
  final String neighborhood;
  final String city;
  final String state;
  final String complement;

  factory CepAddress.fromJson(Map<String, dynamic> json) => CepAddress(
    cep: json['cep'] as String? ?? '',
    street: json['logradouro'] as String? ?? '',
    neighborhood: json['bairro'] as String? ?? '',
    city: json['localidade'] as String? ?? '',
    state: json['uf'] as String? ?? '',
    complement: json['complemento'] as String? ?? '',
  );
}
