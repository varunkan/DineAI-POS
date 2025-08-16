import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../services/order_service.dart';

import '../screens/edit_active_order_screen.dart';

class ServerOrdersScreen extends StatefulWidget {
  final User server;

  const ServerOrdersScreen({Key? key, required this.server}) : super(key: key);

  @override
  State<ServerOrdersScreen> createState() => _ServerOrdersScreenState();
}

class _ServerOrdersScreenState extends State<ServerOrdersScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue.shade700;
      case OrderStatus.preparing:
        return Colors.blue;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.served:
        return Colors.green.shade700;
      case OrderStatus.completed:
        return Colors.grey;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.refunded:
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'PENDING';
      case OrderStatus.confirmed:
        return 'CONFIRMED';
      case OrderStatus.preparing:
        return 'PREPARING';
      case OrderStatus.ready:
        return 'READY';
      case OrderStatus.served:
        return 'SERVED';
      case OrderStatus.completed:
        return 'COMPLETED';
      case OrderStatus.cancelled:
        return 'CANCELLED';
      case OrderStatus.refunded:
        return 'REFUNDED';
      default:
        return 'UNKNOWN';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLargeScreen = screenSize.width > 1200;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildHeader(context, isLargeScreen),
                ),
              ),
              
              // Orders List
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildOrdersList(context, isLargeScreen),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isLargeScreen) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Icon(
                Icons.arrow_back_ios,
                color: Colors.blue.shade700,
                size: 24,
              ),
            ),
          ),
          
          const SizedBox(width: 20),
          
          // Server Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: Text(
                widget.server.name[0].toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isLargeScreen ? 28 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 20),
          
          // Server Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.server.name}\'s Orders',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 32 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage all orders created by this server',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 16 : 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(BuildContext context, bool isLargeScreen) {
    return Consumer<OrderService>(
      builder: (context, orderService, child) {
        final serverOrders = orderService.getActiveOrdersByServer(widget.server.id);
        
        if (serverOrders.isEmpty) {
          return _buildEmptyState(isLargeScreen);
        }
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isLargeScreen ? 3 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isLargeScreen ? 1.3 : 1.2,
            ),
            itemCount: serverOrders.length,
            itemBuilder: (context, index) {
              final order = serverOrders[index];
              return _buildOrderTile(context, order, isLargeScreen, index);
            },
          ),
        );
      },
    );
  }

  Widget _buildOrderTile(BuildContext context, Order order, bool isLargeScreen, int index) {
    final isActive = order.status == OrderStatus.pending || 
                     order.status == OrderStatus.confirmed ||
                     order.status == OrderStatus.preparing;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * _animationController.value),
          child: Opacity(
            opacity: _animationController.value,
            child: GestureDetector(
              onTap: () {
                debugPrint('🔍 ORDER TILE CLICKED: ${order.orderNumber}, status: ${order.status}, isActive: $isActive');
                if (isActive) {
                  debugPrint('✅ Navigating to EditActiveOrderScreen for order ${order.orderNumber}');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditActiveOrderScreen(
                        order: order,
                        user: widget.server,
                      ),
                    ),
                  );
                } else {
                  debugPrint('⚠️ Order ${order.orderNumber} is not active (status: ${order.status}), cannot edit');
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: isActive ? Colors.blue.shade200 : Colors.grey.shade200,
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    // Background Gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isActive 
                              ? [Colors.blue.shade50, Colors.white]
                              : [Colors.grey.shade50, Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Order Header
                          Row(
                            children: [
                              // Order Number
                              Expanded(
                                child: Text(
                                  order.orderNumber,
                                  style: TextStyle(
                                    fontSize: isLargeScreen ? 22 : 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                              
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(order.status),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getStatusText(order.status),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isLargeScreen ? 12 : 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Order Type
                          Row(
                            children: [
                              Icon(
                                order.type == 'dineIn' 
                                    ? Icons.restaurant 
                                    : Icons.takeout_dining,
                                color: Colors.blue.shade600,
                                size: isLargeScreen ? 24 : 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                order.type == 'dineIn' ? 'DINE IN' : 'TAKEOUT',
                                style: TextStyle(
                                  fontSize: isLargeScreen ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Order Details
                          Text(
                            '${order.items.length} items',
                            style: TextStyle(
                              fontSize: isLargeScreen ? 14 : 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Total Amount
                          Text(
                            '\$${order.totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: isLargeScreen ? 20 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade600,
                            ),
                          ),
                          
                          const Spacer(),
                          
                          // Action Button
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: isActive 
                                  ? const LinearGradient(
                                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : LinearGradient(
                                      colors: [Colors.grey.shade300, Colors.grey.shade400],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isActive ? Icons.edit : Icons.check_circle,
                                    color: isActive ? Colors.white : Colors.grey.shade600,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isActive ? 'EDIT ORDER' : 'ORDER COMPLETE',
                                    style: TextStyle(
                                      color: isActive ? Colors.white : Colors.grey.shade600,
                                      fontSize: isLargeScreen ? 14 : 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Time Created
                          const SizedBox(height: 8),
                          Text(
                            'Created: ${_formatDateTime(order.createdAt)}',
                            style: TextStyle(
                              fontSize: isLargeScreen ? 11 : 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isLargeScreen) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long,
              size: isLargeScreen ? 80 : 60,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'No Orders Yet',
              style: TextStyle(
                fontSize: isLargeScreen ? 28 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.server.name} hasn\'t created any orders yet.',
              style: TextStyle(
                fontSize: isLargeScreen ? 16 : 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
} 