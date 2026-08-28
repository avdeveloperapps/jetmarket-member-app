import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jetmarket/infrastructure/theme/app_colors.dart';
import 'package:jetmarket/infrastructure/theme/app_text.dart';
import 'package:jetmarket/presentation/koperasi_pages/pinjaman_v2/controllers/loan_v2.controller.dart';

class LoanActiveLivenessCaptureScreen extends StatefulWidget {
  const LoanActiveLivenessCaptureScreen({
    super.key,
    required this.controller,
  });

  final LoanV2Controller controller;

  @override
  State<LoanActiveLivenessCaptureScreen> createState() =>
      _LoanActiveLivenessCaptureScreenState();
}

class _LoanActiveLivenessCaptureScreenState
    extends State<LoanActiveLivenessCaptureScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _camera;
  late final AnimationController _guideAnimation;
  List<dynamic> _actions = const [];
  int _actionIndex = -1;
  int _countdown = 0;
  bool _initializing = true;
  bool _capturing = false;
  bool _aborted = false;
  String? _error;

  bool get _cameraReady => _camera?.value.isInitialized == true;
  bool get _showingAction =>
      _actionIndex >= 0 && _actionIndex < _actions.length;

  @override
  void initState() {
    super.initState();
    _guideAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _aborted = true;
      unawaited(_disposeCamera());
      return;
    }
    if (state == AppLifecycleState.resumed && !_capturing && _camera == null) {
      _aborted = false;
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
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await camera.initialize();
      if (!mounted || _aborted) {
        await camera.dispose();
        return;
      }
      await _camera?.dispose();
      setState(() {
        _camera = camera;
        _initializing = false;
      });
    } on CameraException catch (exception) {
      _setError(_cameraError(exception));
    } catch (_) {
      _setError(
          'Kamera tidak dapat dibuka. Tutup aplikasi lain yang memakai kamera lalu coba lagi.');
    }
  }

  Future<void> _startCapture() async {
    final camera = _camera;
    if (!_cameraReady || camera == null || _capturing) return;
    _aborted = false;
    setState(() {
      _capturing = true;
      _error = null;
      _countdown = 0;
      _actionIndex = -1;
    });

    try {
      var challenge = widget.controller.livenessChallenge.value;
      if (!_challengeIsUsable(challenge)) {
        final selfie = await camera.takePicture();
        if (_aborted || !mounted) return;
        final created =
            await widget.controller.prepareLivenessChallenge(selfie.path);
        if (!mounted) return;
        if (!created || _aborted) {
          if (widget.controller.livenessSubmitted.value) {
            Navigator.of(context).pop();
            return;
          }
          throw const _CaptureFlowException(
              'Foto referensi atau tantangan liveness gagal diamankan. Silakan coba lagi.');
        }
        challenge = widget.controller.livenessChallenge.value;
      }

      final actions = List<dynamic>.from(challenge?['actions'] ?? const []);
      if (actions.isEmpty) {
        throw const _CaptureFlowException(
            'Tantangan liveness tidak valid. Silakan buat tantangan baru.');
      }
      setState(() => _actions = actions);

      for (var value = 3; value > 0; value--) {
        if (_aborted || !mounted) return;
        setState(() => _countdown = value);
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (_aborted || !mounted) return;
      setState(() {
        _countdown = 0;
        _actionIndex = -2;
      });
      await camera.startVideoRecording();
      await Future<void>.delayed(const Duration(milliseconds: 1800));

      for (var index = 0; index < actions.length; index++) {
        if (_aborted || !mounted) return;
        setState(() => _actionIndex = index);
        final action = actions[index].toString();
        await Future<void>.delayed(
            Duration(milliseconds: action == 'BLINK' ? 3200 : 2800));
      }
      if (_aborted || !mounted) return;
      setState(() => _actionIndex = actions.length);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final video = await camera.stopVideoRecording();
      if (!mounted) return;
      Navigator.of(context).pop(video.path);
    } on CameraException catch (exception) {
      await _stopRecordingIfNeeded();
      _setError(_cameraError(exception));
    } on _CaptureFlowException catch (exception) {
      await _stopRecordingIfNeeded();
      _setError(exception.message);
    } catch (_) {
      await _stopRecordingIfNeeded();
      _setError(
          'Active liveness gagal direkam. Pastikan wajah terlihat jelas lalu coba lagi.');
    } finally {
      if (mounted) {
        setState(() {
          _capturing = false;
          _countdown = 0;
          _actionIndex = -1;
        });
      }
    }
  }

  bool _challengeIsUsable(Map<String, dynamic>? challenge) {
    if (challenge == null ||
        challenge['session_id'] == null ||
        challenge['nonce'] == null ||
        List<dynamic>.from(challenge['actions'] ?? const []).isEmpty) {
      return false;
    }
    final expiresAt =
        DateTime.tryParse(challenge['expires_at']?.toString() ?? '');
    return expiresAt == null || expiresAt.isAfter(DateTime.now().toUtc());
  }

  Future<void> _cancel() async {
    _aborted = true;
    await _stopRecordingIfNeeded();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _stopRecordingIfNeeded() async {
    final camera = _camera;
    if (camera?.value.isRecordingVideo == true) {
      try {
        await camera!.stopVideoRecording();
      } on CameraException {
        // The capture is already being discarded.
      }
    }
  }

  Future<void> _disposeCamera() async {
    final camera = _camera;
    _camera = null;
    await _shutdownCamera(camera);
    if (mounted) setState(() {});
  }

  Future<void> _shutdownCamera(CameraController? camera) async {
    if (camera == null) return;
    if (camera.value.isRecordingVideo) {
      try {
        await camera.stopVideoRecording();
      } on CameraException {
        // The interrupted capture is discarded.
      }
    }
    await camera.dispose();
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _initializing = false;
      _capturing = false;
      _countdown = 0;
      _actionIndex = -1;
    });
  }

  String _cameraError(CameraException exception) => switch (exception.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' =>
          'Izin kamera ditolak. Aktifkan izin kamera Jet Market melalui pengaturan perangkat.',
        'CameraAccessRestricted' =>
          'Akses kamera dibatasi oleh pengaturan perangkat.',
        _ => exception.description ??
            'Kamera tidak dapat digunakan. Silakan coba lagi.',
      };

  @override
  void dispose() {
    _aborted = true;
    _guideAnimation.dispose();
    WidgetsBinding.instance.removeObserver(this);
    final camera = _camera;
    _camera = null;
    unawaited(_shutdownCamera(camera));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_capturing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancel());
      },
      child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
              child: Stack(fit: StackFit.expand, children: [
            _cameraLayer(),
            _faceGuide(),
            _topBar(),
            _instructionPanel(),
          ]))));

  Widget _cameraLayer() {
    if (!_cameraReady || _camera == null) {
      return Center(
          child: _initializing
              ? const CircularProgressIndicator(color: kWhite)
              : const Icon(Icons.videocam_off_outlined,
                  color: kWhite, size: 48));
    }
    final screenAspectRatio = MediaQuery.sizeOf(context).aspectRatio;
    final previewScale = 1 / (_camera!.value.aspectRatio * screenAspectRatio);
    return ColoredBox(
        color: Colors.black,
        child: Transform.scale(
            scale: previewScale < 1 ? 1 : previewScale,
            child: Center(child: CameraPreview(_camera!))));
  }

  Widget _faceGuide() => IgnorePointer(
        child: Center(
          child: SizedBox(
            width: 286.w,
            height: 382.h,
            child: AnimatedBuilder(
              animation: _guideAnimation,
              builder: (_, __) => CustomPaint(
                painter: _LivenessFaceGuidePainter(
                  progress: _guideProgress,
                  pulse: _guideAnimation.value,
                  isCapturing: _capturing,
                  isReady: _cameraReady,
                ),
                child: Center(
                  child: Container(
                    width: 217.w,
                    height: 292.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(116.r, 154.r),
                      ),
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: _capturing ? .72 : .48),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  double get _guideProgress {
    if (!_capturing || _actions.isEmpty) return 0;
    if (_actionIndex < 0) return .06;
    return ((_actionIndex + 1) / _actions.length).clamp(.06, 1.0).toDouble();
  }

  Widget _topBar() => Align(
      alignment: Alignment.topCenter,
      child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          child: Row(children: [
            IconButton(
                onPressed: _capturing ? null : _cancel,
                icon: const Icon(Icons.close_rounded, color: kWhite)),
            Expanded(
                child: Text('Active Liveness',
                    textAlign: TextAlign.center,
                    style: text16BlackSemiBold.copyWith(color: kWhite))),
            SizedBox(width: 48.w),
          ])));

  Widget _instructionPanel() => Align(
      alignment: Alignment.bottomCenter,
      child: Container(
          width: double.infinity,
          margin: EdgeInsets.all(16.r),
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: Colors.white24)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_capturing)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                    width: 8.r,
                    height: 8.r,
                    decoration: const BoxDecoration(
                        color: kErrorColor, shape: BoxShape.circle)),
                Gap(7.w),
                Text('MEREKAM', style: text12WhiteMedium),
              ]),
            if (_capturing) Gap(10.h),
            Text(_instructionTitle(),
                textAlign: TextAlign.center, style: text20WhiteSemiBold),
            Gap(5.h),
            if (_showingAction) ...[
              Icon(_instructionIcon(_actions[_actionIndex]),
                  color: kSuccessColor, size: 28.r),
              Gap(5.h),
            ],
            Text(_instructionDetail(),
                textAlign: TextAlign.center, style: text12WhiteRegular),
            if (_capturing && _actions.isNotEmpty) ...[
              Gap(13.h),
              ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                      minHeight: 5.h,
                      value: ((_actionIndex + 1) / _actions.length)
                          .clamp(0.0, 1.0),
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(kSuccessColor))),
            ],
            if (_error != null) ...[
              Gap(10.h),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: text12WhiteRegular.copyWith(color: kErrorColor2)),
            ],
            if (!_capturing) ...[
              Gap(14.h),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: _cameraReady ? _startCapture : null,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          foregroundColor: kWhite,
                          padding: EdgeInsets.symmetric(vertical: 13.h),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r))),
                      child: Text(
                          _error == null ? 'Mulai Verifikasi' : 'Coba Lagi'))),
            ]
          ])));

  String _instructionTitle() {
    if (_countdown > 0) return '$_countdown';
    if (_capturing && _actionIndex == -2) return 'Hadap lurus';
    if (_showingAction) return _livenessLabel(_actions[_actionIndex]);
    if (_capturing && _actionIndex >= _actions.length) return 'Tahan sebentar';
    if (_initializing) return 'Menyiapkan kamera';
    return 'Posisikan wajah di dalam bingkai';
  }

  String _instructionDetail() {
    if (_countdown > 0) return 'Tetap menghadap kamera';
    if (_capturing && _actionIndex == -2) {
      return 'Tahan wajah lurus untuk kalibrasi awal.';
    }
    if (_showingAction) return _livenessHint(_actions[_actionIndex]);
    if (_capturing) return 'Rekaman sedang diamankan';
    return 'Lepas masker dan kacamata gelap. Pastikan pencahayaan cukup.';
  }

  String _livenessLabel(dynamic action) => switch (action.toString()) {
        'TURN_LEFT' => 'Lihat ke kiri',
        'TURN_RIGHT' => 'Lihat ke kanan',
        'LOOK_UP' => 'Lihat ke atas',
        'LOOK_DOWN' => 'Lihat ke bawah',
        'BLINK' => 'Kedipkan mata',
        _ => 'Ikuti instruksi',
      };

  String _livenessHint(dynamic action) => switch (action.toString()) {
        'TURN_LEFT' ||
        'TURN_RIGHT' =>
          'Putar kepala perlahan, lalu tahan sampai instruksi berubah.',
        'LOOK_UP' ||
        'LOOK_DOWN' =>
          'Gerakkan kepala, bukan hanya mata, lalu tahan sebentar.',
        'BLINK' => 'Tutup kedua mata sesaat, kemudian buka kembali.',
        _ => 'Pastikan seluruh wajah tetap terlihat.',
      };

  IconData _instructionIcon(dynamic action) => switch (action.toString()) {
        'TURN_LEFT' => Icons.arrow_back_rounded,
        'TURN_RIGHT' => Icons.arrow_forward_rounded,
        'LOOK_UP' => Icons.arrow_upward_rounded,
        'LOOK_DOWN' => Icons.arrow_downward_rounded,
        'BLINK' => Icons.visibility_outlined,
        _ => Icons.face_retouching_natural_outlined,
      };
}

class _LivenessFaceGuidePainter extends CustomPainter {
  const _LivenessFaceGuidePainter({
    required this.progress,
    required this.pulse,
    required this.isCapturing,
    required this.isReady,
  });

  final double progress;
  final double pulse;
  final bool isCapturing;
  final bool isReady;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerX = size.width * .46;
    final outerY = size.height * .45;
    final innerX = size.width * .405;
    final innerY = size.height * .397;
    const segmentCount = 54;
    final activeSegments = (segmentCount * progress).round();
    final readyColor = isCapturing
        ? kSuccessColor
        : isReady
            ? kPrimaryColor
            : Colors.white54;

    for (var index = 0; index < segmentCount; index++) {
      final angle = -math.pi / 2 + (2 * math.pi * index / segmentCount);
      final isActive = index < activeSegments;
      final wave = .72 + .28 * math.sin((pulse * math.pi * 2) + index / 5);
      final color = isActive
          ? readyColor.withValues(alpha: .82 + .18 * wave)
          : Colors.white.withValues(alpha: isCapturing ? .24 : .38);
      final lineWidth = isActive ? 3.2 : 2.4;
      final outer = Offset(center.dx + outerX * math.cos(angle),
          center.dy + outerY * math.sin(angle));
      final inner = Offset(center.dx + innerX * math.cos(angle),
          center.dy + innerY * math.sin(angle));
      canvas.drawLine(
          outer,
          inner,
          Paint()
            ..color = color
            ..strokeWidth = lineWidth
            ..strokeCap = StrokeCap.round);
    }

    final oval =
        Rect.fromCenter(center: center, width: innerX * 2, height: innerY * 2);
    canvas.drawOval(
        oval,
        Paint()
          ..color = readyColor.withValues(alpha: isCapturing ? .24 : .14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(_LivenessFaceGuidePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.pulse != pulse ||
      oldDelegate.isCapturing != isCapturing ||
      oldDelegate.isReady != isReady;
}

class _CaptureFlowException implements Exception {
  const _CaptureFlowException(this.message);

  final String message;
}
