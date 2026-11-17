// Shared Gemini access through Firebase AI Logic (no API key in the app).
// Used by the fridge/receipt scanner and by AI meal ideas.

import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

/// Gemini model used across the app. Fast, cheap and multimodal.
const String aiModel = 'gemini-3.5-flash-lite';

/// An AI request failed in a way the user should hear about.
class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => message;
}

/// An image sent along with a prompt.
class AiImage {
  final Uint8List bytes;
  final String mimeType;
  const AiImage(this.bytes, this.mimeType);
}

/// Sends [prompt] (and any [images]) to Gemini, asking for JSON that follows
/// [schema], and returns the raw JSON text. Setup problems become messages
/// the user can act on.
Future<String> askGemini(
  Schema schema,
  String prompt, {
  List<AiImage> images = const [],
  Duration? timeout,
}) async {
  final model = FirebaseAI.googleAI().generativeModel(
    model: aiModel,
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: schema,
    ),
  );
  try {
    final response = await model.generateContent([
      Content.multi([
        TextPart(prompt),
        for (final img in images) InlineDataPart(img.mimeType, img.bytes),
      ]),
    ]).timeout(timeout ?? Duration(seconds: 30 + 10 * images.length));
    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw const AiException('The AI returned no result. Please try again.');
    }
    return text;
  } on AiException {
    rethrow;
  } catch (e) {
    final msg = '$e';
    if (msg.contains('App Check')) {
      throw const AiException(
          'AI was blocked by Firebase App Check. In the Firebase console, '
          'open App Check → APIs → Firebase AI Logic and choose Unenforce '
          '(or add App Check to the app).');
    }
    if (msg.contains('API has not been used') ||
        msg.contains('PERMISSION_DENIED') ||
        msg.contains('firebasevertexai') ||
        msg.contains('generativelanguage')) {
      throw const AiException(
          'AI is not enabled for this Firebase project yet. '
          'Enable "AI Logic" in the Firebase console.');
    }
    if (msg.contains('TimeoutException')) {
      throw const AiException(
          'The AI took too long to answer. Check your connection and try again.');
    }
    throw AiException('AI request failed: $msg');
  }
}
