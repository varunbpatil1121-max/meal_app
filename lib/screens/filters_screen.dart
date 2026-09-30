import 'package:flutter/material.dart';

enum Filter { glutenFree, lactoseFree, vegetarian, vegan }

class FiltersScreen extends StatefulWidget {
  const FiltersScreen({super.key, required this.currentFilters});

  final Map<Filter, bool> currentFilters;

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  var _glutenFreeFilterSet = false;
  var _lactoseFreeFilterSet = false;
  var _vegetarianFilterSet = false;
  var _veganFilterSet = false;

  @override
  void initState() {
    super.initState();
    _glutenFreeFilterSet = widget.currentFilters[Filter.glutenFree]!;
    _lactoseFreeFilterSet = widget.currentFilters[Filter.lactoseFree]!;
    _vegetarianFilterSet = widget.currentFilters[Filter.vegetarian]!;
    _veganFilterSet = widget.currentFilters[Filter.vegan]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Filters')),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
          Navigator.of(context).pop({
            Filter.glutenFree: _glutenFreeFilterSet,
            Filter.lactoseFree: _lactoseFreeFilterSet,
            Filter.vegetarian: _vegetarianFilterSet,
            Filter.vegan: _veganFilterSet,
          });
        },
        child: Column(
          children: [
            SwitchListTile(
              value: _glutenFreeFilterSet,
              onChanged: (isChecked) => setState(() => _glutenFreeFilterSet = isChecked),
              title: const Text('Gluten-free'),
              subtitle: const Text('Only include gluten-free meals.'),
            ),
            SwitchListTile(
              value: _lactoseFreeFilterSet,
              onChanged: (isChecked) => setState(() => _lactoseFreeFilterSet = isChecked),
              title: const Text('Lactose-free'),
              subtitle: const Text('Only include lactose-free meals.'),
            ),
            SwitchListTile(
              value: _vegetarianFilterSet,
              onChanged: (isChecked) => setState(() => _vegetarianFilterSet = isChecked),
              title: const Text('Vegetarian'),
              subtitle: const Text('Only include vegetarian meals.'),
            ),
            SwitchListTile(
              value: _veganFilterSet,
              onChanged: (isChecked) => setState(() => _veganFilterSet = isChecked),
              title: const Text('Vegan'),
              subtitle: const Text('Only include vegan meals.'),
            ),
          ],
        ),
      ),
    );
  }
}