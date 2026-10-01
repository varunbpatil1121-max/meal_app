import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meal_app/config.dart';
import 'package:meal_app/models/meal.dart';
import 'package:meal_app/models/order.dart';

class OrderService {
  static final _orders = FirebaseFirestore.instance.collection('${kCollectionPrefix}orders');
  static final _prices = FirebaseFirestore.instance.collection('${kCollectionPrefix}prices');

  /// Places the order and returns its id.
  static Future<String> placeOrder(Meal meal, int quantity) async {
    final user = FirebaseAuth.instance.currentUser!;
    // Read the live price so the order matches what the admin has set.
    final priceDoc = await _prices.doc(meal.id).get();
    if (!priceDoc.exists) {
      throw Exception('This meal has no price yet. Ask an admin to set one.');
    }
    final unitPrice = priceDoc.data()!['price'] as int;
    final doc = await _orders.add({
      'userId': user.uid,
      'userEmail': user.email,
      'mealId': meal.id,
      'mealTitle': meal.title,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'total': unitPrice * quantity,
      'status': OrderStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      // The last status the customer has seen a popup for.
      'notifiedStatus': OrderStatus.pending.name,
    });
    return doc.id;
  }

  static Stream<MealOrder?> watchOrder(String orderId) => _orders
      .doc(orderId)
      .snapshots()
      .map((snap) => snap.exists ? MealOrder.fromDoc(snap) : null);

  static Stream<List<MealOrder>> watchMyOrders(String uid) => _orders
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map(_toSortedOrders);

  static Stream<List<MealOrder>> watchAllOrders() =>
      _orders.snapshots().map(_toSortedOrders);

  static Future<void> markUserNotified(String orderId, OrderStatus status) =>
      _orders.doc(orderId).update({'notifiedStatus': status.name});

  static Future<void> setStatus(String orderId, OrderStatus status) =>
      _orders.doc(orderId).update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  // Sorted here instead of with orderBy() so no Firestore index is needed.
  static List<MealOrder> _toSortedOrders(QuerySnapshot<Map<String, dynamic>> snap) {
    final orders = snap.docs.map(MealOrder.fromDoc).toList();
    orders.sort((a, b) =>
        (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
    return orders;
  }
}
