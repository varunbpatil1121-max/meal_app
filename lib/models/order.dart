import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus { pending, confirmed, rejected }

class MealOrder {
  const MealOrder({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.mealId,
    required this.mealTitle,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.userNotified,
  });

  final String id;
  final String userId;
  final String userEmail;
  final String mealId;
  final String mealTitle;
  final int quantity;
  final int unitPrice;
  final int total;
  final OrderStatus status;
  final DateTime? createdAt;

  /// Whether the customer has already seen the confirmed/rejected popup.
  final bool userNotified;

  factory MealOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return MealOrder(
      id: doc.id,
      userId: data['userId'] as String,
      userEmail: data['userEmail'] as String? ?? '',
      mealId: data['mealId'] as String,
      mealTitle: data['mealTitle'] as String,
      quantity: data['quantity'] as int,
      unitPrice: data['unitPrice'] as int,
      total: data['total'] as int,
      status: OrderStatus.values.byName(data['status'] as String),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      userNotified: data['userNotified'] as bool? ?? true,
    );
  }
}
