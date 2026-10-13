import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:agenda_contatos/database/helper/contact_helper.dart';
import 'package:agenda_contatos/database/helper/cep_helper.dart';
import 'package:agenda_contatos/database/helper/contact_photo_helper.dart';
import 'package:agenda_contatos/database/helper/email_helper.dart';
import 'package:agenda_contatos/database/model/contact_model.dart';

class ContactPage extends StatefulWidget {
  final Contact? contact;
  final ContactHelper? helper;
  final CepHelper? cepHelper;
  final ContactPhotoHelper? photoHelper;

  const ContactPage({
    super.key,
    this.contact,
    this.helper,
    this.cepHelper,
    this.photoHelper,
  });

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  late Contact _editContact;
  late final ContactHelper _helper;
  late final CepHelper _cepHelper;
  late final ContactPhotoHelper _photoHelper;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _selectingImage = false;
  bool _loadingCep = false;
  int _cepRequest = 0;
  String? _cepRejected;
  String? _cepStatus;
  bool _cepLookupFailed = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cepController = TextEditingController();
  final _streetController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _numberController = TextEditingController();
  final _complementController = TextEditingController();
  final phoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final cepMask = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {'#': RegExp(r'[0-9]')},
  );

  bool get _busy => _saving || _selectingImage;

  @override
  void initState() {
    super.initState();
    _helper = widget.helper ?? ContactHelper();
    _cepHelper = widget.cepHelper ?? CepHelper();
    _photoHelper = widget.photoHelper ?? ContactPhotoHelper();
    _editContact = widget.contact == null
        ? Contact(name: '', email: '', phone: '', img: null)
        : Contact.fromMap(widget.contact!.toMap());
    _nameController.text = _editContact.name;
    _emailController.text = EmailHelper.normalize(_editContact.email);
    _phoneController.text = _editContact.phone;
    _phoneController.value = phoneMask.formatEditUpdate(
      TextEditingValue.empty,
      _phoneController.value,
    );
    _cepController.text = _editContact.cep;
    _cepController.value = cepMask.formatEditUpdate(
      TextEditingValue.empty,
      _cepController.value,
    );
    _streetController.text = _editContact.street;
    _neighborhoodController.text = _editContact.neighborhood;
    _cityController.text = _editContact.city;
    _stateController.text = _editContact.state;
    _numberController.text = _editContact.number;
    _complementController.text = _editContact.complement;
  }

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _emailController,
      _phoneController,
      _cepController,
      _streetController,
      _neighborhoodController,
      _cityController,
      _stateController,
      _numberController,
      _complementController,
    ]) {
      controller.dispose();
    }
    if (widget.cepHelper == null) _cepHelper.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Text(
          _editContact.name.isEmpty ? 'Novo Contato' : _editContact.name,
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _busy || _loadingCep ? null : _saveContact,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: _saving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 90),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              GestureDetector(
                onTap: _busy || _loadingCep ? null : _showPhotoOptions,
                child: Semantics(
                  button: true,
                  label: 'Alterar foto do contato',
                  child: ClipOval(
                    child: SizedBox(
                      width: 140,
                      height: 140,
                      child:
                          _editContact.img != null &&
                              _editContact.img!.isNotEmpty
                          ? Image.file(
                              File(_editContact.img!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  Image.asset(
                                    'assets/imgs/image.png',
                                    fit: BoxFit.cover,
                                  ),
                            )
                          : Image.asset(
                              'assets/imgs/image.png',
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _busy || _loadingCep ? null : _showPhotoOptions,
                icon: const Icon(Icons.add_a_photo),
                label: Text(
                  _selectingImage ? 'Abrindo imagem...' : 'Alterar foto',
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const ValueKey('name'),
                controller: _nameController,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Nome'),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (text) => text == null || text.trim().isEmpty
                    ? 'Nome é obrigatório!'
                    : null,
                onChanged: (text) => setState(() {
                  _editContact.name = text;
                }),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const ValueKey('email'),
                controller: _emailController,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  hintText: 'nome@dominio.com',
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                inputFormatters: [EmailInputFormatter()],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: EmailHelper.validate,
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const ValueKey('phone'),
                controller: _phoneController,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Telefone'),
                keyboardType: TextInputType.phone,
                inputFormatters: [phoneMask],
              ),
              const SizedBox(height: 28),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Endereço',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('cep'),
                controller: _cepController,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                inputFormatters: [cepMask],
                textInputAction: TextInputAction.done,
                onChanged: _onCepChanged,
                onFieldSubmitted: (_) => _lookupCep(),
                validator: (text) {
                  if (text == null || text.isEmpty) return null;
                  if (CepHelper.digits(text).length != 8) {
                    return 'O CEP deve ter 8 dígitos.';
                  }
                  return _cepRejected;
                },
                decoration: InputDecoration(
                  labelText: 'CEP',
                  hintText: '00000-000',
                  helperText: _loadingCep
                      ? 'Consultando CEP...'
                      : _cepStatus ??
                            'Preenchimento automático ao informar o CEP.',
                  helperMaxLines: 3,
                  helperStyle: _cepLookupFailed
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                  errorText: _cepRejected,
                  suffixIcon: _loadingCep
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Consultar CEP',
                          icon: const Icon(Icons.search),
                          onPressed: _busy ? null : _lookupCep,
                        ),
                ),
              ),
              const SizedBox(height: 16),
              _addressField('street', 'Logradouro', _streetController),
              const SizedBox(height: 16),
              _addressField('neighborhood', 'Bairro', _neighborhoodController),
              const SizedBox(height: 16),
              _addressField('city', 'Cidade', _cityController),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('state'),
                controller: _stateController,
                enabled: !_busy && !_loadingCep,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: const InputDecoration(
                  labelText: 'Estado/UF',
                  hintText: 'SP',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('number'),
                controller: _numberController,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Número',
                  hintText: '123 ou s/n',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('complement'),
                controller: _complementController,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Complemento',
                  hintText: 'Apartamento, bloco...',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addressField(
    String key,
    String label,
    TextEditingController controller,
  ) => TextFormField(
    key: ValueKey(key),
    controller: controller,
    enabled: !_busy && !_loadingCep,
    decoration: InputDecoration(labelText: label),
  );

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _onCepChanged(String text) {
    ++_cepRequest; // Invalida a resposta de uma consulta anterior.
    setState(() {
      _cepRejected = null;
      _cepStatus = null;
      _cepLookupFailed = false;
      _loadingCep = false;
      _streetController.clear();
      _neighborhoodController.clear();
      _cityController.clear();
      _stateController.clear();
    });
    if (CepHelper.digits(text).length == 8) unawaited(_lookupCep());
  }

  Future<void> _lookupCep() async {
    if (_busy || _loadingCep) return;
    final cep = CepHelper.digits(_cepController.text);
    if (!RegExp(r'^\d{8}$').hasMatch(cep)) {
      setState(() {
        _cepRejected = 'O CEP deve ter 8 dígitos.';
      });
      return;
    }
    final request = ++_cepRequest;
    setState(() {
      _loadingCep = true;
      _cepRejected = null;
      _cepStatus = null;
      _cepLookupFailed = false;
    });
    try {
      final address = await _cepHelper.lookup(cep);
      if (!mounted || request != _cepRequest) return;
      setState(() {
        _cepStatus = 'Endereço preenchido automaticamente.';
        _streetController.text = address.street;
        _neighborhoodController.text = address.neighborhood;
        _cityController.text = address.city;
        _stateController.text = address.state;
        if (_complementController.text.trim().isEmpty) {
          _complementController.text = address.complement;
        }
      });
    } on CepLookupException catch (error) {
      if (!mounted || request != _cepRequest) return;
      setState(() {
        if (error.invalidCep) {
          _cepRejected = error.message;
        } else {
          _cepStatus = error.message;
          _cepLookupFailed = true;
        }
      });
      _message(error.message);
    } catch (_) {
      if (!mounted || request != _cepRequest) return;
      const message =
          'Não foi possível consultar o CEP. Você pode preencher o endereço manualmente.';
      setState(() {
        _cepStatus = message;
        _cepLookupFailed = true;
      });
      _message(message);
    } finally {
      if (mounted && request == _cepRequest) {
        setState(() {
          _loadingCep = false;
        });
      }
    }
  }

  Future<void> _showPhotoOptions() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Selecionar da galeria'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() {
      _selectingImage = true;
    });
    _syncFields();
    try {
      final image = await _photoHelper.pickImage(source, draft: _editContact);
      if (image != null && mounted) {
        setState(() {
          _editContact.img = image.path;
        });
      }
    } on PlatformException catch (error) {
      final denied =
          error.code.contains('denied') || error.code.contains('access');
      _message(
        denied
            ? 'Acesso à câmera ou às fotos negado. Confira as permissões do aplicativo.'
            : 'Não foi possível abrir a câmera ou a galeria. Tente novamente.',
      );
    } catch (_) {
      _message('Não foi possível selecionar a foto. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() {
          _selectingImage = false;
        });
      }
    }
  }

  void _syncFields() {
    _editContact.name = _nameController.text.trim();
    _editContact.email = EmailHelper.normalize(_emailController.text);
    _editContact.phone = _phoneController.text;
    _editContact.cep = _cepController.text;
    _editContact.street = _streetController.text.trim();
    _editContact.neighborhood = _neighborhoodController.text.trim();
    _editContact.city = _cityController.text.trim();
    _editContact.state = _stateController.text.trim().toUpperCase();
    _editContact.number = _numberController.text.trim();
    _editContact.complement = _complementController.text.trim();
  }

  Future<void> _saveContact() async {
    if (_busy || _loadingCep) return;
    if (!_formKey.currentState!.validate()) {
      _message('Confira os campos indicados antes de salvar.');
      return;
    }
    FocusScope.of(context).unfocus();
    _syncFields();
    setState(() {
      _saving = true;
    });
    try {
      _editContact.img = await _photoHelper.persistPhoto(_editContact.img);
      if (_editContact.id != null) {
        await _helper.updateContact(_editContact);
      } else {
        await _helper.saveContact(_editContact);
      }
      if (!mounted) return;
      Navigator.pop(context, _editContact);
    } on FileSystemException {
      _message('Não foi possível guardar a foto. Selecione a foto novamente.');
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    } catch (_) {
      _message('Erro ao salvar o contato. Tente novamente.');
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }
}
