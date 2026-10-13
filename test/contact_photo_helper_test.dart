import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:agenda_contatos/database/helper/contact_photo_helper.dart';
import 'package:agenda_contatos/database/model/contact_model.dart';

class TestImagePicker extends ImagePicker {
  ImageSource? selected;
  String? draftPath;
  bool cancel = false;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    selected = source;
    expect(maxWidth, 1600);
    expect(requestFullMetadata, isFalse);
    final draft = jsonDecode(await File(draftPath!).readAsString());
    expect(draft['idColumn'], 7);
    expect(draft['nameColumn'], 'Ana');
    return cancel ? null : XFile(File('assets/imgs/image.png').absolute.path);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ContactPhotoHelper helper;
  late TestImagePicker picker;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('agenda-photo-test-');
    picker = TestImagePicker()
      ..draftPath = path.join(directory.path, 'contact_photo_draft.json');
    helper = ContactPhotoHelper(
      picker: picker,
      documentsDirectory: () async => directory,
    );
  });
  tearDown(() async {
    assert(
      path.isWithin(
        Directory.systemTemp.absolute.path,
        directory.absolute.path,
      ),
    );
    await directory.delete(recursive: true);
  });

  test('Câmera e galeria guardam o rascunho durante a captura', () async {
    final contact = Contact(
      id: 7,
      name: 'Ana',
      email: 'ana@email.com',
      phone: '',
      img: null,
    );
    for (final source in [ImageSource.camera, ImageSource.gallery]) {
      expect(await helper.pickImage(source, draft: contact), isNotNull);
      expect(picker.selected, source);
      expect(await File(picker.draftPath!).exists(), isFalse);
    }
    picker.cancel = true;
    expect(await helper.pickImage(ImageSource.camera, draft: contact), isNull);
  });

  test(
    'Foto permanece disponível mesmo depois que o arquivo de cache é removido',
    () async {
      final cache = File(path.join(directory.path, 'camera-cache.png'));
      final original = await File('assets/imgs/image.png').readAsBytes();
      await cache.writeAsBytes(original);
      final savedPath = await helper.persistPhoto(cache.path);
      expect(
        path.isWithin(path.join(directory.path, 'contact_photos'), savedPath!),
        isTrue,
      );
      await cache.delete();
      expect(await File(savedPath).readAsBytes(), original);
      expect(await helper.persistPhoto(savedPath), savedPath);
      expect(await helper.persistPhoto(null), isNull);
    },
  );
}
