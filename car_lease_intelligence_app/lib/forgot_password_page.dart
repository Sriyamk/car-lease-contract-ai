import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _emailSent = false;

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _emailSent = true;
          _isLoading = false;
        });
      } else {
        final data = json.decode(response.body);
        setState(() {
          _errorMessage = data['detail'] ?? 'Failed to send reset email';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              Color(0xFF000000),
              Color(0xFF200B18),
              Color(0xFF765767),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5B3D7),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 80,
                        spreadRadius: 30,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(40),
                  child: _emailSent ? _buildSuccessView() : _buildFormView(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon
          const Icon(
            Icons.lock_reset,
            size: 64,
            color: Color(0xFFFB1597),
          ),
          const SizedBox(height: 20),

          // Title
          const Text(
            'Forgot Password?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF23101A),
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your email and we\'ll send you your password',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF5A2D47),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 40),

          // Email Field
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: const TextStyle(color: Color(0xFF5A2D47)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.email, color: Color(0xFFFB1597)),
            ),
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Color(0xFF23101A)),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),

          // Error Message
          if (_errorMessage != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3F1D2B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFFDA4D6),
                  fontSize: 14,
                ),
              ),
            ),
          ],

          const SizedBox(height: 30),

          // Send Button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _isLoading ? null : _sendResetEmail,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFB1597), Color(0xFFFD86C8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFB1597).withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                    : const Text(
                        'Send Password',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Back to Login Link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: const Row(
                    children: [
                      Icon(
                        Icons.arrow_back,
                        size: 16,
                        color: Color(0xFFFB1597),
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Back to Login',
                        style: TextStyle(
                          color: Color(0xFFFB1597),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success Icon
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: Color(0xFF4CAF50),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),

        // Title
        const Text(
          'Email Sent!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF23101A),
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Message
        Text(
          'Your password has been sent to\n${_emailController.text}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF5A2D47),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please check your inbox',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF5A2D47),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 40),

        // Back to Login Button
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFB1597), Color(0xFFFD86C8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFB1597).withOpacity(0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Text(
                'Back to Login',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}