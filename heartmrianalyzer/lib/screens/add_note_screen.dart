import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart'; 

class AddNoteScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const AddNoteScreen({
    Key? key,
    required this.patientId,
    required this.patientName,
  }) : super(key: key);

  @override
  _AddNoteScreenState createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final TextEditingController _detailsController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _doctorId;
  String _doctorName = ''; // Initialisé vide
  bool _isLoadingDoctorName = true;
  String? _doctorLoadErrorKey; // Stocke la CLÉ de traduction de l'erreur
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchDoctorInfo();
  }

  Future<void> _fetchDoctorInfo() async {
    if (!mounted) return;
    setState(() {
      _isLoadingDoctorName = true;
      _doctorLoadErrorKey = null; // Réinitialiser l'erreur au début
      _doctorName = ''; // Réinitialiser le nom
    });

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() {
        _doctorLoadErrorKey = 'addNoteScreen.doctorNotConnectedError';
        _isLoadingDoctorName = false;
      });
      return;
    }
    _doctorId = currentUser.uid;

    try {
      DocumentSnapshot doctorDoc = await _firestore.collection('users').doc(_doctorId).get();
      if (mounted) {
        if (doctorDoc.exists) {
          final data = doctorDoc.data() as Map<String, dynamic>?;
          // Construire le nom, utiliser la clé de traduction pour le préfixe
          String prefix = 'addNoteScreen.doctorPrefix'.tr();
          String namePart = data?['name'] ?? '';
          String surnamePart = data?['surname'] ?? '';
          String potentialName = '$prefix$namePart $surnamePart'.trim();

          setState(() {
            // Si le nom construit n'est que le préfixe ou vide, ou si l'email est vide, utiliser 'Médecin Inconnu'
            if (potentialName.isEmpty || potentialName == prefix.trim() || (namePart.isEmpty && surnamePart.isEmpty && (data?['email']??'').isEmpty) ) {
              _doctorLoadErrorKey = 'addNoteScreen.unknownDoctor';
            } else if (namePart.isEmpty && surnamePart.isEmpty) {
              // Si nom/prénom vides mais email existe, utiliser l'email
              _doctorName = data?['email'];
            }
            else {
              // Sinon, utiliser le nom construit
              _doctorName = potentialName;
            }
            _isLoadingDoctorName = false;
          });
        } else {
          setState(() {
            _doctorLoadErrorKey = 'addNoteScreen.unknownDoctor';
            _isLoadingDoctorName = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching doctor info: $e"); // Log l'erreur réelle
      if (mounted) {
        setState(() {
          _doctorLoadErrorKey = 'addNoteScreen.doctorLoadError';
          _isLoadingDoctorName = false;
        });
      }
    }
  }

  Future<void> _saveDoctorNoteAddedEventToHistory(String details) async {
    if (_doctorId == null || !mounted) return;
    try {
      await _firestore.collection('users').doc(widget.patientId).collection('history').add({
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'doctor_note_added',
        'details': details,
        'actorId': _doctorId,
        'actorRole': 'Médecin', // Peut aussi être traduit si nécessaire
      });
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Utiliser la clé de traduction avec argument
            content: Text('addNoteScreen.historyError'.tr(namedArgs: {'error': e.toString()})),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _saveNote() async {
    final details = _detailsController.text.trim();
    if (details.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Utiliser la clé de traduction
            content: Text('addNoteScreen.validationHint'.tr()),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
      return;
    }

    // Vérifier si le nom du médecin est chargé et s'il n'y a pas d'erreur
    if (_doctorId == null || _isLoadingDoctorName || _doctorLoadErrorKey != null) return;
    if (_isSaving) return;

    setState(() { _isSaving = true; });

    try {
      final releaseDate = DateTime.now().add(const Duration(days: 7));
      await _firestore.collection('consultations').add({
        'patientId': widget.patientId,
        'patientName': widget.patientName, // Garder le nom tel que reçu
        'doctorId': _doctorId,
        'doctorName': _doctorName, // Utiliser le nom final (peut être email ou Dr. Nom)
        'details': details,
        'createdAt': FieldValue.serverTimestamp(),
        'releaseDate': Timestamp.fromDate(releaseDate),
      });

      await _saveDoctorNoteAddedEventToHistory(details);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Utiliser la clé de traduction
            content: Text('addNoteScreen.saveSuccess'.tr()),
            backgroundColor: const Color(0xFF388E3C), // Vert succès
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Utiliser la clé de traduction avec argument
            content: Text('addNoteScreen.saveError'.tr(namedArgs: {'error': e.toString()})),
            backgroundColor: const Color(0xFFD32F2F), // Rouge erreur
          ),
        );
      }
    } finally {
      if (mounted) { setState(() { _isSaving = false; }); }
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  String _getDoctorDisplayValue() {
    if (_isLoadingDoctorName) {
      return 'addNoteScreen.loadingDoctor'.tr();
    } else if (_doctorLoadErrorKey != null) {
      return _doctorLoadErrorKey!.tr(); // Affiche le message d'erreur traduit
    } else {
      return _doctorName; // Affiche le nom chargé (peut être Dr. Nom ou email)
    }
  }


  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFD32F2F);
    const secondaryColor = Color(0xFF1976D2); // Couleur secondaire pour icône médecin
    const backgroundColor = Color(0xFFFAFAFA);

    return Scaffold(
      appBar: AppBar(
        // Utiliser la clé de traduction
        title: Text('addNoteScreen.appBarTitle'.tr(),
          style: const TextStyle( // Garder le style si nécessaire
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        // backgroundColor, iconTheme, elevation peuvent être hérités du thème global
        flexibleSpace: Container( // Garder le dégradé
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
        decoration: const BoxDecoration(
          color: backgroundColor,
          // Optionnel : garder l'image de fond si elle existe
          // image: DecorationImage(
          //   image: AssetImage('assets/medical_bg.png'),
          //   fit: BoxFit.cover,
          //   opacity: 0.03,
          // ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header avec icône médicale
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.medical_services, // Icône existante
                          color: primaryColor,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Utiliser la clé de traduction
                    Center(
                      child: Text(
                        'addNoteScreen.header'.tr(),
                        style: const TextStyle(
                          color: primaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Section Patient
                    _buildInfoRow(
                      // Utiliser la clé de traduction
                      label: 'addNoteScreen.patientLabel'.tr(),
                      value: widget.patientName, // Nom du patient tel que reçu
                      icon: Icons.person_outline,
                      iconColor: primaryColor,
                    ),
                    const SizedBox(height: 15),

                    // Section Médecin
                    _buildInfoRow(
                      // Utiliser la clé de traduction
                      label: 'addNoteScreen.doctorLabel'.tr(),
                      // Utiliser la fonction pour obtenir la valeur d'affichage correcte
                      value: _getDoctorDisplayValue(),
                      icon: Icons.medical_services_outlined,
                      iconColor: secondaryColor,
                      // Passer l'état de chargement pour afficher potentiellement un indicateur dans _buildInfoRow si besoin
                      isLoading: _isLoadingDoctorName,
                    ),
                    const SizedBox(height: 30),

                    // Champ de texte pour la note
                    // Utiliser la clé de traduction
                    Text(
                      'addNoteScreen.notesLabel'.tr(),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _detailsController,
                        maxLines: 8,
                        minLines: 5,
                        style: const TextStyle(fontSize: 15),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(15),
                          filled: true,
                          fillColor: Colors.grey[50],
                          // hintText peut être ajouté et traduit aussi si nécessaire
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Bouton d'enregistrement
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        // Désactiver si sauvegarde en cours, chargement OU erreur de chargement médecin
                        onPressed: _isSaving || _isLoadingDoctorName || _doctorLoadErrorKey != null
                            ? null
                            : _saveNote,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          shadowColor: primaryColor.withOpacity(0.3),
                        ),
                        child: _isSaving
                            ? Row( // Garder la structure existante
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Utiliser la clé de traduction
                            Text('addNoteScreen.savingButton'.tr()),
                          ],
                        )
                            : Row( // Garder la structure existante
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save_alt_rounded, size: 22),
                            const SizedBox(width: 10),
                            // Utiliser la clé de traduction
                            Text(
                              'addNoteScreen.saveButton'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // _buildInfoRow reste presque identique, mais reçoit `isLoading`
  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    bool isLoading = false, // Ajout du paramètre isLoading
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label, // Le label est déjà traduit avant d'appeler _buildInfoRow
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              // Afficher la valeur (qui peut être un message de chargement/erreur traduit)
              Text(
                value, // La valeur est déjà traduite ou formatée avant d'appeler _buildInfoRow
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}