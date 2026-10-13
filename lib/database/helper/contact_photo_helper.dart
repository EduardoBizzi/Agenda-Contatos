import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:agenda_contatos/database/model/contact_model.dart';

class ContactPhotoHelper {
  ContactPhotoHelper({
    ImagePicker? picker,
    Future<Directory> Function()? documentsDirectory,
  }) : _picker = picker ?? ImagePicker(),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  final ImagePicker _picker;
  final Future<Directory> Function() _documentsDirectory;

  Future<File> _draftFile() async => File(
    path.join((await _documentsDirectory()).path, 'contact_photo_draft.json'),
  );

  Future<XFile?> pickImage(ImageSource source, {required Contact draft}) async {
    // Guarda o formulário antes de abrir a câmera/galeria. O Android pode
    // encerrar a atividade enquanto o aplicativo de câmera está aberto.
    final file = await _draftFile();
    await file.writeAsString(jsonEncode(draft.toMap()), flush: true);
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        requestFullMetadata: false,
      );
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<Contact?> recoverLostContact() async {
    if (!Platform.isAndroid) return null;
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) return null;
    if (response.exception != null) throw response.exception!;
    final photos = response.files;
    if (photos == null || photos.isEmpty) return null;
    final draftFile = await _draftFile();
    Contact contact = Contact(name: '', email: '', phone: '', img: null);
    if (await draftFile.exists()) {
      final decoded = jsonDecode(await draftFile.readAsString());
      contact = Contact.fromMap(Map<String, dynamic>.from(decoded as Map));
      await draftFile.delete();
    }
    contact.img = photos.first.path;
    return contact;
  }

  Future<String?> persistPhoto(String? sourcePath) async {
    if (sourcePath == null || sourcePath.isEmpty) return null;
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException(
        'Foto não encontrada. Selecione a foto novamente.',
      );
    }
    final directory = Directory(
      path.join((await _documentsDirectory()).path, 'contact_photos'),
    );
    await directory.create(recursive: true);
    if (path.isWithin(directory.absolute.path, source.absolute.path)) {
      return source.absolute.path;
    }
    final extension = path.extension(source.path);
    final destination = path.join(
      directory.path,
      'contact_${DateTime.now().microsecondsSinceEpoch}${extension.isEmpty ? '.jpg' : extension}',
    );
    return (await source.copy(destination)).path;
  }
}
