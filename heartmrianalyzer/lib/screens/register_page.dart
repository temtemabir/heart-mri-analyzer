import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // Import easy_localization

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController surnameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController birthDateController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  // 'selectedRole' stores the INTERNAL, NON-LOCALIZED value like "Médecin" or "Patient".
  // This is what you'll use for logic and saving to Firestore.
  // The default 'Médecin' here is an internal key, not a display string.
  String selectedRole = 'Médecin'; // Default internal value
  bool isPatient = false;
  DateTime? selectedBirthDate;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Initialize isPatient based on the default internal selectedRole
    // 'Patient' here is the internal key.
    isPatient = selectedRole == 'Patient';
  }

  @override
  void dispose() {
    nameController.dispose();
    surnameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    birthDateController.dispose();
    addressController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  // Error Dialog
  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog( // Use ctx from builder for Navigator.pop
        title: Text('errorDialogTitle'.tr(), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        content: Text(message, style: TextStyle(color: Colors.black)), // Message is already localized by caller
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text('errorDialogButtonOk'.tr(), style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  // Date Picker
  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedBirthDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: context.locale, // Use easy_localization's current locale for the picker UI
    );
    if (pickedDate != null && pickedDate != selectedBirthDate) {
      setState(() {
        selectedBirthDate = pickedDate;
        birthDateController.text =
        "${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // These are the internal values/keys for the dropdown.
    // The displayed text will be their localized versions.
    const String internalRoleDoctorKey = 'Médecin'; // Internal key
    const String internalRolePatientKey = 'Patient';   // Internal key

    return Scaffold(
      appBar: AppBar(
        title: Text('registerPageTitle'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
        // To make AppBar text and icon white if not already by theme:
        // foregroundColor: Colors.white,
        // iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCard(
              child: Column(
                children: [
                  // Pass the TRANSLATED string to the 'label' parameter
                  _buildTextField(controller: nameController, label: 'textFieldName'.tr(), icon: Icons.person),
                  _buildTextField(controller: surnameController, label: 'textFieldSurname'.tr(), icon: Icons.person_outline),
                  _buildTextField(controller: emailController, label: 'textFieldEmail'.tr(), icon: Icons.email, keyboardType: TextInputType.emailAddress),
                ],
              ),
            ),
            SizedBox(height: 16),
            _buildCard(
              child: Column(
                children: [
                  _buildTextField(controller: passwordController, label: 'textFieldPassword'.tr(), icon: Icons.lock, obscureText: true),
                  _buildTextField(controller: confirmPasswordController, label: 'textFieldConfirmPassword'.tr(), icon: Icons.lock_outline, obscureText: true),
                ],
              ),
            ),
            SizedBox(height: 16),
            _buildCard(
              child: Column(
                // crossAxisAlignment: CrossAxisAlignment.start, // Uncomment if you want "Rôle" aligned left
                children: [
                  Text('dropdownRoleLabel'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                      value: selectedRole, // This uses the internal, non-localized value ('Médecin' or 'Patient')
                      isExpanded: true,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedRole = newValue; // Update the internal value
                            isPatient = selectedRole == internalRolePatientKey; // Compare with internal key
                          });
                        }
                      },
                      // The items' values are the internal keys.
                      // The child Text displays the localized version.
                      items: [
                        DropdownMenuItem<String>(
                          value: internalRoleDoctorKey, // Internal key
                          child: Text('dropdownRoleDoctor'.tr(), style: TextStyle(fontSize: 16)),
                        ),
                        DropdownMenuItem<String>(
                          value: internalRolePatientKey, // Internal key
                          child: Text('dropdownRolePatient'.tr(), style: TextStyle(fontSize: 16)),
                        ),
                      ]
                  ),
                  if (isPatient) ...[
                    GestureDetector(
                      onTap: () => _selectBirthDate(context),
                      child: AbsorbPointer(
                        child: _buildTextField(
                          controller: birthDateController,
                          label: 'textFieldBirthDate'.tr(),
                          icon: Icons.calendar_today,
                        ),
                      ),
                    ),
                    _buildTextField(controller: addressController, label: 'textFieldAddress'.tr(), icon: Icons.location_on),
                    _buildTextField(controller: phoneController, label: 'textFieldPhone'.tr(), icon: Icons.phone, keyboardType: TextInputType.phone),
                  ],
                ],
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _registerUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                  shadowColor: Colors.red[500],
                  // foregroundColor: Colors.white, // To make button text white
                ),
                child: Text('buttonRegister'.tr(), style: TextStyle(fontSize: 18)),
              ),
            ),
            SizedBox(height: 16), // Some bottom padding
          ],
        ),
      ),
    );
  }

  Future<void> _registerUser() async {
    // Password confirmation check
    if (passwordController.text != confirmPasswordController.text) {
      _showErrorDialog('errorPasswordsDoNotMatch'.tr());
      return;
    }

    // Trim and get text field values
    final String name = nameController.text.trim();
    final String surname = surnameController.text.trim();
    final String email = emailController.text.trim();
    final String password = passwordController.text;

    // General mandatory field checks
    if (name.isEmpty || surname.isEmpty || email.isEmpty || password.isEmpty) {
      _showErrorDialog('errorFillAllRequiredFields'.tr());
      return;
    }

    // Patient-specific mandatory field checks
    String address = '';
    String phone = '';
    if (isPatient) { // isPatient is true if selectedRole (internal key) == 'Patient' (internal key)
      if (selectedBirthDate == null) {
        _showErrorDialog('errorSelectBirthDate'.tr());
        return;
      }
      address = addressController.text.trim();
      phone = phoneController.text.trim();
      if (address.isEmpty) {
        _showErrorDialog('errorEnterAddress'.tr());
        return;
      }
      if (phone.isEmpty || !RegExp(r'^[0-9]+$').hasMatch(phone) || phone.length < 8) {
        _showErrorDialog('errorEnterValidPhone'.tr());
        return;
      }
    }

    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userId = userCredential.user?.uid;
      if (userId == null) {
        _showErrorDialog('errorCreatingUserNoId'.tr());
        return;
      }

      Map<String, dynamic> userData = {
        'name': name,
        'surname': surname,
        'email': email,
        'role': selectedRole, // Store the internal, non-localized value ('Médecin' or 'Patient')
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (isPatient) {
        userData['birthDate'] = Timestamp.fromDate(selectedBirthDate!);
        userData['address'] = address;
        userData['phone'] = phone;
      }

      await _firestore.collection('users').doc(userId).set(userData);
      print('Utilisateur créé : $userId avec rôle: $selectedRole');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('successAccountCreated'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }

    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'weak-password') {
        errorMessage = 'errorAuthWeakPassword'.tr();
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'errorAuthEmailInUse'.tr();
      } else if (e.code == 'invalid-email') {
        errorMessage = 'errorAuthInvalidEmail'.tr();
      } else {
        errorMessage = 'errorAuthGeneric'.tr(args: [e.message ?? e.code]);
      }
      _showErrorDialog(errorMessage);
    } catch (e) {
      _showErrorDialog('errorUnexpected'.tr(args: [e.toString()]));
    }
  }

  // _buildCard method is exactly from your original code
  Widget _buildCard({required Widget child}) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.red[500]!),
          ),
        ),
      ),
    );
  }
}