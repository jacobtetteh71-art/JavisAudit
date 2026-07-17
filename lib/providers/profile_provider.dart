// ============================================================
// providers/profile_provider.dart  –  Business Profile State
// ============================================================

import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

class ProfileProvider extends ChangeNotifier {
  BusinessProfile? _profile; // null until loaded from database
  bool _isLoading = false;

  BusinessProfile? get profile   => _profile;
  bool             get isLoading => _isLoading;
  bool             get hasProfile => _profile != null;

  // Load the profile from SQLite (called on app startup)
  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    final map = await DatabaseHelper.instance.getProfile();
    _profile = map != null ? BusinessProfile.fromMap(map) : null;

    _isLoading = false;
    notifyListeners();
  }

  // Save a new profile (first launch)
  Future<bool> saveProfile(BusinessProfile profile) async {
    try {
      await DatabaseHelper.instance.insertProfile(profile.toMap());
      _profile = profile;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving profile: $e');
      return false;
    }
  }

  // Update an existing profile (from Settings screen)
  Future<bool> updateProfile(BusinessProfile profile) async {
    try {
      final updatedMap = profile.toMap();
      updatedMap['updated_at'] = DateTime.now().toIso8601String();
      await DatabaseHelper.instance.updateProfile(updatedMap);
      _profile = profile;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }
}
