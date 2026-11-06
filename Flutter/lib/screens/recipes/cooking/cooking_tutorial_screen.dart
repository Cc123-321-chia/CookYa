// screens/recipes/cooking/cooking_tutorial_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';
import '../../../models/recipe.dart';
import 'ingredients_page.dart';
import 'step_page.dart';
import 'completed_page.dart';

/// Full tutorial flow: Ingredients -> Step 1..N -> Completed.
///
/// Voice and Translation are persistent toggles:
///   - Once ON, stay ON for the whole tutorial.
///   - Turning ON/OFF prompts a confirmation dialog.
///   - On every page change, if enabled, the step is auto-translated
///     and/or auto-read.
class CookingTutorialScreen extends StatefulWidget {
  final Recipe recipe;

  const CookingTutorialScreen({super.key, required this.recipe});

  @override
  State<CookingTutorialScreen> createState() => _CookingTutorialScreenState();
}

class _CookingTutorialScreenState extends State<CookingTutorialScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  int _totalPages = 0;

  // Voice & translation services.
  final FlutterTts _flutterTts = FlutterTts();
  final GoogleTranslator _translator = GoogleTranslator();

  /// Persistent toggles.
  bool _voiceEnabled = false;
  bool _translateEnabled = false;

  bool _isSpeaking = false;
  bool _isTranslating = false;

  /// Current step's translation cache.
  String? _translatedText;
  String? _translatedNote;

  String _selectedLanguage = 'en';

  /// Curated language list — common languages only.
  final List<Map<String, String>> supportedLanguages = const [
    {'code': 'en', 'tts': 'en-US', 'name': 'English'},
    {'code': 'zh-CN', 'tts': 'zh-CN', 'name': '中文 (简体)'},
    {'code': 'zh-TW', 'tts': 'zh-TW', 'name': '中文 (繁體)'},
    {'code': 'ms', 'tts': 'ms-MY', 'name': 'Bahasa Melayu'},
    {'code': 'id', 'tts': 'id-ID', 'name': 'Bahasa Indonesia'},
    {'code': 'th', 'tts': 'th-TH', 'name': 'ภาษาไทย'},
    {'code': 'vi', 'tts': 'vi-VN', 'name': 'Tiếng Việt'},
    {'code': 'ja', 'tts': 'ja-JP', 'name': '日本語'},
    {'code': 'ko', 'tts': 'ko-KR', 'name': '한국어'},
    {'code': 'hi', 'tts': 'hi-IN', 'name': 'हिन्दी'},
    {'code': 'fr', 'tts': 'fr-FR', 'name': 'Français'},
    {'code': 'de', 'tts': 'de-DE', 'name': 'Deutsch'},
    {'code': 'es', 'tts': 'es-ES', 'name': 'Español'},
    {'code': 'it', 'tts': 'it-IT', 'name': 'Italiano'},
    {'code': 'pt', 'tts': 'pt-PT', 'name': 'Português'},
    {'code': 'ru', 'tts': 'ru-RU', 'name': 'Русский'},
  ];

  Map<String, String> get _langInfo => supportedLanguages.firstWhere(
        (l) => l['code'] == _selectedLanguage,
        orElse: () => supportedLanguages.first,
      );

  @override
  void initState() {
    super.initState();
    _totalPages = 1 + widget.recipe.steps.length + 1;
    _pageController = PageController();
    _configureTts();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _pageController.dispose();
    super.dispose();
  }

  // ==================== TTS setup ====================

  void _configureTts() {
    _flutterTts.setLanguage(_langInfo['tts']!);
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setPitch(1.0);
    _flutterTts.awaitSpeakCompletion(true);
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _flutterTts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  // ==================== Navigation ====================

  void _goToNextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _exit() {
    _flutterTts.stop();
    Navigator.of(context).pop();
  }

  // ==================== Page change ====================

  Future<void> _onPageChanged(int page) async {
    await _flutterTts.stop();
    setState(() {
      _currentPage = page;
      _translatedText = null;
      _translatedNote = null;
      _isSpeaking = false;
    });

    final isStepPage = page >= 1 && page <= widget.recipe.steps.length;
    if (!isStepPage) return;

    if (_translateEnabled) {
      await _translateCurrentStep(silent: true);
    }
    if (_voiceEnabled) {
      await _speakCurrentStep();
    }
  }

  // ==================== TTS ====================

  String _stepTextForTts() {
    if (_translatedText != null) return _translatedText!;
    return widget.recipe.steps[_currentPage - 1].instruction;
  }

  Future<void> _speakCurrentStep() async {
    final isStepPage =
        _currentPage >= 1 && _currentPage <= widget.recipe.steps.length;
    if (!isStepPage) return;

    final text = _stepTextForTts();
    if (text.trim().isEmpty) return;

    setState(() => _isSpeaking = true);
    try {
      await _flutterTts.setLanguage(_langInfo['tts']!);
      await _flutterTts.speak(text);
    } catch (e) {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }

  // ==================== Translation ====================

  Future<void> _translateCurrentStep({bool silent = false}) async {
    final isStepPage =
        _currentPage >= 1 && _currentPage <= widget.recipe.steps.length;
    if (!isStepPage) return;
    if (_isTranslating) return;

    setState(() => _isTranslating = true);
    final targetLang = _normalizedLangCode();

    try {
      final step = widget.recipe.steps[_currentPage - 1];

      String translatedInstruction;
      try {
        translatedInstruction =
            await _translateWithRetry(step.instruction, targetLang);
      } catch (e) {
        debugPrint('Translate instruction failed: $e');
        rethrow;
      }

      String? translatedNote;
      if (step.note != null && step.note!.isNotEmpty) {
        try {
          translatedNote =
              await _translateWithRetry(step.note!, targetLang);
        } catch (e) {
          debugPrint('Translate note failed: $e');
          translatedNote = null;
        }
      }

      if (!mounted) return;
      setState(() {
        _translatedText = translatedInstruction;
        _translatedNote = translatedNote;
        _isTranslating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTranslating = false);
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Google Translate is picky about Chinese codes — normalize them.
  String _normalizedLangCode() {
    switch (_selectedLanguage) {
      case 'zh-CN':
        return 'zh-cn';
      case 'zh-TW':
        return 'zh-tw';
      default:
        return _selectedLanguage;
    }
  }

  /// Translate with one retry. The free Google endpoint sometimes rejects
  /// the very first request in a session.
  Future<String> _translateWithRetry(String text, String target) async {
    try {
      final r = await _translator.translate(text, from: 'auto', to: target);
      return r.text;
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 500));
      final r = await _translator.translate(text, from: 'auto', to: target);
      return r.text;
    }
  }

  // ==================== Toggle dialogs ====================

  Future<void> _toggleVoice() async {
    if (_voiceEnabled) {
      final confirm = await _showToggleDialog(
        title: 'Turn off Voice?',
        message: 'Auto-read will stop for the rest of the tutorial.',
        confirmText: 'Turn Off',
      );
      if (confirm == true) {
        await _stopSpeaking();
        setState(() => _voiceEnabled = false);
      }
    } else {
      final confirm = await _showToggleDialog(
        title: 'Turn on Voice?',
        message:
            'CookYa will automatically read each step aloud as you advance.',
        confirmText: 'Turn On',
      );
      if (confirm == true) {
        setState(() => _voiceEnabled = true);
        await _speakCurrentStep();
      }
    }
  }

  Future<void> _toggleTranslate() async {
    if (_translateEnabled) {
      final confirm = await _showToggleDialog(
        title: 'Turn off Translation?',
        message: 'Auto-translation will stop for the rest of the tutorial.',
        confirmText: 'Turn Off',
      );
      if (confirm == true) {
        setState(() {
          _translateEnabled = false;
          _translatedText = null;
          _translatedNote = null;
        });
      }
    } else {
      final confirm = await _showToggleDialog(
        title: 'Turn on Translation?',
        message:
            'CookYa will automatically translate each step into your chosen language.',
        confirmText: 'Turn On',
      );
      if (confirm == true) {
        setState(() => _translateEnabled = true);
        await _translateCurrentStep(silent: true);
        if (_voiceEnabled) await _speakCurrentStep();
      }
    }
  }

  Future<bool?> _showToggleDialog({
    required String title,
    required String message,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 13,
            height: 1.4,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB347),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              confirmText,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Language picker ====================

  void _showLanguageDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Language',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6B4C2A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: supportedLanguages.length,
                        itemBuilder: (_, index) {
                          final lang = supportedLanguages[index];
                          final isSelected = _selectedLanguage == lang['code'];
                          return ListTile(
                            leading: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: Color(0xFFFFB347))
                                : const Icon(Icons.language,
                                    color: Colors.grey),
                            title: Text(
                              lang['name']!,
                              style: GoogleFonts.poppins(
                                color: isSelected
                                    ? const Color(0xFFFFB347)
                                    : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            onTap: () async {
                              setState(() {
                                _selectedLanguage = lang['code']!;
                                _translatedText = null;
                                _translatedNote = null;
                              });
                              try {
                                await _flutterTts.setLanguage(lang['tts']!);
                              } catch (_) {}
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              if (_translateEnabled) {
                                await _translateCurrentStep(silent: true);
                              }
                              if (_voiceEnabled) {
                                await _speakCurrentStep();
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                IngredientsPage(
                  recipe: widget.recipe,
                  onContinue: _goToNextPage,
                ),
                ...widget.recipe.steps.asMap().entries.map((entry) {
                  final stepIndex = entry.key;
                  final stepItem = entry.value;
                  final isCurrentStep = (_currentPage == stepIndex + 1);

                  return StepPage(
                    stepNumber: stepIndex + 1,
                    stepItem: stepItem,
                    totalSteps: widget.recipe.steps.length,
                    onBack: _goToPreviousPage,
                    onContinue: _goToNextPage,
                    isLastStep:
                        stepIndex == widget.recipe.steps.length - 1,
                    translatedText: isCurrentStep ? _translatedText : null,
                    translatedNote: isCurrentStep ? _translatedNote : null,
                    showOriginal: isCurrentStep && _translateEnabled,
                    selectedLanguage: _langInfo['name']!,
                  );
                }),
                CompletedPage(onDone: _exit),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      color: Colors.white,
      child: Row(
        children: [
          GestureDetector(
            onTap: _exit,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF5E6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 20, color: Color(0xFF6B4C2A)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step ${_currentPage + 1} of $_totalPages',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFFC9A96E),
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: (_currentPage + 1) / _totalPages,
                  backgroundColor: const Color(0xFFFFF0B5),
                  color: const Color(0xFFFFD966),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Translate',
            onPressed: _isTranslating ? null : _toggleTranslate,
            icon: _isTranslating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFFB347),
                    ),
                  )
                : Icon(
                    _translateEnabled
                        ? Icons.translate
                        : Icons.translate_outlined,
                    color: _translateEnabled
                        ? const Color(0xFFFFB347)
                        : const Color(0xFF6B4C2A),
                    size: 22,
                  ),
          ),
          IconButton(
            tooltip: 'Voice',
            onPressed: _toggleVoice,
            icon: Icon(
              _voiceEnabled ? Icons.volume_up : Icons.volume_up_outlined,
              color: _voiceEnabled
                  ? const Color(0xFFFFB347)
                  : const Color(0xFF6B4C2A),
              size: 22,
            ),
          ),
          IconButton(
            tooltip: 'Language',
            onPressed: _showLanguageDialog,
            icon: const Icon(
              Icons.language,
              color: Color(0xFF6B4C2A),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}