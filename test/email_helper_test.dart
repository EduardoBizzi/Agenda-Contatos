import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_contatos/database/helper/email_helper.dart';

void main() {
  test('Aceita endereços com comprimentos e domínios variados', () {
    for (final email in [
      'ana@example.com',
      'a@dominio.com.br',
      'Nome.Sobrenome+trabalho@sub.dominio.com.br',
      'joao_123@escola.edu.br',
    ]) {
      expect(EmailHelper.isValid(email), isTrue, reason: email);
    }
  });

  test('Recusa e-mails incompletos, espaços e domínios inválidos', () {
    for (final email in [
      '',
      'nome',
      '@exemplo.com',
      'nome@',
      'nome@@exemplo.com',
      '.nome@exemplo.com',
      'nome.@exemplo.com',
      'no..me@exemplo.com',
      'no me@exemplo.com',
      'nome@dominio',
      'nome@-dominio.com',
      'nome@dominio-.com',
      'nome@dominio..com',
    ]) {
      expect(EmailHelper.isValid(email), isFalse, reason: email);
    }
  });

  test('Formatação remove espaços e normaliza somente o domínio', () {
    final formatter = EmailInputFormatter();
    const input = ' Ana+Trabalho@EXEMPLO.COM.BR ';
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: input,
        selection: TextSelection.collapsed(offset: input.length),
      ),
    );
    expect(result.text, 'Ana+Trabalho@exemplo.com.br');
    expect(result.selection.baseOffset, result.text.length);
    expect(EmailHelper.validate(''), isNotNull);
    expect(EmailHelper.validate('inválido'), isNotNull);
    expect(EmailHelper.validate(result.text), isNull);
  });
}
