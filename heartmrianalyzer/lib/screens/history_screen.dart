import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart'; // Import Easy Localization

class HistoryScreen extends StatelessWidget {
  final String patientId;

  const HistoryScreen({Key? key, required this.patientId}) : super(key: key);

  IconData _getIconForEventType(String? eventType) {
    // This logic remains the same as it's based on internal keys
    switch (eventType) {
      case 'report_generated':
        return Icons.bloodtype_outlined;
      case 'report_saved':
        return Icons.assignment_outlined;
      case 'appointment_booked':
        return Icons.medical_services_outlined;
      case 'doctor_note_added':
        return Icons.notes_outlined;
      default:
        return Icons.medical_information_outlined;
    }
  }

  Color _getColorForEventType(String? eventType) {
    // This logic remains the same
    switch (eventType) {
      case 'report_generated':
        return const Color(0xFFD32F2F);
      case 'report_saved':
        return const Color(0xFF1976D2);
      case 'appointment_booked':
        return const Color(0xFF388E3C);
      case 'doctor_note_added':
        return const Color(0xFF7B1FA2);
      default:
        return const Color(0xFF455A64);
    }
  }

  String _getTitleForEvent(BuildContext context, String? eventType, Map<String, dynamic> data) {
    switch (eventType) {
      case 'report_generated':
        bool? isSick = (data['result_data'] as Map?)?['is_sick'];
        if (isSick == true) return 'historyScreen.eventTitles.report_generated_anomaly'.tr();
        if (isSick == false) return 'historyScreen.eventTitles.report_generated_normal'.tr();
        return 'historyScreen.eventTitles.report_generated_new'.tr();
      case 'report_saved':
        return 'historyScreen.eventTitles.report_saved'.tr();
      case 'appointment_booked':
        return 'historyScreen.eventTitles.appointment_booked'.tr();
      case 'doctor_note_added':
        return 'historyScreen.eventTitles.doctor_note_added'.tr();
      default:
        return 'historyScreen.eventTitles.default_event'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('historyScreen.appBarTitle'.tr()),
          backgroundColor: const Color(0xFFD32F2F), // Keep color
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container( // Keep gradient
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'historyScreen.authenticationRequired'.tr(),
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('historyScreen.appBarTitle'.tr(), style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        flexibleSpace: Container(
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
          gradient: LinearGradient(
            colors: [Color(0xFFF5F5F5), Color(0xFFE0E0E0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(patientId)
              .collection('history')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 50),
                    const SizedBox(height: 16),
                    Text(
                      'historyScreen.errorLoading'.tr(),
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD32F2F)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'historyScreen.loadingHistory'.tr(),
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_outlined, color: Colors.grey[400], size: 60),
                    const SizedBox(height: 16),
                    Text(
                      'historyScreen.noHistory'.tr(),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            final historyEvents = snapshot.data!.docs;

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: historyEvents.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final eventData = historyEvents[index].data() as Map<String, dynamic>? ?? {};
                final String? eventType = eventData['type'] as String?;
                final String details = eventData['details'] as String? ?? 'historyScreen.detailsNotAvailable'.tr();
                final Timestamp? timestamp = eventData['timestamp'] as Timestamp?;

                // Use context.locale.languageCode for DateFormat locale preference
                // It's better to use languageCode (e.g., "en", "fr", "ar")
                // than toString() (e.g. "en_US") if your `intl` setup and JSON date patterns
                // are geared towards language only.
                // If you specifically need "fr_FR", "en_US", etc., you can use:
                // context.locale.toStringWithSeparator(separator: '_')
                // For simplicity and general compatibility with intl:
                final String currentLocale = context.locale.languageCode;

                final String formattedDate = timestamp != null
                    ? DateFormat('historyScreen.dateFormat'.tr(), currentLocale).format(timestamp.toDate())
                    : 'historyScreen.unknownDate'.tr();

                final Color eventColor = _getColorForEventType(eventType);

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  shadowColor: Colors.black26,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      // Action when an event is clicked (logic remains)
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: eventColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: eventColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              _getIconForEventType(eventType),
                              color: eventColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getTitleForEvent(context, eventType, eventData),
                                  style: TextStyle(
                                    color: Colors.grey[900],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  details, // Already translated if it was a fallback
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      color: Colors.grey[500],
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      formattedDate, // Already translated
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}