// services/tts_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  String _selectedLanguage = 'en-US';

  final List<Map<String, String>> supportedLanguages = [
    {'code': 'en-US', 'name': 'English (US)'},
    {'code': 'en-GB', 'name': 'English (UK)'},
    {'code': 'zh-CN', 'name': '中文 (简体)'},
    {'code': 'zh-TW', 'name': '中文 (繁體)'},
    {'code': 'ms-MY', 'name': 'Bahasa Melayu'},
    {'code': 'ja-JP', 'name': '日本語'},
    {'code': 'ko-KR', 'name': '한국어'},
    {'code': 'fr-FR', 'name': 'Français'},
    {'code': 'de-DE', 'name': 'Deutsch'},
    {'code': 'es-ES', 'name': 'Español'},
    {'code': 'it-IT', 'name': 'Italiano'},
    {'code': 'pt-PT', 'name': 'Português'},
    {'code': 'ru-RU', 'name': 'Русский'},
    {'code': 'ar-SA', 'name': 'العربية'},
    {'code': 'hi-IN', 'name': 'हिन्दी'},
    {'code': 'th-TH', 'name': 'ภาษาไทย'},
    {'code': 'vi-VN', 'name': 'Tiếng Việt'},
  ];

  String get selectedLanguage => _selectedLanguage;

  void setLanguage(String languageCode) {
    _selectedLanguage = languageCode;
    _flutterTts.setLanguage(languageCode);
  }

  Future<void> speak(String text) async {
    await _flutterTts.setLanguage(_selectedLanguage);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  Future<void> pause() async {
    await _flutterTts.pause();
  }
}