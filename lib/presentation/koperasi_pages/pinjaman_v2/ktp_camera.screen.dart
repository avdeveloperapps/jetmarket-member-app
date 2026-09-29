import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:jetmarket/infrastructure/theme/app_colors.dart';
import 'package:jetmarket/infrastructure/theme/app_text.dart';

/// Kamera KTP in-app: menggantikan image_picker (kamera bawaan) yang
/// menyebabkan activity Flutter dibunuh OS sehingga aplikasi kembali ke home.
/// Menampilkan overlay bingkai rasio KTP (85.6 x 53.98) + tombol Ambil Foto,
/// lalu pratinjau dengan opsi Ulangi / Pakai Foto.
class KtpCameraScreen extends StatefulWidget {
  const KtpCameraScreen({super.key});

  @override
  State<KtpCameraScreen> createState() => _KtpCameraScreenState();
}

class _KtpCameraScreenState extends State<KtpCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;
  String? _capturedPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_disposeCamera());
      return;
    }
    if (state == AppLifecycleState.resumed &&
        _camera == null &&
        _capturedPath == null) {
      unawaited(_initializeCamera());
    }
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
      });
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
            'CameraUnavailable', 'Kamera tidak ditemukan pada perangkat.');
      }
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        selected,
        // medium, bukan high: buffer capture full-res + decode pratinjau
        // membuat HP RAM kecil OOM dan force-close tepat setelah shutter.
        // KTP masih terbaca jelas pada preset ini; file asli tetap dipakai
        // untuk upload.
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await camera.initialize();
      await camera.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() {
        _camera = camera;
        _initializing = false;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = error.description ??
            'Kamera tidak dapat dibuka. Periksa izin kamera lalu coba lagi.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Kamera tidak dapat dibuka. Silakan coba lagi.';
      });
    }
  }

  Future<void> _disposeCamera() async {
    final camera = _camera;
    _camera = null;
    try {
      await camera?.dispose();
    } catch (_) {
      // Abaikan: dispose saat lifecycle berubah tidak boleh melempar.
    }
  }

  Future<void> _takePicture() async {
    final camera = _camera;
    if (camera == null ||
        !camera.value.isInitialized ||
        camera.value.isTakingPicture ||
        _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final file = await camera.takePicture();
      if (!mounted) return;
      setState(() {
        _capturedPath = file.path;
        _capturing = false;
      });
      await _disposeCamera();
    } on CameraException catch (error) {
      developer.log('KTP capture gagal',
          name: 'KtpCameraScreen',
          error: '${error.code}: ${error.description}');
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = error.description ?? 'Gagal mengambil foto. Coba lagi.';
      });
    } catch (error) {
      // Perangkat/OEM berbeda melempar tipe exception berbeda dari
      // takePicture (tidak selalu CameraException). Tanpa catch umum ini,
      // exception lolos ke Flutter framework dan aplikasi force-close.
      developer.log('KTP capture gagal (non-kamera)',
          name: 'KtpCameraScreen', error: error);
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error =
            'Gagal mengambil foto di perangkat ini. Coba lagi atau gunakan HP lain.';
      });
    }
  }

  void _retake() {
    final path = _capturedPath;
    _capturedPath = null;
    if (path != null) {
      try {
        File(path).deleteSync();
      } catch (_) {
        // Abaikan: file pratinjau yang dibuang tidak wajib terhapus.
      }
    }
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeCamera());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text('Foto KTP', style: text16BlackSemiBold.copyWith(color: Colors.white))),
        body: _error != null
            ? _errorBody()
            : _capturedPath != null
                ? _previewBody()
                : _cameraBody(),
      );

  Widget _errorBody() => Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.videocam_off_outlined,
                color: Colors.white70, size: 44),
            Gap(12.h),
            Text(_error ?? 'Kamera tidak dapat dibuka.',
                style: text12HintRegular.copyWith(color: Colors.white70),
                textAlign: TextAlign.center),
            Gap(16.h),
            ElevatedButton.icon(
              onPressed: () => Get.back(),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Kembali'),
            ),
          ]),
        ),
      );

  Widget _cameraBody() {
    final camera = _camera;
    if (_initializing || camera == null || !camera.value.isInitialized) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    return LayoutBuilder(builder: (context, constraints) {
      final frameWidth = constraints.maxWidth - 48.w;
      final frameHeight = frameWidth / _ktpAspectRatio;
      return Stack(children: [
        Positioned.fill(child: CameraPreview(camera)),
        Positioned.fill(
            child: CustomPaint(
                painter: _KtpFramePainter(
                    frameWidth: frameWidth, frameHeight: frameHeight))),
        Positioned(
          top: (constraints.maxHeight - frameHeight) / 2 - 44.h,
          left: 0,
          right: 0,
          child: Text('Posisikan KTP di dalam bingkai',
              style: text12HintRegular.copyWith(color: Colors.white),
              textAlign: TextAlign.center),
        ),
        Positioned(
          bottom: 32.h,
          left: 24.w,
          right: 24.w,
          child: SizedBox(
            height: 48.h,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: kSecondaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r))),
              onPressed: _capturing ? null : _takePicture,
              icon: _capturing
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.camera_alt_rounded, color: Colors.white),
              label: Text(_capturing ? 'Mengambil...' : 'Ambil Foto',
                  style: text14BlackSemiBold.copyWith(color: Colors.white)),
            ),
          ),
        ),
      ]);
    });
  }

  Widget _previewBody() => Column(children: [
        Expanded(
            child: Padding(
                padding: EdgeInsets.all(16.r),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    // Batasi decode pratinjau: file asli bisa belasan MP dan
                    // meledakkan memori HP lemah tepat setelah shutter.
                    // File asli (full-res) tetap yang dikirim ke server.
                    child: Image.file(File(_capturedPath!),
                        fit: BoxFit.contain,
                        width: double.infinity,
                        cacheWidth: 1080)))),
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
          child: Row(children: [
            Expanded(
                child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r))),
                    onPressed: _retake,
                    child: const Text('Ulangi'))),
            Gap(12.w),
            Expanded(
                child: SizedBox(
              height: 48.h,
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kSecondaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r))),
                  onPressed: () => Get.back(result: _capturedPath),
                  child: Text('Pakai Foto',
                      style:
                          text14BlackSemiBold.copyWith(color: Colors.white))),
            )),
          ]),
        ),
      ]);
}

/// Rasio kartu identitas ISO/IEC 7810 ID-1 (85.60 x 53.98 mm).
const double _ktpAspectRatio = 85.60 / 53.98;

class _KtpFramePainter extends CustomPainter {
  _KtpFramePainter({required this.frameWidth, required this.frameHeight});

  final double frameWidth;
  final double frameHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final frameLeft = (size.width - frameWidth) / 2;
    final frameTop = (size.height - frameHeight) / 2;
    final frameRect = Rect.fromLTWH(frameLeft, frameTop, frameWidth, frameHeight);
    final frameRRect =
        RRect.fromRectAndRadius(frameRect, Radius.circular(12.r));

    final dimPaint = Paint()..color = Colors.black.withValues(alpha: .62);
    canvas.drawPath(
        Path()
          ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
          ..addRRect(frameRRect)
          ..fillType = PathFillType.evenOdd,
        dimPaint);

    final borderPaint = Paint()
      ..color = kPrimaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(frameRRect, borderPaint);

    final cornerLength = math.min(frameWidth, frameHeight) * .18;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final corners = [
      frameRect.topLeft,
      frameRect.topRight,
      frameRect.bottomLeft,
      frameRect.bottomRight,
    ];
    for (final corner in corners) {
      final dx = corner.dx < size.width / 2 ? 1.0 : -1.0;
      final dy = corner.dy < size.height / 2 ? 1.0 : -1.0;
      canvas.drawLine(
          corner, corner.translate(dx * cornerLength, 0), cornerPaint);
      canvas.drawLine(
          corner, corner.translate(0, dy * cornerLength), cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _KtpFramePainter oldDelegate) =>
      oldDelegate.frameWidth != frameWidth ||
      oldDelegate.frameHeight != frameHeight;
}
