import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Fonction pour ajouter une action dans l'historique
Future<void> ajouterActionHistorique(String actionDescription) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;

  if (userId == null) return;  // Assurer que l'utilisateur est connecté

  try {
    await FirebaseFirestore.instance.collection('history').add({
      'action': actionDescription,  // L'action décrite (exemple: "Ajout d'un rapport")
      'timestamp': FieldValue.serverTimestamp(),  // L’heure de l’action
      'userId': userId,  // L'id de l'utilisateur qui a effectué l'action
    });
  } catch (e) {
    print("Erreur lors de l'ajout de l'action à l'historique: ${e.toString()}");
  }
}
