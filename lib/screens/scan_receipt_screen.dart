import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/camera_overlay_painter.dart';
import '../services/ocr_service.dart';
import 'review_receipt_screen.dart';

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _isProcessingOCR = false;

  late AnimationController _animController;
  late OCRService _ocrService;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _ocrService = OCRService();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras!.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _animController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      setState(() => _isFlashOn = !_isFlashOn);
      await _cameraController!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    }
  }

  Future<void> _processImageFile(File imageFile) async {
    setState(() => _isProcessingOCR = true);

    try {
      final parsedResult = await _ocrService.processReceiptImage(imageFile);

      if (mounted) {
        setState(() => _isProcessingOCR = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReviewReceiptScreen(
              parsedResult: parsedResult,
              originalImage: imageFile,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingOCR = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi đọc hóa đơn: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController != null && _cameraController!.value.isInitialized && !_isProcessingOCR) {
      try {
        final XFile photo = await _cameraController!.takePicture();
        await _processImageFile(File(photo.path));
      } catch (e) {
        debugPrint('Capture error: $e');
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _processImageFile(File(image.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Quét Hóa Đơn (Offline OCR)'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.amber),
            onPressed: _toggleFlash,
          ),
          IconButton(
            icon: const Icon(Icons.photo_library_rounded, color: Colors.white),
            onPressed: _pickFromGallery,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Camera Live Viewfinder with Tap to Focus
          if (_isCameraInitialized && _cameraController != null)
            LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) async {
                    final Offset offset = Offset(
                      details.localPosition.dx / constraints.maxWidth,
                      details.localPosition.dy / constraints.maxHeight,
                    );
                    try {
                      await _cameraController!.setFocusPoint(offset);
                      await _cameraController!.setExposurePoint(offset);
                    } catch (_) {}
                  },
                  child: CameraPreview(_cameraController!),
                );
              },
            )
          else
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                  SizedBox(height: 16),
                  Text('Đang khởi động Camera...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),

          // 2. Custom Painter Viewfinder Overlay & Scan Laser Line
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: CameraOverlayPainter(scanAnimationValue: _animController.value),
              );
            },
          ),

          // 3. Guidance Header Text
          Positioned(
            top: 24,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                children: [
                  Icon(Icons.crop_free_rounded, color: Color(0xFF00E676), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Đặt hóa đơn nằm gọn trong khung hình để trích xuất tốt nhất',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Shutter Button & Controls at Bottom
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.photo_library_rounded, color: Colors.white),
                  onPressed: _pickFromGallery,
                ),

                // Capture Button
                GestureDetector(
                  onTap: _capturePhoto,
                  child: Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF6C5CE7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 34),
                    ),
                  ),
                ),

                IconButton(
                  iconSize: 32,
                  icon: Icon(_isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white),
                  onPressed: _toggleFlash,
                ),
              ],
            ),
          ),

          // 5. OCR Processing Overlay Loading Indicator
          if (_isProcessingOCR)
            Container(
              color: Colors.black.withOpacity(0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF00E676), strokeWidth: 3),
                    const SizedBox(height: 20),
                    const Text(
                      'Đang phân tích văn bản bằng Google ML Kit...',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Thuật toán Heuristic Regex đang trích xuất số tiền & ngày...',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
