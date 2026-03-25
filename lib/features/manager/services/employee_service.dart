import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/audit_service.dart';

class EmployeeService {
  static final _db = FirebaseFirestore.instance;

  // 🟢 1. ENTERPRISE ONBOARDING (Strict Manual EMP ID)
  static Future<void> createEmployee({
    required String empId,
    required String role, // 👈 Dynamic Role Name (e.g., Wealth Head)
    String? tagPrefix, // 👈 🚀 NEW: The Security Tag (e.g., WEALTH)
    required String name,
    required String phone,
    String? email,
    required String branchCode,
    String? tenantId,
  }) async {
    try {
      // 1. Duplicate checks (Phone & EmpID)
      final existingPhone = await _db
          .collection('staff')
          .where('phone', isEqualTo: phone)
          .get();
      if (existingPhone.docs.isNotEmpty) {
        throw "Phone number +91 $phone is already registered.";
      }

      final existingEmpId = await _db
          .collection('staff')
          .where('empId', isEqualTo: empId.trim().toUpperCase())
          .get();
      if (existingEmpId.docs.isNotEmpty) {
        throw "Employee ID '${empId.trim().toUpperCase()}' is already in use.";
      }

      // 2. Create Document
      final staffRef = _db.collection('staff').doc();
      final cleanEmpId = empId.trim().toUpperCase();
      final cleanBranch = branchCode.toUpperCase().trim();
      final finalTag = tagPrefix?.toUpperCase() ?? role.toUpperCase();

      await staffRef.set({
        'staffId': staffRef.id,
        'docId': staffRef.id,
        'empId': cleanEmpId,
        'role': role.toUpperCase(),
        'tagPrefix': finalTag, // 🚀 NEW
        // 🗝️ THE BILLION DOLLAR ARRAY: Yeh hume access filters me speed dega
        'accessTags': [
          finalTag, // (e.g. "WEALTH")
          cleanBranch, // (e.g. "MUM01")
        ],
        'name': name.trim(),
        'phone': phone.trim(),
        'email': email?.trim().toLowerCase() ?? '',
        'branchCode': cleanBranch,
        'status': 'ACTIVE',
        'isActive': true,
        'isDeleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'tenantId': tenantId,
      });

      // 📧 3. FIREBASE FREE EMAIL TRIGGER
      if (email != null && email.trim().isNotEmpty) {
        await _db.collection('mail').add({
          'to': email.trim().toLowerCase(),
          'message': {
            'subject': 'Welcome to ClickOut! Your Access Details',
            'text':
                'Hello $name,\n\nYou have been assigned the role of $role at branch $cleanBranch.\n\nYour Employee ID is: $cleanEmpId\nLogin using your registered phone number: +91 $phone.\n\nThe App download link will be shared with you shortly.\n\nRegards,\nClickOut Admin Team',
          },
        });
      }

      // 🛡️ Audit Log
      await AuditService.logAction(
        actionType: 'STAFF_ONBOARDED',
        targetCollection: 'staff',
        targetId: staffRef.id,
        details: 'Created $role access for $name ($cleanEmpId).',
        severity: 'INFO',
        tenantId: tenantId ?? 'SYSTEM',
      );
    } catch (e) {
      throw "Onboarding Failed: $e";
    }
  }

  // 🟠 2. UPDATE EMPLOYEE
  static Future<void> updateEmployee({
    required String uid,
    required String collectionName,
    required String role,
    required String phone,
    required String branchCode,
    String? tenantId,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(uid)
          .update({
            'role': role.toUpperCase(),
            'phone': phone,
            'branchCode': branchCode.toUpperCase(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // 🛡️ LOG THE ACTION
      await AuditService.logAction(
        actionType: 'UPDATE_STAFF',
        targetCollection: collectionName,
        targetId: uid,
        details:
            'Updated profile. Re-assigned to Role: $role, Branch: $branchCode.',
        severity: 'WARNING',
        tenantId: tenantId ?? 'SYSTEM',
      );
    } catch (e) {
      throw "Update Failed: $e";
    }
  }

  // 🔴 3. TOGGLE STATUS
  static Future<void> toggleEmployeeStatus(
    String uid,
    bool currentStatus,
    String collectionName,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(uid)
          .update({
            'isActive': !currentStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw "Status Toggle Failed: $e";
    }
  }

  // 💀 4. SOFT DELETE
  static Future<void> softDeleteEmployee(
    String uid,
    String collectionName,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(uid)
          .update({
            'isDeleted': true,
            'isActive': false,
            'deletedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw "Delete Failed: $e";
    }
  }
}
