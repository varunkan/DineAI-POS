import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_pos_system/models/reservation.dart';
import 'package:ai_pos_system/services/reservation_service.dart';
import 'package:ai_pos_system/services/table_service.dart';

import '../widgets/back_button.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  List<Reservation> _dateReservations = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDateReservations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDateReservations() async {
    setState(() => _isLoading = true);
    final reservationService = Provider.of<ReservationService>(context, listen: false);
    final reservations = await reservationService.getReservationsForDate(_selectedDate);
    setState(() {
      _dateReservations = reservations;
      _isLoading = false;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadDateReservations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Table Reservations',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: const CustomBackButton(),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Today\'s Bookings'),
            Tab(text: 'All Reservations'),
            Tab(text: 'Calendar View'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _showCreateReservationDialog(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodaysBookings(),
          _buildAllReservations(),
          _buildCalendarView(),
        ],
      ),
    );
  }

  Widget _buildTodaysBookings() {
    return Consumer<ReservationService>(
      builder: (context, reservationService, child) {
        final todaysReservations = reservationService.todaysReservations;
        
        if (reservationService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (todaysReservations.isEmpty) {
          return _buildEmptyState('No reservations for today');
        }

        return RefreshIndicator(
          onRefresh: reservationService.loadReservations,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: todaysReservations.length,
            itemBuilder: (context, index) {
              final reservation = todaysReservations[index];
              return _buildReservationCard(reservation);
            },
          ),
        );
      },
    );
  }

  Widget _buildAllReservations() {
    return Consumer<ReservationService>(
      builder: (context, reservationService, child) {
        final reservations = reservationService.reservations;
        
        if (reservationService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (reservations.isEmpty) {
          return _buildEmptyState('No reservations found');
        }

        return RefreshIndicator(
          onRefresh: reservationService.loadReservations,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reservations.length,
            itemBuilder: (context, index) {
              final reservation = reservations[index];
              return _buildReservationCard(reservation);
            },
          ),
        );
      },
    );
  }

  Widget _buildCalendarView() {
    return Column(
      children: [
        // Date selector
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF2A2A2A),
          child: InkWell(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedDate.day == DateTime.now().day &&
                            _selectedDate.month == DateTime.now().month &&
                            _selectedDate.year == DateTime.now().year
                        ? 'Today'
                        : '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const Icon(Icons.calendar_today, color: Colors.orange),
                ],
              ),
            ),
          ),
        ),
        // Reservations for selected date
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _dateReservations.isEmpty
                  ? _buildEmptyState('No reservations for selected date')
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _dateReservations.length,
                      itemBuilder: (context, index) {
                        final reservation = _dateReservations[index];
                        return _buildReservationCard(reservation);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildReservationCard(Reservation reservation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    reservation.customerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: reservation.status.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    reservation.status.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Reservation details
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${reservation.formattedDate} at ${reservation.formattedTime}',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            Row(
              children: [
                const Icon(Icons.people, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Party of ${reservation.partySize}',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                if (reservation.tableId != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.table_restaurant, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Table assigned',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ],
            ),
            
            if (reservation.customerPhone != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    reservation.customerPhone!,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ],
            
            if (reservation.specialRequests != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.note, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reservation.specialRequests!,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (reservation.status == ReservationStatus.pending)
                  _buildActionButton(
                    'Confirm',
                    Colors.green,
                    () => _updateReservationStatus(reservation.id, ReservationStatus.confirmed),
                  ),
                if (reservation.status == ReservationStatus.confirmed)
                  _buildActionButton(
                    'Arrived',
                    Colors.blue,
                    () => _updateReservationStatus(reservation.id, ReservationStatus.arrived),
                  ),
                if (reservation.status == ReservationStatus.arrived)
                  _buildActionButton(
                    'Seated',
                    Colors.purple,
                    () => _updateReservationStatus(reservation.id, ReservationStatus.seated),
                  ),
                const SizedBox(width: 8),
                _buildActionButton(
                  'Edit',
                  Colors.orange,
                  () => _showEditReservationDialog(reservation),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  'Cancel',
                  Colors.red,
                  () => _cancelReservation(reservation),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(60, 32),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.event_busy,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showCreateReservationDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text(
              'Create Reservation',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateReservationDialog() async {
    await showDialog(
      context: context,
      builder: (context) => const CreateReservationDialog(),
    );
    await _loadDateReservations();
  }

  Future<void> _showEditReservationDialog(Reservation reservation) async {
    await showDialog(
      context: context,
      builder: (context) => EditReservationDialog(reservation: reservation),
    );
    await _loadDateReservations();
  }

  Future<void> _updateReservationStatus(String reservationId, ReservationStatus newStatus) async {
    final reservationService = Provider.of<ReservationService>(context, listen: false);
    final success = await reservationService.updateReservationStatus(reservationId, newStatus);
    
    if (success) {
      await _loadDateReservations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reservation status updated to ${newStatus.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update reservation status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelReservation(Reservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Cancel Reservation', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to cancel the reservation for ${reservation.customerName}?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateReservationStatus(reservation.id, ReservationStatus.cancelled);
    }
  }
}

class CreateReservationDialog extends StatefulWidget {
  const CreateReservationDialog({super.key});

  @override
  State<CreateReservationDialog> createState() => _CreateReservationDialogState();
}

class _CreateReservationDialogState extends State<CreateReservationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _specialRequestsController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);
  int _partySize = 2;
  String? _selectedTableId;
  bool _isLoading = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _specialRequestsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      title: const Text(
        'Create Reservation',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Customer Name
                TextFormField(
                  controller: _customerNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Customer Name',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter customer name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Customer Phone
                TextFormField(
                  controller: _customerPhoneController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Customer Phone',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Customer Email
                TextFormField(
                  controller: _customerEmailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Customer Email',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Date and Time Row
                Row(
                  children: [
                    // Date selector
                    Expanded(
                      child: InkWell(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text(
                                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Time selector
                    Expanded(
                      child: InkWell(
                        onTap: _selectTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text(
                                _selectedTime.format(context),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Party Size
                Row(
                  children: [
                    const Text('Party Size:', style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _partySize,
                        dropdownColor: const Color(0xFF2A2A2A),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.orange),
                          ),
                        ),
                        items: List.generate(20, (index) => index + 1)
                            .map((size) => DropdownMenuItem(
                                  value: size,
                                  child: Text('$size people'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() => _partySize = value!);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Table Selection
                Consumer<TableService>(
                  builder: (context, tableService, child) {
                    return DropdownButtonFormField<String>(
                      value: _selectedTableId,
                      dropdownColor: const Color(0xFF2A2A2A),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Assign Table (Optional)',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.orange),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('No table assigned'),
                        ),
                        ...tableService.tables.map((table) => DropdownMenuItem(
                              value: table.id,
                              child: Text('Table ${table.number} (${table.capacity} seats)'),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedTableId = value);
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                
                // Special Requests
                TextFormField(
                  controller: _specialRequestsController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Special Requests',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createReservation,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Create', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _createReservation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final reservationService = Provider.of<ReservationService>(context, listen: false);

    final reservation = Reservation(
      customerName: _customerNameController.text,
      customerPhone: _customerPhoneController.text.isEmpty ? null : _customerPhoneController.text,
      customerEmail: _customerEmailController.text.isEmpty ? null : _customerEmailController.text,
      reservationDate: _selectedDate,
      reservationTime: _selectedTime,
      partySize: _partySize,
      tableId: _selectedTableId,
      specialRequests: _specialRequestsController.text.isEmpty ? null : _specialRequestsController.text,
      createdBy: 'admin', // TODO: Use actual current user
    );

    final success = await reservationService.createReservation(reservation);

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create reservation. Time slot may be unavailable.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class EditReservationDialog extends StatefulWidget {
  final Reservation reservation;

  const EditReservationDialog({super.key, required this.reservation});

  @override
  State<EditReservationDialog> createState() => _EditReservationDialogState();
}

class _EditReservationDialogState extends State<EditReservationDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _customerNameController;
  late TextEditingController _customerPhoneController;
  late TextEditingController _customerEmailController;
  late TextEditingController _specialRequestsController;
  late TextEditingController _notesController;
  
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late int _partySize;
  String? _selectedTableId;
  late ReservationStatus _selectedStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final reservation = widget.reservation;
    _customerNameController = TextEditingController(text: reservation.customerName);
    _customerPhoneController = TextEditingController(text: reservation.customerPhone ?? '');
    _customerEmailController = TextEditingController(text: reservation.customerEmail ?? '');
    _specialRequestsController = TextEditingController(text: reservation.specialRequests ?? '');
    _notesController = TextEditingController(text: reservation.notes ?? '');
    _selectedDate = reservation.reservationDate;
    _selectedTime = reservation.reservationTime;
    _partySize = reservation.partySize;
    _selectedTableId = reservation.tableId;
    _selectedStatus = reservation.status;
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _specialRequestsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      title: const Text(
        'Edit Reservation',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Customer Name
                TextFormField(
                  controller: _customerNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Customer Name',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter customer name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Status
                DropdownButtonFormField<ReservationStatus>(
                  value: _selectedStatus,
                  dropdownColor: const Color(0xFF2A2A2A),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  items: ReservationStatus.values.map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.displayName),
                      )).toList(),
                  onChanged: (value) {
                    setState(() => _selectedStatus = value!);
                  },
                ),
                const SizedBox(height: 16),
                
                // Customer Phone
                TextFormField(
                  controller: _customerPhoneController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Customer Phone',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Date and Time Row
                Row(
                  children: [
                    // Date selector
                    Expanded(
                      child: InkWell(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text(
                                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Time selector
                    Expanded(
                      child: InkWell(
                        onTap: _selectTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text(
                                _selectedTime.format(context),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Party Size
                Row(
                  children: [
                    const Text('Party Size:', style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _partySize,
                        dropdownColor: const Color(0xFF2A2A2A),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.orange),
                          ),
                        ),
                        items: List.generate(20, (index) => index + 1)
                            .map((size) => DropdownMenuItem(
                                  value: size,
                                  child: Text('$size people'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() => _partySize = value!);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Table Selection
                Consumer<TableService>(
                  builder: (context, tableService, child) {
                    return DropdownButtonFormField<String>(
                      value: _selectedTableId,
                      dropdownColor: const Color(0xFF2A2A2A),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Assign Table (Optional)',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.orange),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('No table assigned'),
                        ),
                        ...tableService.tables.map((table) => DropdownMenuItem(
                              value: table.id,
                              child: Text('Table ${table.number} (${table.capacity} seats)'),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedTableId = value);
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                
                // Special Requests
                TextFormField(
                  controller: _specialRequestsController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Special Requests',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Notes
                TextFormField(
                  controller: _notesController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Internal Notes',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateReservation,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Update', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _updateReservation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final reservationService = Provider.of<ReservationService>(context, listen: false);

    final updatedReservation = widget.reservation.copyWith(
      customerName: _customerNameController.text,
      customerPhone: _customerPhoneController.text.isEmpty ? null : _customerPhoneController.text,
      customerEmail: _customerEmailController.text.isEmpty ? null : _customerEmailController.text,
      reservationDate: _selectedDate,
      reservationTime: _selectedTime,
      partySize: _partySize,
      tableId: _selectedTableId,
      status: _selectedStatus,
      specialRequests: _specialRequestsController.text.isEmpty ? null : _specialRequestsController.text,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    final success = await reservationService.updateReservation(updatedReservation);

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update reservation. Time slot may be unavailable.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 