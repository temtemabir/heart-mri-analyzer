import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'forgot_password_page.dart'; // <-- Importez la nouvelle page

class LoginPage extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.redAccent,
        title: Text(
          'appTitle'.tr(),
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/heart_logo.png',
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  "loginPageWelcome".tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 32),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'loginPageEmailLabel'.tr(),
                    prefixIcon: Icon(Icons.email),
                    filled: true,
                    fillColor: Colors.red[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'loginPagePasswordLabel'.tr(),
                    prefixIcon: Icon(Icons.lock),
                    filled: true,
                    fillColor: Colors.red[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  obscureText: true,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (!context.mounted) return;
                    try {
                      final email = emailController.text.trim();
                      final password = passwordController.text.trim();

                      if (email.isEmpty || password.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('errorFillAllRequiredFields'.tr())),
                        );
                        return;
                      }

                      UserCredential userCredential = await FirebaseAuth.instance
                          .signInWithEmailAndPassword(email: email, password: password);

                      DocumentSnapshot userDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(userCredential.user!.uid)
                          .get();

                      if (!userDoc.exists || userDoc.data() == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('loginPageErrorUnknownRole'.tr())),
                        );
                        return;
                      }

                      final userData = userDoc.data() as Map<String, dynamic>;
                      if (!userData.containsKey('role')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('loginPageErrorUnknownRole'.tr())),
                        );
                        return;
                      }
                      String role = userData['role'];

                      if (role == 'Patient') {
                        if (context.mounted) Navigator.pushReplacementNamed(context, '/upload');
                      } else if (role == 'Médecin') {
                        if (context.mounted) Navigator.pushReplacementNamed(context, '/consultation');
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('loginPageErrorUnknownRole'.tr())),
                          );
                        }
                      }
                    } on FirebaseAuthException catch (e) {
                      String errorMessage;
                      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
                        errorMessage = 'errorAuthInvalidEmailOrPassword'.tr();
                      } else if (e.code == 'invalid-email') {
                        errorMessage = 'errorAuthInvalidEmail'.tr();
                      } else {
                        errorMessage = 'loginPageErrorGeneric'.tr(args: [e.message ?? e.code]);
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(errorMessage)),
                        );
                      }
                    }
                    catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('loginPageErrorGeneric'.tr(args: [e.toString()]))),
                        );
                      }
                    }
                  },
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
                  child: Text('loginPageLoginButton'.tr()),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
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
                  child: Text('loginPageCreateAccountButton'.tr()),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // --- NAVIGATION VERS LA PAGE DE MOT DE PASSE OUBLIÉ ---
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ForgotPasswordPage()),
                    );
                    // Ou si vous avez une route nommée:
                    // Navigator.pushNamed(context, '/forgot-password');
                  },
                  child: Text(
                    "loginPageForgotPasswordButton".tr(),
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}