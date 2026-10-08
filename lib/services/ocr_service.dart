import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/ocr_result.dart';
import 'heuristic_parser.dart';

class OCRService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Scans receipt image file using Google ML Kit Text Recognition (<100ms on device)
  Future<ParsedReceiptResult> processReceiptImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    final List<String> extractedLines = [];

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        extractedLines.add(line.text);
      }
    }

    // Run Heuristic Regex Engine on extracted raw lines
    return HeuristicReceiptParser.parse(extractedLines);
  }

  /// Close text recognizer resources
  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
