import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart'; // <-- Importer Easy Localization

// Assurez-vous que ces écrans d'importation sont corrects pour votre projet
import 'add_note_screen.dart';
import 'history_screen.dart';

class ConsultationScreen extends StatefulWidget {
  const ConsultationScreen({super.key});

  @override
  _ConsultationScreenState createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _patients = [];
  List<DocumentSnapshot> _filteredPatients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    setState(() { _isLoading = true; });
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Patient')
          .get();
      if (mounted) { // <-- Vérifier si le widget est toujours monté
        setState(() {
          _patients = snapshot.docs;
          _filteredPatients = _patients;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching patients: $e");
      if (mounted) { // <-- Vérifier si le widget est toujours monté
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Utiliser la clé de traduction
            content: Text('consultationScreen.errorLoading'.tr()),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
        setState(() { _isLoading = false; });
      }
    }
  }

  void _filterPatients(String keyword) {
    setState(() {
      if (keyword.isEmpty) {
        _filteredPatients = _patients;
      } else {
        _filteredPatients = _patients.where((patient) {
          final data = patient.data() as Map<String, dynamic>? ?? {};
          // Garder la logique de recherche originale (nom/prénom)
          final name = data['name']?.toString().toLowerCase() ?? '';
          final surname = data['surname']?.toString().toLowerCase() ?? '';
          return name.contains(keyword.toLowerCase()) ||
              surname.contains(keyword.toLowerCase());
        }).toList();
      }
    });
  }

  // --- MODIFIÉ POUR LA TRADUCTION : Calcule la valeur de l'âge ou un indicateur ---
  int? _calculateAgeValue(Timestamp? birthDateTimestamp) {
    if (birthDateTimestamp == null) {
      return null; // Indique que l'âge n'est pas fourni
    }
    DateTime birthDate = birthDateTimestamp.toDate();
    DateTime today = DateTime.now();

    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }

    if (age < 0) {
      return -1; // Indique une date invalide
    }
    return age;
  }
  // --- FIN MODIFIÉ ---

  // --- NOUVELLE FONCTION UTILITAIRE : Obtient la chaîne d'âge traduite ---
  String _getAgeDisplayString(Timestamp? birthDateTimestamp) {
    final ageValue = _calculateAgeValue(birthDateTimestamp);
    if (ageValue == null) {
      // Clé pour "Âge non fourni"
      return 'patientCard.ageNotProvided'.tr();
    } else if (ageValue < 0) {
      // Clé pour "Date de naissance invalide"
      return 'patientCard.invalidBirthDate'.tr();
    } else {
      // Construit la chaîne avec l'âge et le suffixe traduit ("ans", "years old", "سنة")
      // Utilise la clé `yearsSuffix` définie dans les fichiers JSON
      return '$ageValue ${'patientCard.yearsSuffix'.tr()}';
      // Alternative si vous aviez utilisé une clé comme "yearsOld": "{age} ans" dans le JSON:
      // return 'patientCard.yearsOld'.tr(namedArgs: {'age': ageValue.toString()});
    }
  }
  // --- FIN NOUVELLE FONCTION UTILITAIRE ---

  @override
  Widget build(BuildContext context) {
    // Ces couleurs peuvent être définies dans le thème global (MyApp)
    const primaryColor = Color(0xFFD32F2F);
    const backgroundColor = Color(0xFFFAFAFA);

    return Scaffold(
      appBar: AppBar(
        // Utiliser la clé de traduction pour le titre
        title: Text('consultationScreen.title'.tr()),
        // Les autres propriétés (backgroundColor, etc.) peuvent être héritées du thème
        flexibleSpace: Container( // Garder le dégradé si nécessaire
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        color: backgroundColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      // Utiliser les clés de traduction
                      labelText: 'consultationScreen.searchLabel'.tr(),
                      hintText: 'consultationScreen.searchHint'.tr(),
                      prefixIcon: const Icon(Icons.search, color: primaryColor),
                      border: InputBorder.none,
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _filterPatients('');
                        },
                      )
                          : null,
                    ),
                    onChanged: _filterPatients,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                    const SizedBox(height: 16),
                    // Utiliser la clé de traduction
                    Text(
                      'consultationScreen.loading'.tr(),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
                  : _filteredPatients.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 60,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    // Utiliser les clés de traduction, vérifier si la recherche est active
                    Text(
                      _searchController.text.isEmpty
                          ? 'consultationScreen.noPatientsRegistered'.tr()
                          : 'consultationScreen.noPatientsFound'.tr(),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : RefreshIndicator( // Garder si vous voulez le pull-to-refresh
                onRefresh: _fetchPatients,
                color: primaryColor,
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _filteredPatients.length,
                  itemBuilder: (context, index) {
                    final patientData = _filteredPatients[index].data()
                    as Map<String, dynamic>? ?? {};

                    // Utiliser les clés de traduction pour les valeurs par défaut
                    final name = patientData['name']?.toString() ?? 'patientCard.unknownSurname'.tr();
                    final surname = patientData['surname']?.toString() ?? 'patientCard.unknownFirstName'.tr();
                    final email = patientData['email']?.toString() ?? 'patientCard.emailNotProvided'.tr();
                    final patientId = _filteredPatients[index].id;
                    final address = patientData['address']?.toString() ?? 'patientCard.addressNotProvided'.tr();
                    // Utiliser 'phone' comme dans votre code original
                    final phone = patientData['phone']?.toString() ?? 'patientCard.phoneNotProvided'.tr();

                    // --- Utiliser la fonction utilitaire pour la chaîne d'âge traduite ---
                    final birthDateTimestamp = patientData['birthDate'] as Timestamp?;
                    final ageDisplay = _getAgeDisplayString(birthDateTimestamp);
                    // --- ---

                    final patientFullName = "$surname $name"; // Combiner pour l'affichage et la transmission

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person_outline,
                                    color: primaryColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        patientFullName, // Afficher le nom combiné
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        email,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      _buildDetailRow(Icons.location_on_outlined, address, Colors.grey[600]!),
                                      // Utiliser la chaîne d'âge traduite
                                      _buildDetailRow(Icons.cake_outlined, ageDisplay, Colors.grey[600]!),
                                      _buildDetailRow(Icons.phone_outlined, phone, Colors.grey[600]!),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.history, size: 20),
                                    // Utiliser la clé de traduction
                                    label: Text('patientCard.historyButton'.tr()),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryColor,
                                      side: const BorderSide(color: primaryColor),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              HistoryScreen(
                                                patientId: patientId,
                                                // Le nom n'est peut-être pas nécessaire si HistoryScreen utilise une clé statique
                                                // patientName: patientFullName, // Passer si HistoryScreen l'utilise pour son titre
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.note_add_outlined, size: 20),
                                    // Utiliser la clé de traduction
                                    label: Text('patientCard.newNoteButton'.tr()),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AddNoteScreen( // Passer ID et nom pour l'argument du titre
                                                patientId: patientId,
                                                patientName: patientFullName,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Cette fonction utilitaire reste inchangée car elle affiche le texte qui lui est passé.
  Widget _buildDetailRow(IconData icon, String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor.withOpacity(0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}


