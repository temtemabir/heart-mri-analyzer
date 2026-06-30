import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';

class ReportPage extends StatefulWidget {
  final Map<String, dynamic> result;
  final String userId;
  final File? imageFile;

  const ReportPage({
    Key? key,
    required this.result,
    required this.userId,
    this.imageFile,
  }) : super(key: key);

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String _currentDateFormattedForDisplay = '';
  DateTime _currentDateTimeObject = DateTime.now();
  bool _isSick = false;
  double _probability = 0.0;
  bool _isLoadingPatientData = true;
  Map<String, dynamic>? _patientData;
  String? _patientDataErrorKey;
  bool _bookingConfirmed = false;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoadingAvailableDays = true;
  Set<DateTime> _daysWithAvailableSlots = {};
  bool _isLoadingTimeSlots = false;
  List<Map<String, dynamic>> _availableTimeSlotsForSelectedDay = [];
  String? _selectedTimeSlotId;
  bool _isBooking = false;
  String? _bookingErrorKey;
  Map<String, String>? _bookingErrorArgs;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _currentDateTimeObject = DateTime.now();

    _isSick = widget.result['is_sick'] ?? widget.result['isSick'] ?? false;
    final probabilityValue = widget.result['probability'];
    if (probabilityValue is num) {
      _probability = probabilityValue.toDouble();
    } else {
      _probability = 0.0;
    }
    _fetchPatientData();
    if (_isSick) {
      _fetchDaysWithAvailableSlots();
    } else {
      if (mounted) setState(() => _isLoadingAvailableDays = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeDateLocalesIfNeeded(context);
  }

  void _updateCurrentDateForDisplay() {
    if (mounted && context.mounted) {
      setState(() {
        _currentDateFormattedForDisplay = DateFormat(
            'reportPage.dateFormat'.tr(),
            context.locale.languageCode
        ).format(_currentDateTimeObject);
      });
    }
  }

  Future<void> _initializeDateLocalesIfNeeded(BuildContext context) async {
    final localeString = context.locale.toStringWithSeparator(separator: '_');
    final languageCode = context.locale.languageCode;
    try {
      await initializeDateFormatting(localeString, null);
    } catch (e) {
      print("Error initializing date formatting for $localeString: $e. Trying language code only.");
      try {
        await initializeDateFormatting(languageCode, null);
      } catch (e2) {
        print("Error initializing date formatting for $languageCode: $e2. Trying fallback 'en_US'.");
        try {
          await initializeDateFormatting('en_US', null);
        } catch (e3) {
          print("Could not initialize date formatting for any preferred locale or fallback: $e3");
        }
      }
    }
    _updateCurrentDateForDisplay();
  }

  void _showSnackBar(String messageKey, {bool isError = false, Map<String, String>? args}) {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(messageKey.tr(namedArgs: args ?? {})),
          backgroundColor: isError ? Colors.redAccent : Colors.green,
        ),
      );
    }
  }

  Future<void> _fetchPatientData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPatientData = true;
      _patientDataErrorKey = null;
    });
    final patientId = widget.userId;
    if (patientId.isEmpty) {
      if(mounted) setState(() {
        _isLoadingPatientData = false;
        _patientDataErrorKey = 'reportPage.errorMessages.patientDataError';
      });
      return;
    }
    try {
      DocumentSnapshot patientSnapshot = await _firestore.collection('users').doc(patientId).get();
      if (mounted) {
        final data = patientSnapshot.data();
        if (patientSnapshot.exists && data != null && data is Map<String, dynamic>) {
          setState(() {
            _patientData = data;
            _isLoadingPatientData = false;
          });
        } else {
          setState(() {
            _isLoadingPatientData = false;
            _patientDataErrorKey = 'reportPage.errorMessages.patientDataError';
          });
        }
      }
    } catch (e) {
      print('Error fetching patient data (ID: $patientId): $e');
      if (mounted) {
        setState(() {
          _isLoadingPatientData = false;
          _patientDataErrorKey = 'reportPage.errorMessages.patientDataError';
        });
        if (_patientDataErrorKey != null) _showSnackBar(_patientDataErrorKey!, isError: true);
      }
    }
  }

  Future<void> _fetchDaysWithAvailableSlots() async {
    if (!mounted) return;
    setState(() => _isLoadingAvailableDays = true);
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);
    final endDate = startDate.add(const Duration(days: 60));
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('available_slots')
          .where('status', isEqualTo: 'available')
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('dateTime', isLessThan: Timestamp.fromDate(endDate))
          .get();
      Set<DateTime> availableDays = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data != null && data is Map<String, dynamic>) {
          final timestamp = data['dateTime'] as Timestamp?;
          if (timestamp != null) {
            final date = timestamp.toDate();
            availableDays.add(DateTime.utc(date.year, date.month, date.day));
          }
        }
      }
      if (mounted) {
        setState(() {
          _daysWithAvailableSlots = availableDays;
          _isLoadingAvailableDays = false;
        });
      }
    } catch (e, stacktrace) {
      print("ERREUR fetch days: $e\n$stacktrace");
      if (mounted) setState(() => _isLoadingAvailableDays = false);
    }
  }

  Future<void> _fetchTimeSlotsForDay(DateTime selectedDay) async {
    if (!mounted) return;
    setState(() {
      _isLoadingTimeSlots = true;
      _availableTimeSlotsForSelectedDay = [];
      _bookingErrorKey = null;
      _bookingErrorArgs = null;
    });
    final startOfDay = Timestamp.fromDate(DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day));
    final endOfDay = Timestamp.fromDate(DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day, 23, 59, 59));
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('available_slots')
          .where('status', isEqualTo: 'available')
          .where('dateTime', isGreaterThanOrEqualTo: startOfDay)
          .where('dateTime', isLessThanOrEqualTo: endOfDay)
          .orderBy('dateTime')
          .get();
      final List<Map<String, dynamic>> slots = snapshot.docs
          .map((doc) {
        final data = doc.data();
        if (data != null && data is Map<String, dynamic> && data['dateTime'] is Timestamp) {
          final Map<String, dynamic> slotData = Map.from(data);
          slotData['id'] = doc.id;
          return slotData;
        }
        return null;
      })
          .where((item) => item != null)
          .cast<Map<String, dynamic>>()
          .toList();
      if (mounted) {
        setState(() {
          _availableTimeSlotsForSelectedDay = slots;
          _isLoadingTimeSlots = false;
        });
      }
    } catch (e, stacktrace) {
      print("ERREUR fetch slots: $e\n$stacktrace");
      if (mounted) setState(() {
        _isLoadingTimeSlots = false;
        _bookingErrorKey = "reportPage.errorMessages.noSlotsAvailable";
      });
      if (_bookingErrorKey != null) _showSnackBar(_bookingErrorKey!, isError: true);
    }
  }

  Future<void> _saveAppointmentBookedEventToHistory(String patientId, Timestamp appointmentTime, String doctorName) async {
    if (!mounted) return;
    try {
      final String formattedApptDate = DateFormat(
          'reportPage.dateFormat'.tr(),
          context.locale.languageCode
      ).format(appointmentTime.toDate());
      final historyEventData = {
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'appointment_booked',
        'details': 'Rendez-vous réservé pour le $formattedApptDate avec $doctorName',
        'actorId': patientId,
        'actorRole': 'Patient',
        'appointmentTime': appointmentTime,
        'doctorName': doctorName,
      };
      await _firestore.collection('users').doc(patientId).collection('history').add(historyEventData);
    } catch (e) {
      print('Error saving appointment_booked event to history: $e');
    }
  }

  Future<void> _bookAppointment(String slotId, Timestamp appointmentDateTime) async {
    if (!mounted) return;
    if (_isLoadingPatientData || _patientData == null || _patientDataErrorKey != null) {
      _showSnackBar("reportPage.errorMessages.patientDataError", isError: true);
      return;
    }
    if (_isBooking || _bookingConfirmed) return;
    setState(() {
      _isBooking = true;
      _selectedTimeSlotId = slotId;
      _bookingErrorKey = null;
      _bookingErrorArgs = null;
    });
    final patientId = widget.userId;
    final String patientName = ('${_patientData?['name'] ?? ''} ${_patientData?['surname'] ?? ''}'.trim()).isEmpty
        ? 'Patient Inconnu'
        : '${_patientData?['name'] ?? ''} ${_patientData?['surname'] ?? ''}'.trim();
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != patientId) {
      if (mounted) {
        setState(() => _isBooking = false);
        _showSnackBar("reportPage.errorMessages.userNotConnected", isError: true);
      }
      return;
    }
    String doctorNameForHistory = 'Médecin';
    try {
      await _firestore.runTransaction((transaction) async {
        final slotRef = _firestore.collection('available_slots').doc(slotId);
        DocumentSnapshot slotSnapshot = await transaction.get(slotRef);
        if (!slotSnapshot.exists || (slotSnapshot.data() as Map?)?['status'] != 'available') {
          throw Exception("Créneau non disponible.");
        }
        doctorNameForHistory = slotSnapshot.get('doctorName') ?? 'Médecin';
        transaction.update(slotRef, {'status': 'booked', 'bookedByPatientId': patientId, 'bookedByPatientName': patientName});
        transaction.set(_firestore.collection('booked_appointments').doc(), {
          'slotId': slotId, 'patientId': patientId, 'patientName': patientName,
          'appointmentDateTime': appointmentDateTime, 'doctorId': slotSnapshot.get('doctorId') ?? 'N/A',
          'doctorName': doctorNameForHistory, 'status': 'booked',
          'bookingTimestamp': FieldValue.serverTimestamp(),
        });
      });
      await _saveAppointmentBookedEventToHistory(patientId, appointmentDateTime, doctorNameForHistory);
      if (mounted) {
        setState(() {
          _bookingConfirmed = true;
          _isBooking = false;
          _selectedTimeSlotId = null;
          _availableTimeSlotsForSelectedDay.removeWhere((slot) => slot['id'] == slotId);
          _fetchDaysWithAvailableSlots();
        });
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            final String formattedDialogDate = DateFormat('reportPage.dateFormat'.tr(), context.locale.languageCode).format(appointmentDateTime.toDate());
            return AlertDialog(
              title: Text('reportPage.dialogTitles.bookingConfirmed'.tr()),
              content: SingleChildScrollView( // <--- CORRECTION AlertDialog
                child: Text(
                  'reportPage.appointmentConfirmation'.tr(namedArgs: {
                    'date': formattedDialogDate,
                    'doctorName': doctorNameForHistory
                  }),
                  textAlign: TextAlign.center, // Optionnel pour l'arabe
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('reportPage.buttons.ok'.tr()),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            );
          },
        );
      }
    } catch (e, stacktrace) {
      print('ERREUR réservation: $e\n$stacktrace');
      if (mounted) {
        String errorKey;
        Map<String, String>? errorArgsValue;
        if (e.toString().contains("Créneau non disponible")) {
          errorKey = "reportPage.errorMessages.slotUnavailable";
          if(_selectedDay != null) _fetchTimeSlotsForDay(_selectedDay!);
        } else {
          errorKey = "reportPage.errorMessages.bookingError";
          errorArgsValue = {'error': e.toString().split(':').last.trim()};
        }
        setState(() {
          _isBooking = false;
          _selectedTimeSlotId = null;
          _bookingErrorKey = errorKey;
          _bookingErrorArgs = errorArgsValue;
        });
        if (_bookingErrorKey != null) _showSnackBar(_bookingErrorKey!, isError: true, args: _bookingErrorArgs);
      }
    } finally {
      if (mounted && _isBooking) {
        setState(() { _isBooking = false; _selectedTimeSlotId = null; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFD32F2F);
    final String calendarLocale = context.locale.languageCode == 'fr'
        ? 'fr_FR'
        : context.locale.toStringWithSeparator(separator: '_');

    if (_currentDateFormattedForDisplay.isEmpty && context.mounted) {
      _updateCurrentDateForDisplay();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('reportPage.appBarTitle'.tr(), style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ Color(0xFFF5F5F5), Color(0xFFEEEEEE), ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.medical_services, size: 50, color: primaryColor),
                        const SizedBox(height: 10),
                        Text('reportPage.mainTitle'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                      ],
                    ),
                  ),
                  const Divider(height: 30, color: Colors.grey),
                  Text('reportPage.patientInfo'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 15),
                  _isLoadingPatientData
                      ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 10), child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor)))
                      : _patientDataErrorKey != null
                      ? Center(child: Text(_patientDataErrorKey!.tr(), style: const TextStyle(color: Colors.red)))
                      : Column(
                    children: [
                      PatientInfoRow(
                        label: 'reportPage.labels.fullName'.tr(),
                        value: _patientData != null ? '${_patientData?['name'] ?? 'N/A'} ${_patientData?['surname'] ?? ''}'.trim() : 'N/A',
                        icon: Icons.person_outline,
                      ),
                      PatientInfoRow(
                        label: 'reportPage.labels.analysisDate'.tr(),
                        value: _currentDateFormattedForDisplay,
                        icon: Icons.calendar_today_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Divider(height: 1, color: Colors.grey),
                  const SizedBox(height: 25),
                  Text('reportPage.analysisResults'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _isSick ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _isSick ? const Color(0xFFEF9A9A) : const Color(0xFFA5D6A7)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                                _isSick ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                                color: _isSick ? primaryColor : const Color(0xFF2E7D32),
                                size: 30
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isSick ? 'reportPage.anomalyDetected'.tr() : 'reportPage.noAnomalyDetected'.tr(),
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: _isSick ? primaryColor : const Color(0xFF2E7D32)
                                ),
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          height: 10,
                          child: LinearProgressIndicator(
                            value: _probability / 100.0,
                            backgroundColor: Colors.grey[300],
                            color: _isSick ? Colors.redAccent : Colors.green,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('${'reportPage.labels.confidence'.tr()} ${_probability.toStringAsFixed(1)}%', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                        const SizedBox(height: 10),
                        Text(
                          '${'reportPage.labels.recommendation'.tr()} ${_isSick ? 'reportPage.recommendations.urgentConsultation'.tr() : 'reportPage.recommendations.annualCheckup'.tr()}',
                          style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (_isSick && !_bookingConfirmed) ...[
                    const Divider(height: 1, color: Colors.grey),
                    const SizedBox(height: 25),
                    Text('reportPage.appointmentSection'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 15),
                    if (_isLoadingAvailableDays)
                      const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: CircularProgressIndicator(color: primaryColor)))
                    else
                      TableCalendar(
                        locale: calendarLocale,
                        firstDay: DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day),
                        lastDay: DateTime.utc(DateTime.now().year, DateTime.now().month + 3, DateTime.now().day),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          if (!isSameDay(_selectedDay, selectedDay)) {
                            if (_daysWithAvailableSlots.contains(DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day))) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                                _availableTimeSlotsForSelectedDay = [];
                                _bookingErrorKey = null;
                                _bookingErrorArgs = null;
                              });
                              _fetchTimeSlotsForDay(selectedDay);
                            } else {
                              _showSnackBar("reportPage.errorMessages.noSlotsAvailableDate", isError: true);
                            }
                          }
                        },
                        onFormatChanged: (format) {
                          if (_calendarFormat != format) {
                            setState(() { _calendarFormat = format; });
                          }
                        },
                        onPageChanged: (focusedDay) { _focusedDay = focusedDay; },
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            final dayOnly = DateTime.utc(date.year, date.month, date.day);
                            if (_daysWithAvailableSlots.contains(dayOnly)) {
                              return Positioned( bottom: 1, child: Container( width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),),);
                            }
                            return null;
                          },
                        ),
                        calendarStyle: const CalendarStyle(
                          todayDecoration: BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
                          selectedDecoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                          outsideDaysVisible: false,
                          disabledTextStyle: TextStyle(color: Colors.grey),
                        ),
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (_selectedDay != null) ...[
                      Text("${'reportPage.timeSlotsFor'.tr()} ${DateFormat('EEEE dd MMMM', calendarLocale).format(_selectedDay!)}:",
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      if (_isLoadingTimeSlots)
                        const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor)))
                      else if (_availableTimeSlotsForSelectedDay.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text("reportPage.noTimeSlots".tr(), style: const TextStyle(color: Colors.grey)),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: _availableTimeSlotsForSelectedDay.map((slot) {
                            final Timestamp? slotTimestamp = slot['dateTime'] as Timestamp?;
                            final String slotId = slot['id'] ?? 'no-id';
                            if (slotTimestamp == null) return const SizedBox.shrink();
                            final DateTime slotDateTime = slotTimestamp.toDate();
                            final String formattedTime = DateFormat('HH:mm').format(slotDateTime);
                            final bool isCurrentlyBookingThisSlot = _isBooking && _selectedTimeSlotId == slotId;
                            return ElevatedButton(
                              onPressed: (_isBooking) ? null : () => _bookAppointment(slotId, slotTimestamp),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal[50],
                                foregroundColor: Colors.teal[800],
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 1,
                                disabledBackgroundColor: Colors.grey[300],
                              ),
                              child: isCurrentlyBookingThisSlot
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor))
                                  : Text(formattedTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                            );
                          }).toList(),
                        ),
                      if (_bookingErrorKey != null && !_isLoadingTimeSlots)
                        Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Center(child: Text(_bookingErrorKey!.tr(namedArgs: _bookingErrorArgs ?? {}), style: const TextStyle(color: Colors.red))),
                        ),
                    ],
                    const SizedBox(height: 30),
                  ],
                  if (_bookingConfirmed) ...[ // ***** CORRECTION OVERFLOW Booking Confirmed Text *****
                    const Divider(height: 1, color: Colors.grey),
                    const SizedBox(height: 25),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 26),
                          const SizedBox(width: 10),
                          Expanded( // <--- AJOUTÉ ICI
                            child: Text(
                              'reportPage.bookingConfirmedText'.tr(),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                              textAlign: TextAlign.center, // Optionnel
                              softWrap: true,
                            ),
                          ), // <--- FIN DE EXPANDED
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ], // ***** FIN CORRECTION OVERFLOW *****
                  const Divider(height: 1, color: Colors.grey),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                          label: Text('reportPage.backButton'.tr()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[400]!),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PatientInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const PatientInfoRow({
    Key? key,
    required this.label,
    required this.value,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Text('$label ', style: TextStyle(fontSize: 14, color: Colors.grey[800])),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}