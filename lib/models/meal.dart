enum Complexity { simple, challenging, hard }
enum Affordability { affordable, pricey, luxurious }

class Meal {
  const Meal({
    required this.id,
    required this.categories,
    required this.title,
    required this.imageUrl,
    required this.ingredients,
    required this.steps,
    required this.duration,
    required this.price,
    required this.complexity,
    required this.affordability,
    required this.isGlutenFree,
    required this.isLactoseFree,
    required this.isVegan,
    required this.isVegetarian,
  });

  final String id;
  final List<String> categories;
  final String title;
  final String imageUrl;
  final List<String> ingredients;
  final List<String> steps;
  final int duration;

  /// Default price in rupees. The live price comes from Firestore
  /// (`meal_prices/{id}`) and can be changed by an admin.
  final int price;
  final Complexity complexity;
  final Affordability affordability;
  final bool isGlutenFree;
  final bool isLactoseFree;
  final bool isVegan;
  final bool isVegetarian;

  // Meals added by an admin are rebuilt on every Firestore update, so compare
  // by id to keep favorites working.
  @override
  bool operator ==(Object other) => other is Meal && other.id == id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toMap() => {
        'categories': categories,
        'title': title,
        'imageUrl': imageUrl,
        'ingredients': ingredients,
        'steps': steps,
        'duration': duration,
        'price': price,
        'complexity': complexity.name,
        'affordability': affordability.name,
        'isGlutenFree': isGlutenFree,
        'isLactoseFree': isLactoseFree,
        'isVegan': isVegan,
        'isVegetarian': isVegetarian,
      };

  factory Meal.fromMap(String id, Map<String, dynamic> data) => Meal(
        id: id,
        categories: List<String>.from(data['categories'] as List),
        title: data['title'] as String,
        imageUrl: data['imageUrl'] as String,
        ingredients: List<String>.from(data['ingredients'] as List),
        steps: List<String>.from(data['steps'] as List),
        duration: data['duration'] as int,
        price: data['price'] as int,
        complexity: Complexity.values.byName(data['complexity'] as String),
        affordability: Affordability.values.byName(data['affordability'] as String),
        isGlutenFree: data['isGlutenFree'] as bool,
        isLactoseFree: data['isLactoseFree'] as bool,
        isVegan: data['isVegan'] as bool,
        isVegetarian: data['isVegetarian'] as bool,
      );
}
