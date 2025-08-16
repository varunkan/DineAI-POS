import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reservation.dart';
import '../services/reservation_service.dart';
import '../widgets/back_button.dart';

class DailyBookingsScreen extends StatefulWidget {
  const DailyBookingsScreen({super.key});

  @override
  State<DailyBookingsScreen> createState() => _DailyBookingsScreenState();
}

class _DailyBookingsScreenState extends State<DailyBookingsScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Reservation> _dateReservations = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDateReservations();
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
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadDateReservations();
    }
  }

  String get _formattedDate {
    final now = DateTime.now();
    if (_selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day) {
      return 'Today';
    }
    
    final tomorrow = now.add(const Duration(days: 1));
    if (_selectedDate.year == tomorrow.year &&
        _selectedDate.month == tomorrow.month &&
        _selectedDate.day == tomorrow.day) {
      return 'Tomorrow';
    }
    
    final yesterday = now.subtract(const Duration(days: 1));
    if (_selectedDate.year == yesterday.year &&
        _selectedDate.month == yesterday.month &&
        _selectedDate.day == yesterday.day) {
      return 'Yesterday';
    }
    
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    final upcomingReservations = _dateReservations.where((r) => 
      r.status != ReservationStatus.cancelled && 
      r.status != ReservationStatus.noShow
    ).toList();
    
    final completedReservations = _dateReservations.where((r) => 
      r.status == ReservationStatus.completed ||
      r.status == ReservationStatus.cancelled ||
      r.status == ReservationStatus.noShow
    ).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(
          'Bookings - $_formattedDate',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: const CustomBackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _selectDate,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDateReservations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dateReservations.isEmpty
              ? _buildEmptyState()
              : Column(
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
                                _formattedDate,
                                style: const TextStyle(color: Colors.white, fontSize: 18),
                              ),
                              const Icon(Icons.calendar_today, color: Colors.orange),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Summary cards
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Total Bookings',
                              _dateReservations.length.toString(),
                              Colors.blue,
                              Icons.event,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'Upcoming',
                              upcomingReservations.length.toString(),
                              Colors.green,
                              Icons.schedule,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'Completed',
                              completedReservations.length.toString(),
                              Colors.grey,
                              Icons.check_circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Reservations list
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadDateReservations,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _dateReservations.length,
                          itemBuilder: (context, index) {
                            final reservation = _dateReservations[index];
                            return _buildReservationCard(reservation);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReservationCard(Reservation reservation) {
    final isUpcoming = reservation.status != ReservationStatus.completed &&
                      reservation.status != ReservationStatus.cancelled &&
                      reservation.status != ReservationStatus.noShow;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status and time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reservation.customerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reservation.formattedTime,
                        style: TextStyle(
                          color: isUpcoming ? Colors.orange : Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                Icon(
                  Icons.people,
                  color: Colors.orange,
                  size: 16,
                ),
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
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: () {
                      // TODO: Implement call functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Call functionality would be implemented here')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Call',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            
            if (reservation.specialRequests != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.note, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reservation.specialRequests!,
                        style: const TextStyle(color: Colors.orange, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (reservation.notes != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sticky_note_2, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Staff Note: ${reservation.notes!}',
                        style: const TextStyle(color: Colors.blue, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Action buttons for upcoming reservations
            if (isUpcoming) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (reservation.status == ReservationStatus.pending) ...[
                    _buildQuickActionButton(
                      'Confirm',
                      Colors.green,
                      () => _updateReservationStatus(reservation.id, ReservationStatus.confirmed),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (reservation.status == ReservationStatus.confirmed) ...[
                    _buildQuickActionButton(
                      'Arrived',
                      Colors.blue,
                      () => _updateReservationStatus(reservation.id, ReservationStatus.arrived),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (reservation.status == ReservationStatus.arrived) ...[
                    _buildQuickActionButton(
                      'Seated',
                      Colors.purple,
                      () => _updateReservationStatus(reservation.id, ReservationStatus.seated),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (reservation.status == ReservationStatus.seated) ...[
                    _buildQuickActionButton(
                      'Complete',
                      Colors.teal,
                      () => _updateReservationStatus(reservation.id, ReservationStatus.completed),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _buildQuickActionButton(
                    'No Show',
                    Colors.red,
                    () => _updateReservationStatus(reservation.id, ReservationStatus.noShow),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(String text, Color color, VoidCallback onPressed) {
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

  Widget _buildEmptyState() {
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
            'No reservations for $_formattedDate',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Reservations will appear here when customers book tables.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
} 