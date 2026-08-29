import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:jetmarket/infrastructure/theme/app_colors.dart';
import 'package:jetmarket/infrastructure/theme/app_text.dart';
import 'package:jetmarket/presentation/koperasi_pages/pinjaman_v2/controllers/loan_v2.controller.dart';
import 'package:jetmarket/utils/services/loan_liveness_action_detector.dart';

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
  CameraDescription? _cameraDescription;
  late final AnimationController _guideAnimation;
  late final FaceDetector _faceDetector;
  final LoanLivenessActionDetector _actionDetector =
      LoanLivenessActionDetector();
  List<dynamic> _actions = const [];
  int _actionIndex = -1;
  int _countdown = 0;
  bool _initializing = true;
  bool _capturing = false;
  bool _aborted = false;
  bool _recentering = false;
  bool _processingFrame = false;
  bool _faceDetectorClosed = false;
  int _completedActions = 0;
  int _detectionEpoch = 0;
  _DetectionPhase _detectionPhase = _DetectionPhase.idle;
  Completer<void>? _detectionWaiter;
  String? _error;

  bool get _cameraReady => _camera?.value.isInitialized == true;
  bool get _showingAction =>
      !_recentering && _actionIndex >= 0 && _actionIndex < _actions.length;

  @override
  void initState() {
    super.initState();
    _guideAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: .18,
      ),
    );
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _aborted = true;
      _endDetectionPhase(const _CaptureFlowException(
          'Verifikasi wajah terhenti saat aplikasi dijeda.'));
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
        fps: 15,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await camera.initialize();
      await camera.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted || _aborted) {
        await camera.dispose();
        return;
      }
      await _camera?.dispose();
      setState(() {
        _camera = camera;
        _cameraDescription = selected;
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
      _recentering = false;
      _completedActions = 0;
    });
    _actionDetector.reset();

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
      final baselineWaiter = _beginDetectionPhase(_DetectionPhase.baseline);
      await camera.startVideoRecording(onAvailable: _processCameraImage);
      await _waitForDetection(
        baselineWaiter,
        const Duration(seconds: 5),
        'Wajah belum terbaca dengan stabil. Hadap lurus ke kamera dan coba lagi.',
      );

      for (var index = 0; index < actions.length; index++) {
        if (_aborted || !mounted) return;
        final action = actions[index].toString();
        _actionDetector.expect(action);
        final actionWaiter = _beginDetectionPhase(_DetectionPhase.action);
        setState(() {
          _recentering = false;
          _actionIndex = index;
        });
        await _waitForDetection(
          actionWaiter,
          Duration(seconds: action == 'BLINK' ? 7 : 6),
          '${_livenessLabel(action)} belum terdeteksi. Silakan coba rekam ulang.',
        );
        if (_aborted || !mounted) return;
        setState(() => _completedActions = index + 1);
        if (index < actions.length - 1) {
          final centerWaiter = _beginDetectionPhase(_DetectionPhase.recenter);
          setState(() => _recentering = true);
          await _waitForDetection(
            centerWaiter,
            const Duration(seconds: 4),
            'Wajah belum kembali ke tengah. Silakan coba rekam ulang.',
            failOnTimeout: false,
          );
        }
      }
      if (_aborted || !mounted) return;
      setState(() {
        _recentering = false;
        _actionIndex = actions.length;
      });
      await Future<void>.delayed(const Duration(milliseconds: 700));
      _endDetectionPhase();
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
      _endDetectionPhase();
      if (mounted) {
        setState(() {
          _capturing = false;
          _countdown = 0;
          _actionIndex = -1;
          _recentering = false;
          _completedActions = 0;
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
    _endDetectionPhase(
        const _CaptureFlowException('Verifikasi wajah dibatalkan.'));
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
    _cameraDescription = null;
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
      _recentering = false;
      _completedActions = 0;
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

  Completer<void> _beginDetectionPhase(_DetectionPhase phase) {
    _detectionEpoch++;
    _detectionPhase = phase;
    final waiter = Completer<void>();
    _detectionWaiter = waiter;
    return waiter;
  }

  Future<void> _waitForDetection(
    Completer<void> waiter,
    Duration timeout,
    String timeoutMessage, {
    bool failOnTimeout = true,
  }) async {
    try {
      await waiter.future.timeout(timeout);
    } on TimeoutException {
      if (failOnTimeout) throw _CaptureFlowException(timeoutMessage);
    } finally {
      if (identical(_detectionWaiter, waiter)) _detectionWaiter = null;
    }
  }

  void _endDetectionPhase([Object? error]) {
    _detectionEpoch++;
    _detectionPhase = _DetectionPhase.idle;
    final waiter = _detectionWaiter;
    _detectionWaiter = null;
    if (waiter == null || waiter.isCompleted) return;
    if (error == null) {
      waiter.complete();
    } else {
      waiter.completeError(error, StackTrace.current);
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_processingFrame || !_capturing || _faceDetectorClosed) {
      return;
    }
    final epoch = _detectionEpoch;
    _processingFrame = true;
    try {
      if (_detectionPhase == _DetectionPhase.idle ||
          !mounted ||
          epoch != _detectionEpoch) {
        return;
      }
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;
      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted || epoch != _detectionEpoch) return;
      if (faces.length != 1) {
        _actionDetector.miss();
        return;
      }
      final face = faces.single;
      final yaw = face.headEulerAngleY;
      final pitch = face.headEulerAngleX;
      if (yaw == null ||
          pitch == null ||
          face.boundingBox.width < image.width * .18) {
        _actionDetector.miss();
        return;
      }
      final signal = LivenessFaceSignal(
        yaw: yaw,
        pitch: pitch,
        leftEyeOpenProbability: face.leftEyeOpenProbability,
        rightEyeOpenProbability: face.rightEyeOpenProbability,
      );
      final detected = switch (_detectionPhase) {
        _DetectionPhase.baseline => _actionDetector.addBaselineSample(signal),
        _DetectionPhase.action => _actionDetector.consumeExpected(signal),
        _DetectionPhase.recenter => _actionDetector.consumeCentered(signal),
        _DetectionPhase.idle => false,
      };
      if (detected && _detectionWaiter?.isCompleted == false) {
        _detectionWaiter!.complete();
      }
    } catch (_) {
      if (epoch == _detectionEpoch) {
        _endDetectionPhase(const _CaptureFlowException(
            'Deteksi wajah tidak dapat dijalankan pada perangkat ini.'));
      }
    } finally {
      _processingFrame = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _cameraDescription;
    final controller = _camera;
    if (camera == null || controller == null || image.planes.length != 1) {
      return null;
    }
    const orientations = <DeviceOrientation, int>{
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final captureOrientation = controller.value.lockedCaptureOrientation ??
        controller.value.deviceOrientation;
    final deviceRotation = orientations[captureOrientation];
    if (deviceRotation == null) return null;
    final rotationCompensation =
        camera.lensDirection == CameraLensDirection.front
            ? (camera.sensorOrientation + deviceRotation) % 360
            : (camera.sensorOrientation - deviceRotation + 360) % 360;
    final rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null) return null;
    if (format != InputImageFormat.nv21) return null;
    final plane = image.planes.single;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _aborted = true;
    _endDetectionPhase(
        const _CaptureFlowException('Verifikasi wajah dihentikan.'));
    _guideAnimation.dispose();
    WidgetsBinding.instance.removeObserver(this);
    final camera = _camera;
    _camera = null;
    _cameraDescription = null;
    unawaited(_shutdownCamera(camera));
    _faceDetectorClosed = true;
    unawaited(_faceDetector.close());
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
    return (_completedActions / _actions.length).clamp(0.0, 1.0).toDouble();
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
                      value:
                          (_completedActions / _actions.length).clamp(0.0, 1.0),
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
    if (_recentering) return 'Kembali ke tengah';
    if (_capturing && _actionIndex == -2) return 'Hadap lurus';
    if (_showingAction) return _livenessLabel(_actions[_actionIndex]);
    if (_capturing && _actionIndex >= _actions.length) return 'Tahan sebentar';
    if (_initializing) return 'Menyiapkan kamera';
    return 'Posisikan wajah di dalam bingkai';
  }

  String _instructionDetail() {
    if (_countdown > 0) return 'Tetap menghadap kamera';
    if (_recentering) {
      return 'Hadapkan wajah lurus ke kamera sebelum instruksi berikutnya.';
    }
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
  });

  final double progress;
  final double pulse;
  final bool isCapturing;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerX = size.width * .46;
    final outerY = size.height * .45;
    final innerX = size.width * .405;
    final innerY = size.height * .397;
    const segmentCount = 54;
    final activeSegments = (segmentCount * progress).round();
    for (var index = 0; index < segmentCount; index++) {
      final angle = -math.pi / 2 + (2 * math.pi * index / segmentCount);
      final isActive = index < activeSegments;
      final wave = .72 + .28 * math.sin((pulse * math.pi * 2) + index / 5);
      final color = isActive
          ? kSuccessColor.withValues(alpha: .82 + .18 * wave)
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
          ..color = Colors.white.withValues(alpha: isCapturing ? .24 : .14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(_LivenessFaceGuidePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.pulse != pulse ||
      oldDelegate.isCapturing != isCapturing;
}

enum _DetectionPhase { idle, baseline, action, recenter }

class _CaptureFlowException implements Exception {
  const _CaptureFlowException(this.message);

  final String message;
}
