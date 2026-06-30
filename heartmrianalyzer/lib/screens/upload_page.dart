import 'package:flutter/material.dart';
// --- Assurez-vous que ces chemins sont corrects ---
import 'package:heartmrianalyzer/screens/report_page.dart';
import 'package:heartmrianalyzer/screens/history_screen.dart';
import 'package:heartmrianalyzer/screens/profile_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
// import 'package:intl/intl.dart'; // Peut ne plus être nécessaire ici si non utilisé
import 'package:easy_localization/easy_localization.dart'; // <-- Importer Easy Localization

class UploadPage extends StatefulWidget {
  @override
  _UploadPageState createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  String _responseMessage = ''; // Garde le message d'erreur/état final traduit
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _pickImage() async {
    if (_isLoading) return;
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        if (mounted) {
          setState(() {
            _image = File(pickedFile.path);
            _responseMessage = ''; // Effacer l'ancien message
          });
        }
      }
    } catch (e) {
      print("Error picking image: $e");
      if (mounted) {
        setState(() {
          // Assigner le message traduit directement
          _responseMessage = 'uploadPage.errorMessages.pickImageError'.tr();
        });
      }
    }
  }

  // --- Nouvelle fonction pour enregistrer l'événement dans l'historique ---
  Future<void> _saveReportGeneratedEventToHistory(Map<String, dynamic> result, Timestamp eventTimestamp, String userId) async {
    try {
      final bool isSickResult = result['is_sick'] ?? false;
      final double probabilityResult = (result['probability'] as num?)?.toDouble() ?? 0.0;
      // Obtenir la clé de traduction appropriée
      final String detailsKey = isSickResult
          ? 'uploadPage.historyEventDetails.anomalyDetected'
          : 'uploadPage.historyEventDetails.noAnomalyDetected';
      // Traduire la chaîne en passant l'argument de confiance
      final String detailsText = detailsKey.tr(namedArgs: {'confidence': probabilityResult.toStringAsFixed(1)});

      final historyEventData = {
        'timestamp': eventTimestamp,
        'type': 'report_generated',
        'details': detailsText, // <-- Détails traduits
        'actorId': userId,
        'actorRole': 'Patient', // Peut être traduit si nécessaire 'roles.patient'.tr()
        'result_data': {
          'is_sick': isSickResult,
          'probability': probabilityResult,
        }
      };

      await _firestore.collection('users').doc(userId).collection('history').add(historyEventData);
      print('Event (report_generated) saved to users/$userId/history');

    } catch (e) {
      print('Error saving report_generated event to history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Utiliser la clé traduite avec l'erreur comme argument
              content: Text('uploadPage.errorMessages.historySaveError'.tr(namedArgs: {'error': e.toString()})),
              backgroundColor: Colors.orange
          ),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_image == null) {
      if (mounted) setState(() { _responseMessage = 'uploadPage.errorMessages.selectImageFirst'.tr(); }); // Traduit
      return;
    }
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() { _responseMessage = 'uploadPage.errorMessages.userNotConnected'.tr(); }); // Traduit
      return;
    }
    final userId = currentUser.uid;
    if (mounted) setState(() { _isLoading = true; _responseMessage = ''; }); // Réinitialiser

    var uri = Uri.parse('http://172.16.8.139:5000/predict'); // << Vérifier IP
    var request = http.MultipartRequest('POST', uri);

    try {
      var pic = await http.MultipartFile.fromPath('file', _image!.path);
      request.files.add(pic);
      print("Sending request to API: $uri");
      var response = await request.send().timeout(const Duration(seconds: 60));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        print("API Response: $respStr");
        if (!mounted) return;
        Map<String, dynamic> result;
        try {
          result = json.decode(respStr) as Map<String, dynamic>;
        } catch (e) {
          print("Error decoding JSON response: $e");
          if (mounted) {
            setState(() {
              _responseMessage = 'uploadPage.errorMessages.invalidApiResponse'.tr(); // Traduit
              _isLoading = false;
            });
          }
          return;
        }
        // Normaliser le résultat
        final bool isSickResult = result['is_sick'] ?? result['isSick'] ?? false;
        final double probabilityResult = (result['probability'] as num?)?.toDouble() ?? 0.0;
        final consistentResult = {
          'is_sick': isSickResult,
          'probability': probabilityResult,
        };
        final Timestamp eventTimestamp = Timestamp.now();

        // 1. Enregistrer l'événement dans l'historique (utilise maintenant les traductions pour les détails)
        await _saveReportGeneratedEventToHistory(consistentResult, eventTimestamp, userId);

        if (!mounted) return;

        // 2. Naviguer vers la page de rapport
        Navigator.push( context, MaterialPageRoute( builder: (context) => ReportPage( result: consistentResult, userId: userId, imageFile: _image, ), ), );

      } else { // Erreur API
        final errorBody = await response.stream.bytesToString();
        print("Error from server API: ${response.statusCode} - $errorBody");
        if (mounted) {
          setState(() {
            // Traduire avec le code d'erreur comme argument
            _responseMessage = 'uploadPage.errorMessages.analysisFailed'.tr(namedArgs: {'code': response.statusCode.toString()});
          });
        }
      }
    } on TimeoutException catch (_) {
      print("Error: Request timeout");
      if (mounted) { setState(() { _responseMessage = 'uploadPage.errorMessages.requestTimeout'.tr(); }); } // Traduit
    } on SocketException catch (e) {
      print("Network Error: $e");
      if (mounted) { setState(() { _responseMessage = 'uploadPage.errorMessages.connectionError'.tr(); }); } // Traduit
    } on http.ClientException catch (e){
      print("HTTP Client Error: $e");
      if (mounted) {
        setState(() {
          // Traduire avec le message d'erreur comme argument
          _responseMessage = 'uploadPage.errorMessages.networkError'.tr(namedArgs: {'message': e.message});
        });
      }
    } catch (e) {
      print("Error during upload/analysis: $e");
      if (mounted) {
        setState(() {
          // Traduire avec l'erreur comme argument
          _responseMessage = 'uploadPage.errorMessages.unexpectedError'.tr(namedArgs: {'error': e.toString()});
        });
      }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  // --- Méthode Build (mise à jour avec les traductions) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Utiliser la clé de traduction
        title: Text('uploadPage.appBarTitle'.tr(), style: const TextStyle( color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22, )),
        centerTitle: true,
        // Style ou thème global
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            // Utiliser la clé de traduction pour le tooltip
            tooltip: 'uploadPage.profileTooltip'.tr(),
            onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())); },
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            // Utiliser la clé de traduction pour le tooltip
            tooltip: 'uploadPage.historyTooltip'.tr(),
            onPressed: () {
              final userId = _auth.currentUser?.uid;
              if (userId != null && userId.isNotEmpty) {
                Navigator.push(context, MaterialPageRoute( builder: (context) => HistoryScreen(patientId: userId) ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    // Utiliser la clé de traduction
                      content: Text('uploadPage.historyAccessDenied'.tr()),
                      backgroundColor: Colors.orange
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        // Garder la décoration si elle existe
        // decoration: const BoxDecoration( /* ... Gradient ... */ ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                elevation: 10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monitor_heart_outlined, size: 60, color: Color(0xFFD32F2F)),
                      const SizedBox(height: 20),
                      // Utiliser la clé de traduction
                      Text(
                        'uploadPage.mainTitle'.tr(),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 15),
                      // Utiliser la clé de traduction
                      Text(
                        'uploadPage.subTitle'.tr(),
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),

                      // Zone d'affichage de l'image
                      Container(
                        width: double.infinity, height: 200,
                        decoration: BoxDecoration( color: Colors.grey[200], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[300]!), ),
                        child: _image == null
                            ? Column( mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.image_search, size: 50, color: Colors.grey[400]),
                          const SizedBox(height: 10),
                          // Utiliser la clé de traduction
                          Text('uploadPage.noImageSelected'.tr(), style: TextStyle(color: Colors.grey[600])),
                        ], )
                            : ClipRRect( borderRadius: BorderRadius.circular(15), child: Image.file(_image!, fit: BoxFit.cover), ),
                      ),
                      const SizedBox(height: 25),

                      // Bouton Analyser
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _uploadImage,
                          style: ElevatedButton.styleFrom( backgroundColor: const Color(0xFFD32F2F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 5, disabledBackgroundColor: Colors.grey, ),
                          child: _isLoading
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                              : Row( mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.analytics_outlined, color: Colors.white),
                            const SizedBox(width: 10),
                            // Utiliser la clé de traduction
                            Text('uploadPage.analyzeButton'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ], ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Bouton Sélectionner Image
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _pickImage,
                          icon: const Icon(Icons.photo_library_outlined, color: Color(0xFFD32F2F)),
                          // Utiliser la clé de traduction
                          label: Text( 'uploadPage.pickImageButton'.tr(), style: const TextStyle(fontSize: 16, color: Color(0xFFD32F2F)), ),
                          style: OutlinedButton.styleFrom( side: const BorderSide(color: Color(0xFFD32F2F)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Message de statut/erreur (déjà traduit lors de l'assignation)
                      if (_responseMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            _responseMessage, // Affiche le message traduit stocké
                            style: TextStyle(
                              color: _responseMessage.contains('Erreur') || _responseMessage.contains('Échec') || _responseMessage.contains('Error') // Condition basique pour la couleur
                                  ? Colors.orange[900]
                                  : Colors.blueAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}