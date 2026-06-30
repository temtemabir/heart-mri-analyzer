import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _feedbackMessage;
  bool _isSuccess = false;

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
      _isSuccess = false;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _feedbackMessage = 'forgotPasswordPage.successMessage'.tr();
          _isSuccess = true;
        });
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'user-not-found') {
        errorMessage = 'forgotPasswordPage.errorUserNotFound'.tr();
      } else if (e.code == 'invalid-email') {
        errorMessage = 'errorAuthInvalidEmail'.tr(); // Réutiliser de Register/Login
      } else {
        errorMessage = 'forgotPasswordPage.errorGeneric'.tr(args: [e.message ?? e.code]);
      }
      if (mounted) {
        setState(() {
          _feedbackMessage = errorMessage;
          _isSuccess = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _feedbackMessage = 'forgotPasswordPage.errorGeneric'.tr(args: [e.toString()]);
          _isSuccess = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('forgotPasswordPage.appBarTitle'.tr(), style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(Icons.lock_reset, size: 80, color: Colors.redAccent),
                SizedBox(height: 20),
                Text(
                  'forgotPasswordPage.title'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'forgotPasswordPage.instruction'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'loginPageEmailLabel'.tr(), // Réutiliser la clé
                    prefixIcon: Icon(Icons.email),
                    filled: true,
                    fillColor: Colors.red[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'errorValidationEmailEmpty'.tr(); // Clé de RegisterPage
                    }
                    if (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                      return 'errorValidationEmailInvalid'.tr(); // Clé de RegisterPage
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),
                if (_isLoading)
                  Center(child: CircularProgressIndicator(color: Colors.redAccent))
                else
                  ElevatedButton(
                    onPressed: _sendResetEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('forgotPasswordPage.sendResetEmailButton'.tr()),
                  ),
                SizedBox(height: 16),
                if (_feedbackMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      _feedbackMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _isSuccess ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Retour à la page de connexion
                  },
                  child: Text(
                    'forgotPasswordPage.backToLoginButton'.tr(),
                    style: TextStyle(color: Colors.redAccent),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}