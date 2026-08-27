# tflite_flutter supports an optional GPU delegate. Jetmarket uses the CPU
# interpreter for MobileFaceNet, so the GPU-only class is intentionally absent.
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
