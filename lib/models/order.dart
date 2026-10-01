import 'package:cloud_firestore/cloud_firestore.dart';

/// Order stages in the order they happen. An admin moves an order forward one
/// step at a time; [rejected] is only possible while it's [pending].
enum OrderStatus {
  pending,
  confirmed,
  cooking,
  pickedUp,
  onTheWay,
  delivered,
  rejected;

  /// The step an admin can move the order to next, if any.
  OrderStatus? get next => switch (this) {
        pending => confirmed,
        confirmed => cooking,
        cooking => pickedUp,
        pickedUp => onTheWay,
        onTheWay => delivered,
        delivered || rejected => null,
      };

  bool get isActive => this != delivered && this != rejected;

  String get label => switch (this) {
        pending => 'Waiting',
        confirmed => 'Confirmed',
        cooking => 'Cooking',
        pickedUp => 'Picked up',
        onTheWay => 'On the way',
        delivered => 'Delivered',
        rejected => 'Rejected',
      };

  /// Button text for an admin moving an order *to* this status.
  String get actionLabel => switch (this) {
        confirmed => 'Confirm order',
        cooking => 'Start cooking',
        pickedUp => 'Picked up',
        onTheWay => 'On the way',
        delivered => 'Delivered',
        _ => label,
      };
}

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
    required this.notifiedStatus,
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

  /// The last status the customer was shown a popup for.
  final String? notifiedStatus;

  factory MealOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final status = data['status'] as String;
    return MealOrder(
      id: doc.id,
      userId: data['userId'] as String,
      userEmail: data['userEmail'] as String? ?? '',
      mealId: data['mealId'] as String,
      mealTitle: data['mealTitle'] as String,
      quantity: data['quantity'] as int,
      unitPrice: data['unitPrice'] as int,
      total: data['total'] as int,
      status: OrderStatus.values.asNameMap()[status] ?? OrderStatus.pending,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      // Orders from before per-step notifications only had a yes/no flag.
      notifiedStatus: data['notifiedStatus'] as String? ??
          ((data['userNotified'] as bool? ?? true) ? status : null),
    );
  }
}
