import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  _EmergencyContactsScreenState createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<EmergencyContact> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();

    // โหลดจำนวนรายชื่อ
    final int count = prefs.getInt('emergency_contacts_count') ?? 0;

    List<EmergencyContact> contacts = [];

    // โหลดรายชื่อทั้งหมด
    for (int i = 0; i < count; i++) {
      final name = prefs.getString('emergency_contact_${i}_name') ?? '';
      final phone = prefs.getString('emergency_contact_${i}_phone') ?? '';
      final relation = prefs.getString('emergency_contact_${i}_relation') ?? '';
      final priority =
          prefs.getInt('emergency_contact_${i}_priority') ?? (i + 1);

      contacts.add(EmergencyContact(
        name: name,
        phone: phone,
        relation: relation,
        priority: priority,
      ));
    }

    // จัดเรียงตามลำดับความสำคัญ
    contacts.sort((a, b) => a.priority.compareTo(b.priority));

    // ถ้ายังไม่มีรายชื่อ ให้สร้างรายชื่อว่างๆ ไว้
    if (contacts.isEmpty) {
      contacts.add(EmergencyContact(
        name: '',
        phone: '',
        relation: 'ผู้ดูแล',
        priority: 1,
      ));
    }

    setState(() {
      _contacts = contacts;
      _isLoading = false;
    });

    // บันทึกรายชื่อแรกเป็นรายชื่อหลัก
    if (contacts.isNotEmpty) {
      await _savePrimaryContact(contacts[0]);
    }
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();

    // บันทึกจำนวนรายชื่อ
    await prefs.setInt('emergency_contacts_count', _contacts.length);

    // บันทึกรายชื่อทั้งหมด
    for (int i = 0; i < _contacts.length; i++) {
      final contact = _contacts[i];
      await prefs.setString('emergency_contact_${i}_name', contact.name);
      await prefs.setString('emergency_contact_${i}_phone', contact.phone);
      await prefs.setString(
          'emergency_contact_${i}_relation', contact.relation);
      await prefs.setInt('emergency_contact_${i}_priority', contact.priority);
    }

    // บันทึกรายชื่อแรกเป็นรายชื่อหลัก
    if (_contacts.isNotEmpty) {
      await _savePrimaryContact(_contacts[0]);
    }
  }

  Future<void> _savePrimaryContact(EmergencyContact contact) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emergency_contact_name', contact.name);
    await prefs.setString('emergency_contact_phone', contact.phone);
  }

  void _addContact() {
    setState(() {
      _contacts.add(EmergencyContact(
        name: '',
        phone: '',
        relation: 'ผู้ดูแล',
        priority: _contacts.length + 1,
      ));
    });
  }

  void _removeContact(int index) {
    setState(() {
      _contacts.removeAt(index);

      // อัพเดทลำดับความสำคัญหลังจากลบ
      for (int i = 0; i < _contacts.length; i++) {
        _contacts[i].priority = i + 1;
      }
    });

    _saveContacts();
  }

  void _moveContactUp(int index) {
    if (index <= 0) return;

    setState(() {
      final temp = _contacts[index];
      _contacts[index] = _contacts[index - 1];
      _contacts[index - 1] = temp;

      // อัพเดทลำดับความสำคัญ
      _contacts[index].priority = index + 1;
      _contacts[index - 1].priority = index;
    });

    _saveContacts();
  }

  void _moveContactDown(int index) {
    if (index >= _contacts.length - 1) return;

    setState(() {
      final temp = _contacts[index];
      _contacts[index] = _contacts[index + 1];
      _contacts[index + 1] = temp;

      // อัพเดทลำดับความสำคัญ
      _contacts[index].priority = index + 1;
      _contacts[index + 1].priority = index + 2;
    });

    _saveContacts();
  }

  void _editContact(int index) {
    final contact = _contacts[index];

    final nameController = TextEditingController(text: contact.name);
    final phoneController = TextEditingController(text: contact.phone);
    final relationController = TextEditingController(text: contact.relation);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(contact.name.isNotEmpty ? 'แก้ไขผู้ติดต่อ' : 'เพิ่มผู้ติดต่อ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อ',
                  hintText: 'ใส่ชื่อผู้ติดต่อ',
                ),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'เบอร์โทรศัพท์',
                  hintText: 'ใส่เบอร์โทรศัพท์',
                ),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: relationController,
                decoration: const InputDecoration(
                  labelText: 'ความสัมพันธ์',
                  hintText: 'เช่น ลูก, ผู้ดูแล, หมอ',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                contact.name = nameController.text.trim();
                contact.phone = phoneController.text.trim();
                contact.relation = relationController.text.trim();
              });

              _saveContacts();
              Navigator.pop(context);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ผู้ติดต่อฉุกเฉิน'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'เรียงลำดับผู้ติดต่อตามความสำคัญ โดยบุคคลแรกจะถูกติดต่อเป็นอันดับแรกเมื่อเกิดเหตุฉุกเฉิน',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      final bool isFirst = index == 0;
                      final bool isLast = index == _contacts.length - 1;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                isFirst ? Colors.blue : Colors.grey,
                            child: Text(
                              (index + 1).toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            contact.name.isNotEmpty
                                ? contact.name
                                : 'แตะเพื่อเพิ่มผู้ติดต่อ',
                            style: TextStyle(
                              fontWeight:
                                  isFirst ? FontWeight.bold : FontWeight.normal,
                              color:
                                  contact.name.isNotEmpty ? null : Colors.grey,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (contact.phone.isNotEmpty) Text(contact.phone),
                              if (contact.relation.isNotEmpty)
                                Text(contact.relation,
                                    style: const TextStyle(
                                        fontStyle: FontStyle.italic)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editContact(index),
                                tooltip: 'แก้ไข',
                              ),
                              if (_contacts.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _removeContact(index),
                                  tooltip: 'ลบ',
                                ),
                              if (!isFirst)
                                IconButton(
                                  icon: const Icon(Icons.arrow_upward),
                                  onPressed: () => _moveContactUp(index),
                                  tooltip: 'เลื่อนขึ้น',
                                ),
                              if (!isLast)
                                IconButton(
                                  icon: const Icon(Icons.arrow_downward),
                                  onPressed: () => _moveContactDown(index),
                                  tooltip: 'เลื่อนลง',
                                ),
                            ],
                          ),
                          onTap: () => _editContact(index),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addContact,
        tooltip: 'เพิ่มผู้ติดต่อ',
        child: const Icon(Icons.add),
      ),
    );
  }
}
