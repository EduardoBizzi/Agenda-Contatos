import 'package:flutter/services.dart';

class EmailHelper {
  static String normalize(String value) {
    final email = value.trim();
    final at = email.lastIndexOf('@');
    if (at < 0) return email;
    return '${email.substring(0, at)}@${email.substring(at + 1).toLowerCase()}';
  }

  static bool isValid(String value) {
    final email = normalize(value);
    if (email.isEmpty || email.length > 254 || RegExp(r'\s').hasMatch(email)) {
      return false;
    }
    final parts = email.split('@');
    if (parts.length != 2) return false;
    final local = parts[0];
    if (local.isEmpty ||
        local.length > 64 ||
        local.startsWith('.') ||
        local.endsWith('.') ||
        local.contains('..') ||
        !RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+$").hasMatch(local)) {
      return false;
    }
    final labels = parts[1].split('.');
    if (labels.length < 2 || !RegExp(r'^[a-z]{2,63}$').hasMatch(labels.last)) {
      return false;
    }
    final labelPattern = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
    return labels.every(labelPattern.hasMatch);
  }

  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) return 'E-mail é obrigatório!';
    return isValid(value)
        ? null
        : 'Informe um e-mail válido, como nome@dominio.com.';
  }
}

// E-mails têm comprimentos variáveis: evita espaços e formata o domínio,
// sem impor uma máscara fixa que impediria endereços válidos.
class EmailInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    final withoutSpaces = newValue.text.replaceAll(RegExp(r'\s'), '');
    final text = EmailHelper.normalize(withoutSpaces);
    int offset(int position) {
      if (position < 0) return text.length;
      return newValue.text
          .substring(0, position.clamp(0, newValue.text.length))
          .replaceAll(RegExp(r'\s'), '')
          .length
          .clamp(0, text.length);
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: offset(newValue.selection.baseOffset),
        extentOffset: offset(newValue.selection.extentOffset),
      ),
    );
  }
}
