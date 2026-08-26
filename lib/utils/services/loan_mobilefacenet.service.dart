import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;
import 'package:tflite_flutter/tflite_flutter.dart';

class LoanMobileFaceNetPreflight {
  const LoanMobileFaceNetPreflight({
    required this.embeddingSha256,
    required this.imageSha256,
  });

  static const modelName = 'MOBILEFACENET';
  static const embeddingDimensions = 192;

  final String embeddingSha256;
  final String imageSha256;
}

class LoanMobileFaceNetException implements Exception {
  const LoanMobileFaceNetException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Runs the same MobileFaceNet model used by AVHRIS before a face capture is
/// uploaded. Its embedding remains on device; only the backend's signed
/// callback can make the final identity decision with a trusted reference.
class LoanMobileFaceNetService {
  static const _modelAsset = 'assets/mobilefacenet.tflite';
  Interpreter? _interpreter;

  Future<LoanMobileFaceNetPreflight> preflight(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = image.decodeImage(bytes);
    if (decoded == null || decoded.width < 112 || decoded.height < 112) {
      throw const LoanMobileFaceNetException(
          'Foto wajah tidak dapat diproses. Ambil ulang foto dengan wajah terlihat jelas.');
    }

    final input = _normalize(_centerCropAndResize(decoded));
    final output =
        List<double>.filled(LoanMobileFaceNetPreflight.embeddingDimensions, 0)
            .reshape([1, LoanMobileFaceNetPreflight.embeddingDimensions]);
    final interpreter = await _loadInterpreter();
    interpreter.run(input.reshape([1, 112, 112, 3]), output);

    final embedding = List<num>.from(output.first);
    if (embedding.length != LoanMobileFaceNetPreflight.embeddingDimensions ||
        embedding.any((value) => !value.isFinite)) {
      throw const LoanMobileFaceNetException(
          'Model verifikasi wajah tidak menghasilkan data yang valid. Silakan ambil ulang foto.');
    }

    final embeddingBytes = ByteData(embedding.length * 4);
    for (var index = 0; index < embedding.length; index++) {
      embeddingBytes.setFloat32(
          index * 4, embedding[index].toDouble(), Endian.little);
    }

    return LoanMobileFaceNetPreflight(
      embeddingSha256:
          sha256.convert(embeddingBytes.buffer.asUint8List()).toString(),
      imageSha256: sha256.convert(bytes).toString(),
    );
  }

  Future<Interpreter> _loadInterpreter() async {
    return _interpreter ??= await Interpreter.fromAsset(_modelAsset);
  }

  image.Image _centerCropAndResize(image.Image source) {
    final side = min(source.width, source.height);
    final cropped = image.copyCrop(
      source,
      x: (source.width - side) ~/ 2,
      y: (source.height - side) ~/ 2,
      width: side,
      height: side,
    );
    return image.copyResize(cropped,
        width: 112, height: 112, interpolation: image.Interpolation.cubic);
  }

  List<double> _normalize(image.Image source) {
    final input = List<double>.filled(112 * 112 * 3, 0);
    var index = 0;
    for (var y = 0; y < 112; y++) {
      for (var x = 0; x < 112; x++) {
        final pixel = source.getPixel(x, y);
        input[index++] = (pixel.r - 128) / 128;
        input[index++] = (pixel.g - 128) / 128;
        input[index++] = (pixel.b - 128) / 128;
      }
    }
    return input;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
