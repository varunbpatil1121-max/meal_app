import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:meal_app/models/meal.dart';
import 'package:meal_app/screens/admin_meals_screen.dart';
import 'package:meal_app/screens/admin_orders_screen.dart';
import 'package:meal_app/screens/admin_prices_screen.dart';
import 'package:meal_app/screens/categories_screen.dart';
import 'package:meal_app/screens/filters_screen.dart';
import 'package:meal_app/screens/meals_screen.dart';
import 'package:meal_app/screens/my_orders_screen.dart';
import 'package:meal_app/services/meal_service.dart';
import 'package:meal_app/services/notification_service.dart';
import 'package:meal_app/widgets/main_drawer.dart';

const kInitialFilters = {
  Filter.glutenFree: false,
  Filter.lactoseFree: false,
  Filter.vegetarian: false,
  Filter.vegan: false,
};

class TabsScreen extends StatefulWidget {
  const TabsScreen({super.key, this.isAdmin = false});

  final bool isAdmin;

  @override
  State<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends State<TabsScreen> {
  int _selectedPageIndex = 0;
  final List<Meal> _favoriteMeals = [];
  Map<Filter, bool> _selectedFilters = kInitialFilters;

  @override
  void initState() {
    super.initState();
    MealService.meals.addListener(_onMealsChanged);
  }

  @override
  void dispose() {
    MealService.meals.removeListener(_onMealsChanged);
    super.dispose();
  }

  void _onMealsChanged() => setState(() {});

  void _showInfoMessage(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleMealFavoriteStatus(Meal meal) {
    final isExisting = _favoriteMeals.contains(meal);
    if (isExisting) {
      setState(() { _favoriteMeals.remove(meal); });
      _showInfoMessage('Meal no longer marked as a favorite.');
    } else {
      setState(() { _favoriteMeals.add(meal); });
      _showInfoMessage('Marked as a favorite!');
    }
  }

  void _selectPage(int index) {
    setState(() { _selectedPageIndex = index; });
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => screen));
  }

  void _setScreen(String identifier) async {
    Navigator.of(context).pop();
    switch (identifier) {
      case 'filters':
        final result = await Navigator.of(context).push<Map<Filter, bool>>(
          MaterialPageRoute(builder: (ctx) => FiltersScreen(currentFilters: _selectedFilters)),
        );
        if (!mounted || result == null) return;
        setState(() { _selectedFilters = result; });
      case 'my-orders':
        _push(const MyOrdersScreen());
      case 'admin-orders':
        _push(const AdminOrdersScreen());
      case 'admin-prices':
        _push(const AdminPricesScreen());
      case 'admin-meals':
        _push(const AdminMealsScreen());
      case 'logout':
        await NotificationService.stop();
        await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableMeals = MealService.meals.value.where((meal) {
      if (_selectedFilters[Filter.glutenFree]! && !meal.isGlutenFree) return false;
      if (_selectedFilters[Filter.lactoseFree]! && !meal.isLactoseFree) return false;
      if (_selectedFilters[Filter.vegetarian]! && !meal.isVegetarian) return false;
      if (_selectedFilters[Filter.vegan]! && !meal.isVegan) return false;
      return true;
    }).toList();

    Widget activePage = CategoriesScreen(
      onToggleFavorite: _toggleMealFavoriteStatus,
      isFavorite: _favoriteMeals.contains,
      availableMeals: availableMeals,
    );
    var activePageTitle = 'Categories';

    if (_selectedPageIndex == 1) {
      activePage = MealsScreen(
        meals: _favoriteMeals,
        onToggleFavorite: _toggleMealFavoriteStatus,
        isFavorite: _favoriteMeals.contains,
      );
      activePageTitle = 'Your Favorites';
    }

    return Scaffold(
      appBar: AppBar(title: Text(activePageTitle)),
      drawer: MainDrawer(onSelectScreen: _setScreen, isAdmin: widget.isAdmin),
      body: activePage,
      bottomNavigationBar: BottomNavigationBar(
        onTap: _selectPage,
        currentIndex: _selectedPageIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.set_meal), label: 'Categories'),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Favorites'),
        ],
      ),
    );
  }
}