# Meal App

A Flutter meal ordering app with Firebase.

## Features

- **Sign up / sign in** with email and password, choosing **User** or **Admin** mode.
- **Browse meals** by category, filter by diet (gluten-free, lactose-free, vegetarian, vegan), and save favorites.
- **Prices** on every meal, updated live.
- **Ordering**: pick a quantity and place an order, then track its status under *My Orders*.
- **Admin tools**:
  - *Manage Orders*: confirm or reject incoming orders.
  - *Manage Meals*: add new meals, or swipe to delete meals you added.
  - *Manage Prices*: change any meal's price.
- **In-app notifications** that slide down from the top and can be swiped away:
  - admins are told about new orders;
  - customers are told when their order is confirmed or rejected.

## Setup

1. Install [Flutter](https://docs.flutter.dev/get-started/install) and the
   [Firebase CLI](https://firebase.google.com/docs/cli), then run `firebase login`.
2. Create a Firebase project and enable **Authentication → Email/Password**
   and **Firestore Database**.
3. Connect the app to your project. This generates `lib/firebase_options.dart`
   and the platform config files, which are not in this repo:
   ```sh
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
4. Run the app:
   ```sh
   flutter pub get
   flutter run -d chrome --web-port 5050
   ```

### Making an admin

Sign up in the app, then in the Firebase console open
**Firestore → `meal_users` → your user's document** and set `role` to `admin`.
Sign in again with **Admin** selected (the person icon on the sign-in screen).

## Data

All collections start with `meal_` so the app can share a Firebase project:

| Collection    | Contents                                     |
| ------------- | -------------------------------------------- |
| `meal_users`  | email and `role` (`user` or `admin`)         |
| `meal_meals`  | meals added by admins                        |
| `meal_prices` | current price of each meal                   |
| `meal_orders` | orders and their status                      |

> **Note:** the app assumes Firestore security rules that allow signed-in users
> to read and write. Admin-only actions are enforced in the app, not by the
> rules, so tighten the rules before using this with real customers.
