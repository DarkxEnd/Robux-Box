import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

/// Build-time configuration.
final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

/// Firebase SDK singletons, injected rather than reached for globally so tests
/// can substitute fakes.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final functionsProvider = Provider<FirebaseFunctions>((ref) {
  // Every callable is deployed to us-central1; using the default region here
  // silently 404s instead.
  return FirebaseFunctions.instanceFor(region: 'us-central1');
});

final storageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

/// The current signed-in user, or null. Rebuilds on every auth change.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// The current uid, or null when signed out.
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});
