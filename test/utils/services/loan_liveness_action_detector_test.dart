import 'package:flutter_test/flutter_test.dart';
import 'package:jetmarket/utils/services/loan_liveness_action_detector.dart';

void main() {
  const centered = LivenessFaceSignal(
    yaw: 0,
    pitch: 0,
    leftEyeOpenProbability: .9,
    rightEyeOpenProbability: .9,
  );

  LoanLivenessActionDetector calibratedDetector() {
    final detector = LoanLivenessActionDetector();
    for (var index = 0; index < 4; index++) {
      detector.addBaselineSample(centered);
    }
    return detector;
  }

  test('does not accept actions before a stable baseline', () {
    final detector = LoanLivenessActionDetector()..expect('TURN_LEFT');

    expect(
        detector.consumeExpected(const LivenessFaceSignal(yaw: 25, pitch: 0)),
        isFalse);
    expect(detector.hasBaseline, isFalse);
  });

  test('completes every action and keeps opposite horizontal direction', () {
    final detector = calibratedDetector();

    detector.expect('TURN_LEFT');
    expect(
        detector.consumeExpected(const LivenessFaceSignal(yaw: 24, pitch: 0)),
        isFalse);
    expect(
        detector.consumeExpected(const LivenessFaceSignal(yaw: 24, pitch: 0)),
        isTrue);

    detector.expect('TURN_RIGHT');
    expect(
        detector.consumeExpected(const LivenessFaceSignal(yaw: 24, pitch: 0)),
        isFalse);
    expect(
        detector.consumeExpected(const LivenessFaceSignal(yaw: -24, pitch: 0)),
        isFalse);
    expect(
        detector.consumeExpected(const LivenessFaceSignal(yaw: -24, pitch: 0)),
        isTrue);

    detector.expect('LOOK_UP');
    expect(
        detector.consumeExpected(const LivenessFaceSignal(yaw: 0, pitch: 15)),
        isFalse);
    expect(
        detector.consumeExpected(const LivenessFaceSignal(yaw: 0, pitch: 15)),
        isTrue);

    detector.expect('LOOK_DOWN');
    expect(
        detector.consumeExpected(const LivenessFaceSignal(yaw: 0, pitch: -15)),
        isFalse);
    expect(
        detector.consumeExpected(const LivenessFaceSignal(yaw: 0, pitch: -15)),
        isTrue);

    detector.expect('BLINK');
    expect(
      detector.consumeExpected(const LivenessFaceSignal(
        yaw: 0,
        pitch: 0,
        leftEyeOpenProbability: .1,
        rightEyeOpenProbability: .1,
      )),
      isFalse,
    );
    expect(detector.consumeExpected(centered), isTrue);
  });

  test('requires two centered samples before recentering completes', () {
    final detector = calibratedDetector();

    expect(
        detector.consumeCentered(const LivenessFaceSignal(yaw: 4, pitch: -3)),
        isFalse);
    expect(
        detector.consumeCentered(const LivenessFaceSignal(yaw: 4, pitch: -3)),
        isTrue);
  });

  test('detects a realistic blink relative to the calibrated eye score', () {
    final detector = calibratedDetector()..expect('BLINK');

    expect(
        detector.consumeExpected(const LivenessFaceSignal(
          yaw: 0,
          pitch: 0,
          leftEyeOpenProbability: .55,
          rightEyeOpenProbability: .58,
        )),
        isFalse);
    expect(
        detector.consumeExpected(const LivenessFaceSignal(
          yaw: 0,
          pitch: 0,
          leftEyeOpenProbability: .76,
          rightEyeOpenProbability: .78,
        )),
        isTrue);
  });

  test('accepts a gentle head movement for directional prompts', () {
    final detector = calibratedDetector()..expect('LOOK_DOWN');

    expect(
        detector.consumeExpected(const LivenessFaceSignal(yaw: 0, pitch: -6)),
        isFalse);
    expect(
        detector.consumeExpected(const LivenessFaceSignal(yaw: 0, pitch: -6)),
        isTrue);

    detector.expect('TURN_LEFT');
    expect(detector.consumeExpected(const LivenessFaceSignal(yaw: 9, pitch: 0)),
        isFalse);
    expect(detector.consumeExpected(const LivenessFaceSignal(yaw: 9, pitch: 0)),
        isTrue);
  });

  test('tolerates one noisy frame while confirming an action', () {
    final detector = calibratedDetector()..expect('LOOK_UP');

    expect(
        detector.consumeExpected(const LivenessFaceSignal(yaw: 0, pitch: 12)),
        isFalse);
    detector.miss();
    expect(
        detector.consumeExpected(const LivenessFaceSignal(yaw: 0, pitch: 12)),
        isFalse);
    expect(
        detector.consumeExpected(const LivenessFaceSignal(yaw: 0, pitch: 12)),
        isTrue);
  });

  test('completes every challenge order in both camera orientations', () {
    const actions = [
      'TURN_LEFT',
      'TURN_RIGHT',
      'LOOK_UP',
      'LOOK_DOWN',
      'BLINK',
    ];

    for (final order in permutations(actions)) {
      for (final leftYawSign in [-1, 1]) {
        final detector = calibratedDetector();
        for (final action in order) {
          detector.expect(action);
          final signals = switch (action) {
            'TURN_LEFT' => [
                LivenessFaceSignal(yaw: 24.0 * leftYawSign, pitch: 0),
                LivenessFaceSignal(yaw: 24.0 * leftYawSign, pitch: 0),
              ],
            'TURN_RIGHT' => [
                LivenessFaceSignal(yaw: -24.0 * leftYawSign, pitch: 0),
                LivenessFaceSignal(yaw: -24.0 * leftYawSign, pitch: 0),
              ],
            'LOOK_UP' => const [
                LivenessFaceSignal(yaw: 0, pitch: 15),
                LivenessFaceSignal(yaw: 0, pitch: 15),
              ],
            'LOOK_DOWN' => const [
                LivenessFaceSignal(yaw: 0, pitch: -15),
                LivenessFaceSignal(yaw: 0, pitch: -15),
              ],
            _ => const [
                LivenessFaceSignal(
                  yaw: 0,
                  pitch: 0,
                  leftEyeOpenProbability: .1,
                  rightEyeOpenProbability: .1,
                ),
                centered,
              ],
          };
          var completed = false;
          for (final signal in signals) {
            completed = detector.consumeExpected(signal) || completed;
          }
          expect(completed, isTrue, reason: '$order failed at $action');
        }
      }
    }
  });
}

Iterable<List<T>> permutations<T>(List<T> values) sync* {
  if (values.isEmpty) {
    yield <T>[];
    return;
  }
  for (var index = 0; index < values.length; index++) {
    final remaining = List<T>.from(values)..removeAt(index);
    for (final suffix in permutations(remaining)) {
      yield [values[index], ...suffix];
    }
  }
}
