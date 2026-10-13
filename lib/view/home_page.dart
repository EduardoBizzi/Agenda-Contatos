import 'dart:io';
import 'package:agenda_contatos/database/helper/contact_photo_helper.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agenda_contatos/database/helper/contact_helper.dart';
import 'package:agenda_contatos/database/model/contact_model.dart';
import 'package:agenda_contatos/view/contact_page.dart';

enum OrderOptions { orderAZ, orderZA }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ContactHelper helper = ContactHelper();
  List<Contact> contacts = [];
  final ContactPhotoHelper _photoHelper = ContactPhotoHelper();

  @override
  void initState() {
    super.initState();
    _getAllContacts();
    _recoverLostPhoto();
  }

  Future<void> _recoverLostPhoto() async {
    try {
      final contact = await _photoHelper.recoverLostContact();
      if (contact == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Foto recuperada. Confira e salve os dados do contato.',
          ),
        ),
      );
      await _showContactPage(contact: contact);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível recuperar a foto. Selecione-a novamente.',
          ),
        ),
      );
    }
  }

  Future<void> _getAllContacts() async {
    try {
      final list = await helper.getAllContacts();
      if (!mounted) return;
      setState(() {
        contacts = list;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao carregar os contatos.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda de Contatos'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: <Widget>[
          PopupMenuButton<OrderOptions>(
            itemBuilder: (context) => <PopupMenuEntry<OrderOptions>>[
              const PopupMenuItem<OrderOptions>(
                value: OrderOptions.orderAZ,
                child: Text('Ordenar de A-Z'),
              ),
              const PopupMenuItem<OrderOptions>(
                value: OrderOptions.orderZA,
                child: Text('Ordenar de Z-A'),
              ),
            ],
            onSelected: _orderList,
          ),
        ],
      ),
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showContactPage(),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(10.0),
        itemCount: contacts.length,
        itemBuilder: (context, index) => _contactCard(context, index),
      ),
    );
  }

  Widget _contactCard(BuildContext context, int index) {
    final contact = contacts[index];
    return GestureDetector(
      onTap: () => _showOptions(context, index),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: <Widget>[
              ClipOval(
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: contact.img != null && contact.img!.isNotEmpty
                      ? Image.file(
                          File(contact.img!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Image.asset(
                            'assets/imgs/image.png',
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset('assets/imgs/image.png', fit: BoxFit.cover),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        contact.email,
                        style: const TextStyle(fontSize: 18.0),
                      ),
                      Text(
                        contact.phone,
                        style: const TextStyle(fontSize: 18.0),
                      ),
                      if (contact.formattedAddress.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          contact.formattedAddress,
                          style: const TextStyle(fontSize: 14.0),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showContactPage({Contact? contact}) async {
    final updatedContact = await Navigator.push<Contact>(
      context,
      MaterialPageRoute(builder: (context) => ContactPage(contact: contact)),
    );
    if (updatedContact != null && mounted) {
      await _getAllContacts();
    }
  }

  void _showOptions(BuildContext context, int index) {
    final contact = contacts[index];
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return BottomSheet(
          onClosing: () {},
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextButton(
                    child: const Text(
                      'Ligar',
                      style: TextStyle(color: Colors.green, fontSize: 20.0),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _callContact(contact);
                    },
                  ),
                  TextButton(
                    child: const Text(
                      'Editar',
                      style: TextStyle(color: Colors.blue, fontSize: 20.0),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showContactPage(contact: contact);
                    },
                  ),
                  TextButton(
                    child: const Text(
                      'Excluir',
                      style: TextStyle(color: Colors.red, fontSize: 20.0),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _deleteContact(contact);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _callContact(Contact contact) async {
    try {
      final opened = await launchUrl(Uri(scheme: 'tel', path: contact.phone));
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o discador.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o discador.')),
      );
    }
  }

  Future<void> _deleteContact(Contact contact) async {
    if (contact.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: ID do contato não encontrado.')),
      );
      return;
    }
    try {
      await helper.deleteContact(contact.id!);
      if (!mounted) return;
      setState(() {
        contacts.remove(contact);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao excluir o contato.')),
      );
    }
  }

  void _orderList(OrderOptions result) {
    switch (result) {
      case OrderOptions.orderAZ:
        contacts.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case OrderOptions.orderZA:
        contacts.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
    }
    setState(() {});
  }
}
