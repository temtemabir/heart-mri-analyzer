import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart'; // Import easy_localization

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  bool _isLoading = true;

  // Internal role keys (match what's stored in Firestore)
  static const String roleDoctorInternal = 'Médecin';
  static const String rolePatientInternal = 'Patient';

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  Future<void> _getUserData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();
        if (mounted) {
          if (userDoc.exists) {
            setState(() {
              userData = userDoc.data() as Map<String, dynamic>?;
              _isLoading = false;
            });
            // print("Données utilisateur récupérées : ${userData.toString()}"); // Original print
          } else {
            // print("Aucune donnée trouvée pour cet utilisateur."); // Original print
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('profileScreenNoDataFound'.tr()), backgroundColor: Colors.orange),
            );
            setState(() { _isLoading = false; });
          }
        }
      } catch (e) {
        // print("Erreur lors de la récupération des données utilisateur : $e"); // Original print
        if (mounted) {
          setState(() { _isLoading = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('profileScreenErrorLoading'.tr(args: [e.toString()])), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      if (mounted) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profileScreenUserNotConnected'.tr()), backgroundColor: Colors.orange),
        );
      }
      // print("Utilisateur non connecté."); // Original print
    }
  }

  String _getLocalizedRole(String? internalRole) {
    if (internalRole == roleDoctorInternal) {
      return 'dropdownRoleDoctor'.tr();
    } else if (internalRole == rolePatientInternal) {
      return 'dropdownRolePatient'.tr();
    }
    return 'profileScreenRoleNotDefined'.tr();
  }


  String _calculateAge(dynamic birthDateData) {
    if (birthDateData == null) {
      return 'profileScreenAgeNotSpecified'.tr();
    }
    DateTime? dob;
    if (birthDateData is Timestamp) {
      dob = birthDateData.toDate();
    } else if (birthDateData is String && birthDateData.isNotEmpty) {
      try {
        if (birthDateData.contains('/')) {
          dob = DateFormat('dd/MM/yyyy', context.locale.toString().replaceAll('_', '-')).parseStrict(birthDateData);
        } else if (birthDateData.contains('-') && birthDateData.length == 10) {
          dob = DateFormat('yyyy-MM-dd', context.locale.toString().replaceAll('_', '-')).parseStrict(birthDateData);
        } else if (birthDateData.length > 10 && birthDateData.contains('T')){
          dob = DateTime.parse(birthDateData);
        }
      } catch (e) {
        // print("Erreur format date de naissance: $e"); // Original print
        return 'profileScreenInvalidDateFormat'.tr();
      }
    }
    if (dob == null) return 'profileScreenInvalidData'.tr();

    DateTime today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return 'profileScreenYearsOld'.tr(args: [age.toString()]);
  }


  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFD32F2F);
    const secondaryTextColor = Colors.black54;
    const primaryTextColor = Colors.black87;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('profileScreenTitle'.tr(), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : userData == null
          ? Center(child: Text('profileScreenUnableToLoad'.tr())) // Translated
          : RefreshIndicator(
        onRefresh: _getUserData,
        color: primaryColor,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildHeaderSection(primaryColor, secondaryTextColor, primaryTextColor),
            const SizedBox(height: 24),
            _buildDetailsCard(primaryColor, secondaryTextColor, primaryTextColor),
            const SizedBox(height: 24),
            if (userData!['role'] == roleDoctorInternal) ...[
              _buildDoctorActionsCard(primaryColor),
              const SizedBox(height: 24),
            ],
            _buildLogoutButton(primaryColor),
          ],
        ),
      ),
    );
  }

  // --- ويدجت لبناء قسم الهيدر (تم تعديله لاستخدام أيقونة) ---
  // This is from your original code structure for the header.
  Widget _buildHeaderSection(Color primaryColor, Color secondaryTextColor, Color primaryTextColor) {
    String name = userData!['name'] ?? 'profileScreenNameNotSpecified'.tr();
    String surname = userData!['surname'] ?? 'profileScreenSurnameNotSpecified'.tr();
    String roleDisplay = _getLocalizedRole(userData!['role']);

    return Column(
      children: [
        CircleAvatar(
          radius: 65,
          backgroundColor: primaryColor.withOpacity(0.1),
          child: CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[300],
            child: Icon(
              Icons.person,
              size: 70,
              color: Colors.white, // Kept original icon color
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '$name $surname',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryTextColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          roleDisplay, // Uses the localized role
          style: TextStyle(fontSize: 16, color: secondaryTextColor),
        ),
      ],
    );
  }
  // ---------------------------------------------------------

  Widget _buildDetailsCard(Color primaryColor, Color secondaryTextColor, Color primaryTextColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'profileScreenPersonalInfo'.tr(), // Translated
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
            ),
            const Divider(height: 24, thickness: 1),
            ProfileDetailRow(
                icon: Icons.email_outlined,
                title: 'profileScreenLabelEmail'.tr(), // Translated
                value: userData!['email'] ?? 'profileScreenValueNotSpecified'.tr(), // Translated default
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor),
            ProfileDetailRow(
                icon: Icons.phone_outlined,
                title: 'profileScreenLabelPhone'.tr(), // Translated
                value: userData!['phone'] ?? 'profileScreenValueNotSpecified'.tr(), // Translated default
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor),
            ProfileDetailRow(
                icon: Icons.location_on_outlined,
                title: 'profileScreenLabelAddress'.tr(), // Translated
                value: userData!['address'] ?? 'profileScreenValueNotSpecified'.tr(), // Translated default
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor),
            if (userData!['role'] == rolePatientInternal)
              ProfileDetailRow(
                  icon: Icons.cake_outlined,
                  title: 'profileScreenLabelAge'.tr(), // Translated
                  value: _calculateAge(userData!['birthDate']), // Already handles translation
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorActionsCard(Color primaryColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        // Kept original padding
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.medical_services_outlined, color: primaryColor),
              title: Text('profileScreenDoctorActionsConsultations'.tr(), style: TextStyle(fontWeight: FontWeight.w500)), // Translated
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pushNamed(context, '/consultation');
              },
            ),
            const Divider(indent: 16, endIndent: 16), // Kept original divider
            ListTile(
              leading: Icon(Icons.history_outlined, color: primaryColor),
              title: Text('profileScreenDoctorActionsPatientHistory'.tr(), style: TextStyle(fontWeight: FontWeight.w500)), // Translated
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pushNamed(context, '/history'); // Changed from /historique to /history
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(Color primaryColor) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: () async {
          final bool? confirmLogout = await showDialog<bool>(
            context: context,
            builder: (alertDialogContext) => AlertDialog(
              title: Text('profileScreenLogoutDialogTitle'.tr()), // Translated
              content: Text('profileScreenLogoutDialogContent'.tr()), // Translated
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(alertDialogContext).pop(false),
                  child: Text('profileScreenLogoutDialogCancel'.tr()), // Translated
                ),
                TextButton(
                  onPressed: () => Navigator.of(alertDialogContext).pop(true),
                  child: Text('profileScreenLogoutDialogConfirm'.tr(), style: TextStyle(color: Colors.red)), // Translated
                ),
              ],
            ),
          );

          if (confirmLogout == true && mounted) {
            try {
              await FirebaseAuth.instance.signOut();
              if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            } catch (e) {
              // print("Erreur lors de la déconnexion: $e"); // Original print
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('profileScreenErrorLogout'.tr(args: [e.toString()])), backgroundColor: Colors.red),
                );
              }
            }
          }
        },
        icon: Icon(Icons.logout, color: primaryColor),
        label: Text('profileScreenLogoutButton'.tr(), style: TextStyle(color: primaryColor)), // Translated
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: primaryColor.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }
}

// --- ProfileDetailRow remains as is, as title/value are passed pre-translated ---
class ProfileDetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color primaryTextColor;
  final Color secondaryTextColor;

  const ProfileDetailRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.primaryTextColor,
    required this.secondaryTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: secondaryTextColor),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: primaryTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}