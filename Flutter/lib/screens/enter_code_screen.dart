import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cookyaapp/services/api_service.dart';
import 'package:cookyaapp/widgets/pin_code_field.dart';
import 'reset_password_screen.dart';

class EnterCodeScreen extends StatefulWidget {
  final String email;
  const EnterCodeScreen({super.key, required this.email});

  @override
  State<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends State<EnterCodeScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _verify(String code) async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });

    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/users/password-reset/verify/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': widget.email, 'code': code}),
      );
      final data = json.decode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        final token = data['reset_token'] as String;
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(resetToken: token),
          ),
        );
      } else {
        setState(() => _error = data['error'] ?? 'Invalid code');
      }
    } catch (e) {
      setState(() => _error = 'Connection error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Code')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            const Text(
              'Enter verification code',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We sent a 6-digit code to\n${widget.email}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            PinCodeField(
              length: 6,
              onCompleted: _verify,
            ),

            const SizedBox(height: 20),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            if (_loading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],

            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Didn\'t receive? Go back'),
            ),
          ],
        ),
      ),
    );
  }
}