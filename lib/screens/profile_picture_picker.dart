// ============================================================
// screens/profile_picture_picker.dart  –  Camera / Gallery Picker
// ============================================================
// Shown when the user taps their profile picture on the Dashboard.
// Lets them take a new photo, choose one from the gallery, or
// remove the current picture.
//
// Picked images are COPIED into the app's permanent documents
// folder (not just referenced by their original temporary path) —
// this guarantees the picture survives even if the original photo
// is later deleted from the camera roll, and always lives at one
// stable, predictable path: <app documents>/profile_picture.jpg
// ============================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/providers.dart';
import '../utils/utils.dart';

Future<void> showProfilePicturePicker(BuildContext context) async {
  final profile = context.read<ProfileProvider>().profile;
  final hasExistingPicture =
      profile?.profileImagePath != null && File(profile!.profileImagePath!).existsSync();

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          const Text('Profile Picture', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
            title: const Text('Take Photo'),
            onTap: () {
              Navigator.pop(sheetContext);
              _pickAndSave(context, ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
            title: const Text('Choose from Gallery'),
            onTap: () {
              Navigator.pop(sheetContext);
              _pickAndSave(context, ImageSource.gallery);
            },
          ),
          if (hasExistingPicture)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetContext);
                _removePhoto(context);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> _pickAndSave(BuildContext context, ImageSource source) async {
  try {
    final picker = ImagePicker();
    // imageQuality + maxWidth keep the stored file small — this is a
    // profile picture, not a full-resolution photo, so there's no
    // need to store multi-megabyte images on the device.
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked == null) return; // user cancelled

    // Copy into a stable, permanent location inside the app's own
    // documents folder — always the same filename, so old profile
    // pictures don't pile up over time.
    final docsDir = await getApplicationDocumentsDirectory();
    final savedPath = '${docsDir.path}/profile_picture.jpg';
    await File(picked.path).copy(savedPath);

    if (!context.mounted) return;
    await context.read<ProfileProvider>().updateProfileImage(savedPath);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated!'), backgroundColor: AppColors.primary),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update profile picture: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

Future<void> _removePhoto(BuildContext context) async {
  final profile = context.read<ProfileProvider>().profile;
  final path = profile?.profileImagePath;

  if (path != null) {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  if (!context.mounted) return;
  await context.read<ProfileProvider>().updateProfileImage(null);
}
