import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meal_app/config.dart';
import 'package:meal_app/data/dummy_data.dart';
import 'package:meal_app/models/meal.dart';
import 'package:meal_app/services/meal_service.dart';

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imageUrl = TextEditingController();
  var _title = '';
  var _price = 0;
  var _duration = 0;
  var _ingredients = <String>[];
  var _steps = <String>[];
  final _categories = <String>{};
  var _complexity = Complexity.simple;
  var _affordability = Affordability.affordable;
  var _isGlutenFree = false;
  var _isLactoseFree = false;
  var _isVegetarian = false;
  var _isVegan = false;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Rebuild so the image preview follows the URL field.
    _imageUrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _imageUrl.dispose();
    super.dispose();
  }

  static List<String> _lines(String? text) => (text ?? '')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  static String? _positiveNumber(String? value) =>
      (int.tryParse(value ?? '') ?? 0) > 0 ? null : 'Enter a number above 0';

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one category.')),
      );
      return;
    }
    if (!valid) return;
    _formKey.currentState!.save();

    setState(() { _isSaving = true; });
    final meal = Meal(
      id: '', // assigned by Firestore
      categories: _categories.toList(),
      title: _title,
      imageUrl: _imageUrl.text.trim(),
      ingredients: _ingredients,
      steps: _steps,
      duration: _duration,
      price: _price,
      complexity: _complexity,
      affordability: _affordability,
      isGlutenFree: _isGlutenFree,
      isLactoseFree: _isLactoseFree,
      isVegan: _isVegan,
      isVegetarian: _isVegetarian,
    );
    try {
      await MealService.addMeal(meal);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"${meal.title}" added to the menu.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() { _isSaving = false; });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save meal: $e')));
    }
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  @override
  Widget build(BuildContext context) {
    final url = _imageUrl.text.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Add Meal')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: 'Meal name'),
              textCapitalization: TextCapitalization.words,
              validator: _required,
              onSaved: (value) => _title = value!.trim(),
            ),
            TextFormField(
              controller: _imageUrl,
              decoration: const InputDecoration(
                labelText: 'Image link',
                hintText: 'https://…/photo.jpg',
              ),
              keyboardType: TextInputType.url,
              validator: (value) => Uri.tryParse(value?.trim() ?? '')?.hasAbsolutePath == true &&
                      (value!.trim().startsWith('http://') || value.trim().startsWith('https://'))
                  ? null
                  : 'Enter a full link starting with https://',
            ),
            if (url.startsWith('http'))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    url,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, error, stackTrace) => const SizedBox(
                      height: 80,
                      child: Center(child: Text("Can't load this image")),
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Price', prefixText: kCurrency),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _positiveNumber,
                    onSaved: (value) => _price = int.parse(value!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Time', suffixText: 'min'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _positiveNumber,
                    onSaved: (value) => _duration = int.parse(value!),
                  ),
                ),
              ],
            ),
            _heading('Categories'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in availableCategories)
                  FilterChip(
                    label: Text(category.title),
                    selected: _categories.contains(category.id),
                    onSelected: (selected) => setState(() {
                      selected ? _categories.add(category.id) : _categories.remove(category.id);
                    }),
                  ),
              ],
            ),
            _heading('Difficulty'),
            SegmentedButton<Complexity>(
              segments: const [
                ButtonSegment(value: Complexity.simple, label: Text('Simple')),
                ButtonSegment(value: Complexity.challenging, label: Text('Challenging')),
                ButtonSegment(value: Complexity.hard, label: Text('Hard')),
              ],
              selected: {_complexity},
              onSelectionChanged: (value) => setState(() { _complexity = value.first; }),
            ),
            _heading('Cost'),
            SegmentedButton<Affordability>(
              segments: const [
                ButtonSegment(value: Affordability.affordable, label: Text('Affordable')),
                ButtonSegment(value: Affordability.pricey, label: Text('Pricey')),
                ButtonSegment(value: Affordability.luxurious, label: Text('Luxurious')),
              ],
              selected: {_affordability},
              onSelectionChanged: (value) => setState(() { _affordability = value.first; }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Ingredients',
                helperText: 'One per line',
                alignLabelWithHint: true,
              ),
              minLines: 3,
              maxLines: null,
              validator: (value) => _lines(value).isEmpty ? 'Add at least one ingredient' : null,
              onSaved: (value) => _ingredients = _lines(value),
            ),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Steps',
                helperText: 'One per line',
                alignLabelWithHint: true,
              ),
              minLines: 3,
              maxLines: null,
              validator: (value) => _lines(value).isEmpty ? 'Add at least one step' : null,
              onSaved: (value) => _steps = _lines(value),
            ),
            _heading('Dietary'),
            SwitchListTile(
              title: const Text('Gluten-free'),
              value: _isGlutenFree,
              onChanged: (value) => setState(() { _isGlutenFree = value; }),
            ),
            SwitchListTile(
              title: const Text('Lactose-free'),
              value: _isLactoseFree,
              onChanged: (value) => setState(() { _isLactoseFree = value; }),
            ),
            SwitchListTile(
              title: const Text('Vegetarian'),
              value: _isVegetarian,
              onChanged: (value) => setState(() { _isVegetarian = value; }),
            ),
            SwitchListTile(
              title: const Text('Vegan'),
              value: _isVegan,
              onChanged: (value) => setState(() {
                _isVegan = value;
                if (value) _isVegetarian = true;
              }),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Save meal'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
