import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/emergency_contact.dart';

/// บริการสำหรับจัดการผู้ติดต่อฉุกเฉิน
class EmergencyContactsService {
  // รายชื่อผู้ติดต่อฉุกเฉิน
  List<EmergencyContact> _contacts = [];

  // Singleton pattern
  static final EmergencyContactsService _instance =
      EmergencyContactsService._internal();

  factory EmergencyContactsService() {
    return _instance;
  }

  EmergencyContactsService._internal();

  /// โหลดรายชื่อผู้ติดต่อจาก SharedPreferences
  Future<List<EmergencyContact>> loadContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // โหลดจำนวนรายชื่อ
      final int count = prefs.getInt('emergency_contacts_count') ?? 0;

      List<EmergencyContact> contacts = [];

      // โหลดรายชื่อทั้งหมด
      for (int i = 0; i < count; i++) {
        final name = prefs.getString('emergency_contact_${i}_name') ?? '';
        final phone = prefs.getString('emergency_contact_${i}_phone') ?? '';
        final relation =
            prefs.getString('emergency_contact_${i}_relation') ?? '';
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

      _contacts = contacts;

      // บันทึกรายชื่อแรกเป็นรายชื่อหลัก
      if (contacts.isNotEmpty) {
        await _savePrimaryContact(contacts[0]);
      }
    } catch (e) {
      print('Error loading emergency contacts: $e');

      // ถ้าโหลดไม่สำเร็จ ให้ใช้รายชื่อเริ่มต้น
      _contacts = [
        EmergencyContact(
          name: '',
          phone: '',
          relation: 'ผู้ดูแล',
          priority: 1,
        ),
      ];
    }

    return _contacts;
  }

  /// บันทึกรายชื่อผู้ติดต่อลงใน SharedPreferences
  Future<void> saveContacts() async {
    try {
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
    } catch (e) {
      print('Error saving emergency contacts: $e');
    }
  }

  /// บันทึกรายชื่อหลักที่จะถูกใช้ในกรณีฉุกเฉิน
  Future<void> _savePrimaryContact(EmergencyContact contact) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('emergency_contact_name', contact.name);
      await prefs.setString('emergency_contact_phone', contact.phone);
    } catch (e) {
      print('Error saving primary contact: $e');
    }
  }

  /// ดึงรายชื่อผู้ติดต่อฉุกเฉินทั้งหมด
  List<EmergencyContact> getAllContacts() {
    return List.unmodifiable(_contacts);
  }

  /// ดึงรายชื่อผู้ติดต่อฉุกเฉินหลัก
  Future<EmergencyContact?> getPrimaryContact() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('emergency_contact_name') ?? '';
      final phone = prefs.getString('emergency_contact_phone') ?? '';

      if (name.isEmpty && phone.isEmpty) {
        return null;
      }

      return EmergencyContact(
        name: name,
        phone: phone,
        relation: '',
        priority: 1,
      );
    } catch (e) {
      print('Error getting primary contact: $e');
      return null;
    }
  }

  /// เพิ่มผู้ติดต่อฉุกเฉินใหม่
  Future<void> addContact(EmergencyContact contact) async {
    // กำหนดลำดับความสำคัญใหม่
    contact = contact.copyWith(priority: _contacts.length + 1);

    _contacts.add(contact);

    // บันทึกการเปลี่ยนแปลง
    await saveContacts();
  }

  /// อัพเดทผู้ติดต่อฉุกเฉินที่มีอยู่
  Future<void> updateContact(int index, EmergencyContact updatedContact) async {
    if (index < 0 || index >= _contacts.length) {
      return;
    }

    // คงลำดับความสำคัญเดิม
    updatedContact =
        updatedContact.copyWith(priority: _contacts[index].priority);

    _contacts[index] = updatedContact;

    // บันทึกการเปลี่ยนแปลง
    await saveContacts();
  }

  /// ลบผู้ติดต่อฉุกเฉิน
  Future<void> removeContact(int index) async {
    if (index < 0 || index >= _contacts.length) {
      return;
    }

    _contacts.removeAt(index);

    // ปรับลำดับความสำคัญใหม่
    for (int i = 0; i < _contacts.length; i++) {
      _contacts[i] = _contacts[i].copyWith(priority: i + 1);
    }

    // บันทึกการเปลี่ยนแปลง
    await saveContacts();
  }

  /// เลื่อนลำดับผู้ติดต่อฉุกเฉินขึ้น
  Future<void> moveContactUp(int index) async {
    if (index <= 0 || index >= _contacts.length) {
      return;
    }

    // สลับตำแหน่ง
    final temp = _contacts[index];
    _contacts[index] = _contacts[index - 1];
    _contacts[index - 1] = temp;

    // ปรับลำดับความสำคัญ
    _contacts[index] = _contacts[index].copyWith(priority: index + 1);
    _contacts[index - 1] = _contacts[index - 1].copyWith(priority: index);

    // บันทึกการเปลี่ยนแปลง
    await saveContacts();
  }

  /// เลื่อนลำดับผู้ติดต่อฉุกเฉินลง
  Future<void> moveContactDown(int index) async {
    if (index < 0 || index >= _contacts.length - 1) {
      return;
    }

    // สลับตำแหน่ง
    final temp = _contacts[index];
    _contacts[index] = _contacts[index + 1];
    _contacts[index + 1] = temp;

    // ปรับลำดับความสำคัญ
    _contacts[index] = _contacts[index].copyWith(priority: index + 1);
    _contacts[index + 1] = _contacts[index + 1].copyWith(priority: index + 2);

    // บันทึกการเปลี่ยนแปลง
    await saveContacts();
  }

  /// นำเข้ารายชื่อจาก JSON
  Future<bool> importFromJson(String jsonString) async {
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);

      final List<EmergencyContact> contacts = jsonList.map((json) {
        return EmergencyContact.fromJson(json);
      }).toList();

      // จัดเรียงตามลำดับความสำคัญ
      contacts.sort((a, b) => a.priority.compareTo(b.priority));

      // ปรับลำดับความสำคัญให้ต่อเนื่อง
      for (int i = 0; i < contacts.length; i++) {
        contacts[i] = contacts[i].copyWith(priority: i + 1);
      }

      _contacts = contacts;

      // บันทึกการเปลี่ยนแปลง
      await saveContacts();

      return true;
    } catch (e) {
      print('Error importing contacts from JSON: $e');
      return false;
    }
  }

  /// ส่งออกรายชื่อเป็น JSON
  String exportToJson() {
    final jsonList = _contacts.map((contact) => contact.toJson()).toList();
    return jsonEncode(jsonList);
  }

  /// ดึงจำนวนรายชื่อผู้ติดต่อฉุกเฉิน
  int getContactsCount() {
    return _contacts.length;
  }

  /// ตรวจสอบว่ามีรายชื่อหลักตั้งค่าไว้หรือไม่
  Future<bool> hasPrimaryContact() async {
    final contact = await getPrimaryContact();
    return contact != null &&
        contact.name.isNotEmpty &&
        contact.phone.isNotEmpty;
  }

  /// ล้างรายชื่อผู้ติดต่อทั้งหมด
  Future<void> clearAllContacts() async {
    _contacts.clear();

    // เพิ่มรายชื่อว่างเริ่มต้น
    _contacts.add(EmergencyContact(
      name: '',
      phone: '',
      relation: 'ผู้ดูแล',
      priority: 1,
    ));

    // บันทึกการเปลี่ยนแปลง
    await saveContacts();
  }
}
