import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerUtil {
  static final _picker = ImagePicker();

  /// Picks an image from the gallery.
  /// Returns raw bytes (works on both mobile and web).
  /// Returns null if the user cancels.
  static Future<Uint8List?> pickFromGallery() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return null;
    return await file.readAsBytes();
  }

  /// Picks an image using the camera (mobile only).
  /// Falls back to gallery on web.
  static Future<Uint8List?> pickFromCamera() async {
    final source = kIsWeb ? ImageSource.gallery : ImageSource.camera;
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (file == null) return null;
    return await file.readAsBytes();
  }

  /// Shows a bottom sheet to let the user choose gallery or camera,
  /// then returns the picked bytes.
  ///
  /// Usage:
  ///   final bytes = await ImagePickerUtil.pickWithChoice(context);
  ///   if (bytes != null) setState(() => _imageBytes = bytes);
  static Future<Uint8List?> pickWithChoice(BuildContext context) async {
    Uint8List? result;

    if (kIsWeb) {
      // On web, just open gallery directly (camera not supported)
      result = await pickFromGallery();
    } else {
      await showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  result = await pickFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  result = await pickFromCamera();
                },
              ),
            ],
          ),
        ),
      );
    }

    return result;
  }
}