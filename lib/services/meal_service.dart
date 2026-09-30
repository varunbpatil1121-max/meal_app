import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:meal_app/config.dart';
import 'package:meal_app/data/dummy_data.dart';
import 'package:meal_app/models/meal.dart';

/// All meals: the built-in ones from dummy_data plus meals admins have added
/// (stored in `meal_meals`), kept up to date live.
class MealService {
  static final _db = FirebaseFirestore.instance;
  static final _meals = _db.collection('${kCollectionPrefix}meals');
  static final _prices = _db.collection('${kCollectionPrefix}prices');
  static final ValueNotifier<List<Meal>> meals = ValueNotifier(dummyMeals);
  static StreamSubscription? _sub;

  static final _builtInIds = {for (final meal in dummyMeals) meal.id};

  static void start() {
    _sub ??= _meals.snapshots().listen((snap) {
      final added = <Meal>[];
      for (final doc in snap.docs) {
        try {
          added.add(Meal.fromMap(doc.id, doc.data()));
        } catch (e) {
          debugPrint('Skipping malformed meal ${doc.id}: $e');
        }
      }
      added.sort((a, b) => a.title.compareTo(b.title));
      meals.value = [...dummyMeals, ...added];
    });
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    meals.value = dummyMeals;
  }

  static bool isAddedByAdmin(Meal meal) => !_builtInIds.contains(meal.id);

  /// Saves the meal and its price together, so it can be ordered straight away.
  static Future<void> addMeal(Meal meal) async {
    final doc = _meals.doc();
    final batch = _db.batch()
      ..set(doc, meal.toMap())
      ..set(_prices.doc(doc.id), {'price': meal.price});
    await batch.commit();
  }

  static Future<void> deleteMeal(Meal meal) async {
    final batch = _db.batch()
      ..delete(_meals.doc(meal.id))
      ..delete(_prices.doc(meal.id));
    await batch.commit();
  }
}
