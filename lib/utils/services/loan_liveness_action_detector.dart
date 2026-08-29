class LivenessFaceSignal {
  const LivenessFaceSignal({
    required this.yaw,
    required this.pitch,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
  });

  final double yaw;
  final double pitch;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
}

class LoanLivenessActionDetector {
  static const _baselineSampleCount = 4;
  static const _requiredPoseHits = 2;
  static const _yawThreshold = 15.0;
  static const _pitchThreshold = 10.0;
  static const _centerThreshold = 14.0;
  static const _closedEyeThreshold = .35;
  static const _openEyeThreshold = .65;

  final List<double> _baselineYawSamples = [];
  final List<double> _baselinePitchSamples = [];

  double? _baselineYaw;
  double? _baselinePitch;
  String? _expectedAction;
  int _poseHits = 0;
  int _centerHits = 0;
  int? _leftYawSign;
  int? _horizontalCandidateSign;
  bool _blinkClosed = false;

  bool get hasBaseline => _baselineYaw != null && _baselinePitch != null;

  void reset() {
    _baselineYawSamples.clear();
    _baselinePitchSamples.clear();
    _baselineYaw = null;
    _baselinePitch = null;
    _expectedAction = null;
    _poseHits = 0;
    _centerHits = 0;
    _leftYawSign = null;
    _horizontalCandidateSign = null;
    _blinkClosed = false;
  }

  bool addBaselineSample(LivenessFaceSignal signal) {
    if (signal.yaw.abs() > 20 || signal.pitch.abs() > 20) return false;
    _baselineYawSamples.add(signal.yaw);
    _baselinePitchSamples.add(signal.pitch);
    if (_baselineYawSamples.length < _baselineSampleCount) return false;
    _baselineYaw = _median(_baselineYawSamples);
    _baselinePitch = _median(_baselinePitchSamples);
    return true;
  }

  void expect(String action) {
    _expectedAction = action;
    _poseHits = 0;
    _centerHits = 0;
    _horizontalCandidateSign = null;
    _blinkClosed = false;
  }

  bool consumeExpected(LivenessFaceSignal signal) {
    final action = _expectedAction;
    if (!hasBaseline || action == null) return false;
    if (action == 'BLINK') return _consumeBlink(signal);

    final yawDelta = signal.yaw - _baselineYaw!;
    final pitchDelta = signal.pitch - _baselinePitch!;
    final matched = switch (action) {
      'TURN_LEFT' || 'TURN_RIGHT' => _consumeHorizontal(action, yawDelta),
      'LOOK_UP' => pitchDelta >= _pitchThreshold,
      'LOOK_DOWN' => pitchDelta <= -_pitchThreshold,
      _ => false,
    };
    if (!matched) {
      if (_poseHits > 0) _poseHits--;
      return false;
    }
    _poseHits++;
    if (_poseHits < _requiredPoseHits) return false;
    if (action == 'TURN_LEFT' || action == 'TURN_RIGHT') {
      _lockHorizontalOrientation(action);
    }
    _poseHits = 0;
    return true;
  }

  bool consumeCentered(LivenessFaceSignal signal) {
    if (!hasBaseline) return false;
    final centered = (signal.yaw - _baselineYaw!).abs() <= _centerThreshold &&
        (signal.pitch - _baselinePitch!).abs() <= _centerThreshold;
    _centerHits = centered ? _centerHits + 1 : 0;
    if (_centerHits < _requiredPoseHits) return false;
    _centerHits = 0;
    return true;
  }

  void miss() {
    if (_poseHits > 0) _poseHits--;
    if (_centerHits > 0) _centerHits--;
    if (_poseHits == 0) _horizontalCandidateSign = null;
  }

  bool _consumeHorizontal(String action, double yawDelta) {
    if (yawDelta.abs() < _yawThreshold) {
      return false;
    }
    final observedSign = yawDelta > 0 ? 1 : -1;
    if (_leftYawSign != null) {
      final expectedSign =
          action == 'TURN_LEFT' ? _leftYawSign : -_leftYawSign!;
      if (observedSign != expectedSign) {
        _horizontalCandidateSign = null;
        return false;
      }
    }
    if (_horizontalCandidateSign != null &&
        _horizontalCandidateSign != observedSign) {
      _horizontalCandidateSign = observedSign;
      return false;
    }
    _horizontalCandidateSign = observedSign;
    return true;
  }

  void _lockHorizontalOrientation(String action) {
    if (_leftYawSign == null && _horizontalCandidateSign != null) {
      _leftYawSign = action == 'TURN_LEFT'
          ? _horizontalCandidateSign
          : -_horizontalCandidateSign!;
    }
    _horizontalCandidateSign = null;
  }

  bool _consumeBlink(LivenessFaceSignal signal) {
    final left = signal.leftEyeOpenProbability;
    final right = signal.rightEyeOpenProbability;
    if (left == null || right == null) return false;
    if (left <= _closedEyeThreshold && right <= _closedEyeThreshold) {
      _blinkClosed = true;
      return false;
    }
    if (_blinkClosed &&
        left >= _openEyeThreshold &&
        right >= _openEyeThreshold) {
      _blinkClosed = false;
      return true;
    }
    return false;
  }

  double _median(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }
}
