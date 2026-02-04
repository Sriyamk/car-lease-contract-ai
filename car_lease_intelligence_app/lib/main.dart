import 'package:flutter/material.dart';
import 'signup_page.dart';
import 'login_page.dart';
import 'forgot_password_page.dart';
import 'home_page.dart';
import 'package:google_fonts/google_fonts.dart';  

void main() {
  runApp(const CarLeaseApp());
}

class CarLeaseApp extends StatelessWidget {
  const CarLeaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lease Intelligence',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Inter',
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}