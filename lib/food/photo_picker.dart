import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' as image_picker;

import 'config.dart';
import 'models.dart';

enum FoodPhotoSource { camera, gallery }

enum FoodPhotoPickOutcome { selected, cancelled, unavailable, failed }

enum FoodPhotoPlatform { mobile, desktop, unsupported }

final class FoodPhotoSourceData {
  final Uint8List bytes;
  final String name;

  const FoodPhotoSourceData({required this.bytes, required this.name});
}

typedef FoodPhotoAcquirer =
    Future<FoodPhotoSourceData?> Function(FoodPhotoSource source);

final class FoodPhotoPickResult {
  final FoodPhotoPickOutcome outcome;
  final FoodVisionImage? image;
  final String? message;

  const FoodPhotoPickResult._({
    required this.outcome,
    this.image,
    this.message,
  });

  const FoodPhotoPickResult.selected(FoodVisionImage value)
    : this._(outcome: FoodPhotoPickOutcome.selected, image: value);

  const FoodPhotoPickResult.cancelled()
    : this._(outcome: FoodPhotoPickOutcome.cancelled);

  const FoodPhotoPickResult.unavailable(String detail)
    : this._(outcome: FoodPhotoPickOutcome.unavailable, message: detail);

  const FoodPhotoPickResult.failed(String detail)
    : this._(outcome: FoodPhotoPickOutcome.failed, message: detail);

  bool get selected =>
      outcome == FoodPhotoPickOutcome.selected && image != null;
}

/// Acquires scanner photos and converts them to bounded metadata-free PNGs.
///
/// The original two-value [FoodPhotoSource] enum stays stable so existing
/// exhaustive UI switches remain source-compatible. Explicit Files access is
/// exposed through [pickFiles], which uses the OS document picker and then the
/// exact same size/decode/re-encode privacy boundary.
final class FoodPhotoPicker {
  FoodPhotoPicker({
    this.acquirer,
    FoodPhotoPlatform? platform,
    image_picker.ImagePicker? mobilePicker,
    Future<file_selector.XFile?> Function()? desktopFilePicker,
  }) : _platform = platform ?? _detectPlatform(),
       _mobilePicker = mobilePicker ?? image_picker.ImagePicker(),
       _desktopFilePicker = desktopFilePicker ?? _openImageFile;

  static final FoodPhotoPicker instance = FoodPhotoPicker();

  final FoodPhotoAcquirer? acquirer;
  final FoodPhotoPlatform _platform;
  final image_picker.ImagePicker _mobilePicker;
  final Future<file_selector.XFile?> Function() _desktopFilePicker;

  Future<FoodPhotoPickResult> captureCamera() {
    return pick(FoodPhotoSource.camera);
  }

  Future<FoodPhotoPickResult> pickGallery() {
    return pick(FoodPhotoSource.gallery);
  }

  Future<FoodPhotoPickResult> pickFiles() async {
    Uint8List? workingBytes;
    try {
      final acquired = await _acquireSystemFile();
      if (acquired == null) return const FoodPhotoPickResult.cancelled();
      _validateSourceLength(acquired.bytes.length);
      workingBytes = Uint8List.fromList(acquired.bytes);
      final image = await _normalize(workingBytes, acquired.name);
      return FoodPhotoPickResult.selected(image);
    } on MissingPluginException {
      return const FoodPhotoPickResult.unavailable(
        'The system file picker is unavailable in this build.',
      );
    } on UnsupportedError catch (error) {
      return FoodPhotoPickResult.unavailable(_friendlyError(error));
    } on FormatException catch (error) {
      return FoodPhotoPickResult.failed(error.message.toString());
    } on PlatformException catch (error) {
      final detail = error.message?.trim();
      return FoodPhotoPickResult.failed(
        detail == null || detail.isEmpty
            ? 'The system file picker failed (${error.code}).'
            : detail,
      );
    } catch (error) {
      return FoodPhotoPickResult.failed(_friendlyError(error));
    } finally {
      workingBytes?.fillRange(0, workingBytes.length, 0);
    }
  }

  Future<FoodPhotoPickResult> pick(FoodPhotoSource source) async {
    Uint8List? workingBytes;
    try {
      final acquired = await (acquirer?.call(source) ?? _acquire(source));
      if (acquired == null) return const FoodPhotoPickResult.cancelled();
      _validateSourceLength(acquired.bytes.length);
      workingBytes = Uint8List.fromList(acquired.bytes);
      final image = await _normalize(workingBytes, acquired.name);
      return FoodPhotoPickResult.selected(image);
    } on MissingPluginException {
      return const FoodPhotoPickResult.unavailable(
        'Photo selection is unavailable in this build. Fully restart or rebuild the app to register the native picker.',
      );
    } on UnsupportedError catch (error) {
      return FoodPhotoPickResult.unavailable(_friendlyError(error));
    } on FormatException catch (error) {
      return FoodPhotoPickResult.failed(error.message.toString());
    } on PlatformException catch (error) {
      final detail = _platformError(error, source);
      return _isUnavailablePlatformError(error)
          ? FoodPhotoPickResult.unavailable(detail)
          : FoodPhotoPickResult.failed(detail);
    } catch (error) {
      return FoodPhotoPickResult.failed(_friendlyError(error));
    } finally {
      workingBytes?.fillRange(0, workingBytes.length, 0);
    }
  }

  Future<FoodPhotoSourceData?> _acquire(FoodPhotoSource source) async {
    switch (_platform) {
      case FoodPhotoPlatform.mobile:
        return _acquireMobile(source);
      case FoodPhotoPlatform.desktop:
        if (source == FoodPhotoSource.camera) {
          throw UnsupportedError(
            'Camera capture is available on Android and iOS. On desktop, choose an existing scanner photo.',
          );
        }
        return _acquireSystemFile();
      case FoodPhotoPlatform.unsupported:
        throw UnsupportedError(
          'Photo selection is unavailable on this platform.',
        );
    }
  }

  Future<FoodPhotoSourceData?> _acquireMobile(FoodPhotoSource source) async {
    final picked = await _mobilePicker.pickImage(
      source: source == FoodPhotoSource.camera
          ? image_picker.ImageSource.camera
          : image_picker.ImageSource.gallery,
      maxWidth: FoodVisionConfig.visionMaxImageDimension.toDouble(),
      maxHeight: FoodVisionConfig.visionMaxImageDimension.toDouble(),
      imageQuality: 95,
      requestFullMetadata: false,
    );
    if (picked == null) return null;
    final length = await picked.length();
    _validateSourceLength(length);
    return FoodPhotoSourceData(
      bytes: await picked.readAsBytes(),
      name: picked.name,
    );
  }

  Future<FoodPhotoSourceData?> _acquireSystemFile() async {
    if (_platform == FoodPhotoPlatform.unsupported) {
      throw UnsupportedError('File selection is unavailable on this platform.');
    }
    final picked = await _desktopFilePicker();
    if (picked == null) return null;
    final length = await picked.length();
    _validateSourceLength(length);
    return FoodPhotoSourceData(
      bytes: await picked.readAsBytes(),
      name: picked.name,
    );
  }

  static Future<file_selector.XFile?> _openImageFile() {
    return file_selector.openFile(
      acceptedTypeGroups: const <file_selector.XTypeGroup>[
        file_selector.XTypeGroup(
          label: 'Scanner photos',
          extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
        ),
      ],
      confirmButtonText: 'Choose photo',
    );
  }

  static void _validateSourceLength(int length) {
    if (length <= 0) {
      throw const FormatException('The selected image is empty.');
    }
    if (length > FoodVisionConfig.visionMaxSourceImageBytes) {
      throw const FormatException(
        'The selected image exceeds the 32 MB source limit.',
      );
    }
  }

  static Future<FoodVisionImage> _normalize(
    Uint8List sourceBytes,
    String sourceName,
  ) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? decoded;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(sourceBytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width <= 0 || descriptor.height <= 0) {
        throw const FormatException(
          'The selected file is not a supported image.',
        );
      }
      if (descriptor.width > 100000 || descriptor.height > 100000) {
        throw const FormatException(
          'The selected image dimensions are not supported.',
        );
      }

      final longestSide = math.max(descriptor.width, descriptor.height);
      final scale = math.min(
        1.0,
        FoodVisionConfig.visionMaxImageDimension / longestSide,
      );
      final targetWidth = math.max(1, (descriptor.width * scale).round());
      final targetHeight = math.max(1, (descriptor.height * scale).round());
      codec = await descriptor.instantiateCodec(
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      decoded = frame.image;
      final encoded = await decoded.toByteData(format: ui.ImageByteFormat.png);
      if (encoded == null || encoded.lengthInBytes == 0) {
        throw const FormatException(
          'The selected image could not be normalized.',
        );
      }
      if (encoded.lengthInBytes > FoodVisionConfig.visionMaxImageBytes) {
        throw const FormatException(
          'The normalized image exceeds the 8 MB vision limit.',
        );
      }

      return FoodVisionImage(
        bytes: Uint8List.fromList(
          encoded.buffer.asUint8List(
            encoded.offsetInBytes,
            encoded.lengthInBytes,
          ),
        ),
        name: _pngName(sourceName),
        width: decoded.width,
        height: decoded.height,
      );
    } finally {
      decoded?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  static FoodPhotoPlatform _detectPlatform() {
    if (kIsWeb) return FoodPhotoPlatform.desktop;
    if (Platform.isAndroid || Platform.isIOS) {
      return FoodPhotoPlatform.mobile;
    }
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      return FoodPhotoPlatform.desktop;
    }
    return FoodPhotoPlatform.unsupported;
  }

  static String _pngName(String sourceName) {
    final leaf = sourceName.trim().split(RegExp(r'[/\\]')).last;
    final dot = leaf.lastIndexOf('.');
    final rawStem = dot > 0 ? leaf.substring(0, dot) : leaf;
    final stem = rawStem.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_').trim();
    return '${stem.isEmpty ? 'scanner-photo' : stem}.png';
  }

  static bool _isUnavailablePlatformError(PlatformException error) {
    final code = error.code.toLowerCase();
    return code.contains('no_available_camera') ||
        code.contains('camera_unavailable') ||
        code.contains('unavailable') ||
        code.contains('not_supported');
  }

  static String _platformError(
    PlatformException error,
    FoodPhotoSource source,
  ) {
    final code = error.code.toLowerCase();
    if (code.contains('camera_access_denied') ||
        code.contains('camera_permission')) {
      return 'Camera access was denied. Allow camera access in system settings, then try again.';
    }
    if (code.contains('photo_access_denied') ||
        code.contains('photo_permission')) {
      return 'Photo-library access was denied. Allow photo access in system settings, then try again.';
    }
    if (_isUnavailablePlatformError(error)) {
      return source == FoodPhotoSource.camera
          ? 'No usable camera is available on this device.'
          : 'The system photo-library picker is unavailable on this device.';
    }
    final detail = error.message?.trim();
    return detail == null || detail.isEmpty
        ? 'The system photo picker failed (${error.code}).'
        : detail;
  }

  static String _friendlyError(Object error) {
    final detail = error
        .toString()
        .replaceFirst(
          RegExp(r'^(Exception|StateError|Unsupported operation):\s*'),
          '',
        )
        .trim();
    return detail.isEmpty
        ? 'The selected photo could not be prepared.'
        : detail;
  }
}
