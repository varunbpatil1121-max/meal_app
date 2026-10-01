// Used by CI when the real lib/firebase_options.dart (which is gitignored)
// isn't available. The app compiles with it but can't connect to Firebase.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
        'Firebase is not configured. Run `flutterfire configure` to generate '
        'lib/firebase_options.dart.',
      );
}
