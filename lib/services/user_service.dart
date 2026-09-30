import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meal_app/config.dart';

class UserService {
  static final _users = FirebaseFirestore.instance.collection('${kCollectionPrefix}users');

  /// Creates `meal_users/{uid}` the first time someone signs in. New accounts are
  /// always plain users; make someone an admin by setting `role: "admin"` on
  /// their document in the Firebase console.
  static Future<void> ensureUserDoc(User user) async {
    final doc = _users.doc(user.uid);
    if ((await doc.get()).exists) return;
    await doc.set({
      'email': user.email,
      'role': 'user',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<bool> watchIsAdmin(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((snap) => snap.data()?['role'] == 'admin');
}
