import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:ai_pos_system/services/database_service.dart';


/// Advanced analytics service with AI-powered insights
class AnalyticsService extends ChangeNotifier {
  final DatabaseService _databaseService;
  
  // Cached analytics data
  Map<String, dynamic>? _cachedDashboardData;
  DateTime? _lastCacheUpdate;
  static const Duration _cacheValidDuration = Duration(minutes: 15);
  
  // AI insights cache
  Map<String, dynamic>? _aiInsights;
  DateTime? _lastAiUpdate;
  static const Duration _aiUpdateInterval = Duration(hours: 1);

  AnalyticsService(this._databaseService);

  /// Get comprehensive dashboard analytics
  Future<Map<String, dynamic>> getDashboardAnalytics({
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    // Check cache first
    if (!forceRefresh && _cachedDashboardData != null && _lastCacheUpdate != null) {
      if (DateTime.now().difference(_lastCacheUpdate!) < _cacheValidDuration) {
        return _cachedDashboardData!;
      }
    }

    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();

    try {
      // Get basic analytics from optimized query
      final basicAnalytics = await _databaseService.getAnalyticsData(
        startDate: start,
        endDate: end,
      );

      // Get popular items
      final popularItems = await _databaseService.getPopularMenuItems(limit: 10);

      // Get time-based analytics
      final hourlyData = await _getHourlyAnalytics(start, end);
      final dailyData = await _getDailyAnalytics(start, end);

      // Get performance metrics
      final performanceMetrics = await _getPerformanceMetrics(start, end);

      // Get customer insights
      final customerInsights = await _getCustomerInsights(start, end);

      // Get financial analytics
      final financialAnalytics = await _getFinancialAnalytics(start, end);

      // Get operational insights
      final operationalInsights = await _getOperationalInsights(start, end);

      final dashboardData = {
        'basic_analytics': basicAnalytics,
        'popular_items': popularItems,
        'hourly_data': hourlyData,
        'daily_data': dailyData,
        'performance_metrics': performanceMetrics,
        'customer_insights': customerInsights,
        'financial_analytics': financialAnalytics,
        'operational_insights': operationalInsights,
        'generated_at': DateTime.now().toIso8601String(),
        'period': {
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
        },
      };

      // Cache the results
      _cachedDashboardData = dashboardData;
      _lastCacheUpdate = DateTime.now();

      return dashboardData;

    } catch (e) {
      debugPrint('Error generating dashboard analytics: $e');
      rethrow;
    }
  }

  /// Get AI-powered insights and recommendations
  Future<Map<String, dynamic>> getAIInsights({bool forceRefresh = false}) async {
    // Check cache first
    if (!forceRefresh && _aiInsights != null && _lastAiUpdate != null) {
      if (DateTime.now().difference(_lastAiUpdate!) < _aiUpdateInterval) {
        return _aiInsights!;
      }
    }

    try {
      final dashboardData = await getDashboardAnalytics();
      
      final insights = {
        'revenue_optimization': await _generateRevenueOptimizationInsights(dashboardData),
        'menu_optimization': await _generateMenuOptimizationInsights(dashboardData),
        'operational_efficiency': await _generateOperationalEfficiencyInsights(dashboardData),
        'customer_experience': await _generateCustomerExperienceInsights(dashboardData),
        'predictive_analytics': await _generatePredictiveAnalytics(dashboardData),
        'recommendations': await _generateActionableRecommendations(dashboardData),
        'generated_at': DateTime.now().toIso8601String(),
      };

      _aiInsights = insights;
      _lastAiUpdate = DateTime.now();

      return insights;

    } catch (e) {
      debugPrint('Error generating AI insights: $e');
      rethrow;
    }
  }

  /// Get hourly analytics for peak time analysis
  Future<List<Map<String, dynamic>>> _getHourlyAnalytics(DateTime start, DateTime end) async {
    final db = await _databaseService.database;
    if (db == null) return [];
    
    final result = await db.rawQuery('''
      SELECT 
        CAST(strftime('%H', order_time) AS INTEGER) as hour,
        COUNT(*) as order_count,
        SUM(total_amount) as revenue,
        AVG(total_amount) as avg_order_value,
        COUNT(CASE WHEN type = 'dineIn' THEN 1 END) as dine_in_count,
        COUNT(CASE WHEN type = 'takeaway' THEN 1 END) as takeaway_count,
        COUNT(CASE WHEN type = 'delivery' THEN 1 END) as delivery_count
      FROM orders 
      WHERE created_at BETWEEN ? AND ? AND status = 'completed'
      GROUP BY hour
      ORDER BY hour
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return result;
  }

  /// Get daily analytics for trend analysis
  Future<List<Map<String, dynamic>>> _getDailyAnalytics(DateTime start, DateTime end) async {
    final db = await _databaseService.database;
    if (db == null) return [];
    
    final result = await db.rawQuery('''
      SELECT 
        DATE(order_time) as date,
        COUNT(*) as order_count,
        SUM(total_amount) as revenue,
        AVG(total_amount) as avg_order_value,
        COUNT(DISTINCT customer_phone) as unique_customers,
        COUNT(CASE WHEN is_urgent = 1 THEN 1 END) as urgent_orders
      FROM orders 
      WHERE created_at BETWEEN ? AND ? AND status = 'completed'
      GROUP BY DATE(order_time)
      ORDER BY date
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return result;
  }

  /// Get performance metrics
  Future<Map<String, dynamic>> _getPerformanceMetrics(DateTime start, DateTime end) async {
    final db = await _databaseService.database;
    if (db == null) return {};
    
    // Kitchen performance
    final kitchenPerformance = await db.rawQuery('''
      SELECT 
        AVG(CASE 
          WHEN actual_ready_time IS NOT NULL AND estimated_ready_time IS NOT NULL 
          THEN (julianday(actual_ready_time) - julianday(estimated_ready_time)) * 24 * 60 
        END) as avg_delay_minutes,
        COUNT(CASE 
          WHEN actual_ready_time IS NOT NULL AND estimated_ready_time IS NOT NULL 
          AND actual_ready_time <= estimated_ready_time THEN 1 
        END) as on_time_orders,
        COUNT(CASE 
          WHEN actual_ready_time IS NOT NULL AND estimated_ready_time IS NOT NULL 
        END) as total_timed_orders
      FROM orders 
      WHERE created_at BETWEEN ? AND ? AND status = 'completed'
    ''', [start.toIso8601String(), end.toIso8601String()]);

    // Server performance
    final serverPerformance = await db.rawQuery('''
      SELECT 
        user_id,
        COUNT(*) as orders_handled,
        SUM(total_amount) as revenue_generated,
        AVG(total_amount) as avg_order_value
      FROM orders 
      WHERE created_at BETWEEN ? AND ? AND status = 'completed' AND user_id IS NOT NULL
      GROUP BY user_id
      ORDER BY revenue_generated DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return {
      'kitchen_performance': kitchenPerformance.isNotEmpty ? kitchenPerformance.first : {},
      'server_performance': serverPerformance,
    };
  }

  /// Get customer insights
  Future<Map<String, dynamic>> _getCustomerInsights(DateTime start, DateTime end) async {
    final db = await _databaseService.database;
    if (db == null) return {};
    
    // Customer frequency analysis
    final customerFrequency = await db.rawQuery('''
      SELECT 
        customer_phone,
        customer_name,
        COUNT(*) as visit_count,
        SUM(total_amount) as total_spent,
        AVG(total_amount) as avg_order_value,
        MAX(order_time) as last_visit
      FROM orders 
      WHERE created_at BETWEEN ? AND ? AND status = 'completed' 
      AND customer_phone IS NOT NULL
      GROUP BY customer_phone
      HAVING visit_count > 1
      ORDER BY total_spent DESC
      LIMIT 20
    ''', [start.toIso8601String(), end.toIso8601String()]);

    // Order type preferences
    const orderTypeQuery = '''
      SELECT 
        type,
        COUNT(*) as count,
        SUM(total_amount) as revenue,
        AVG(total_amount) as avg_value
      FROM orders 
      WHERE created_at BETWEEN ? AND ? AND status = 'completed'
      GROUP BY type
    ''';
    
    final orderTypeData = await db.rawQuery(orderTypeQuery, [start.toIso8601String(), end.toIso8601String()]);

    return {
      'loyal_customers': customerFrequency,
      'order_type_preferences': orderTypeData,
    };
  }

  /// Get financial analytics
  Future<Map<String, dynamic>> _getFinancialAnalytics(DateTime start, DateTime end) async {
    final db = await _databaseService.database;
    if (db == null) return {};
    
    // Payment method analysis
    final paymentMethods = await db.rawQuery('''
      SELECT 
        payment_method,
        COUNT(*) as transaction_count,
        SUM(total_amount) as total_amount,
        AVG(total_amount) as avg_transaction
      FROM orders 
      WHERE created_at BETWEEN ? AND ? AND status = 'completed'
      AND payment_method IS NOT NULL
      GROUP BY payment_method
    ''', [start.toIso8601String(), end.toIso8601String()]);

    // Revenue breakdown
    final revenueBreakdown = await db.rawQuery('''
      SELECT 
        SUM(subtotal) as gross_revenue,
        SUM(tax_amount) as total_tax,
        SUM(tip_amount) as total_tips,
        SUM(discount_amount) as total_discounts,
        SUM(gratuity_amount) as total_gratuity,
        COUNT(*) as total_transactions
      FROM orders 
      WHERE created_at BETWEEN ? AND ? AND status = 'completed'
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return {
      'payment_methods': paymentMethods,
      'revenue_breakdown': revenueBreakdown.isNotEmpty ? revenueBreakdown.first : {},
    };
  }

  /// Get operational insights
  Future<Map<String, dynamic>> _getOperationalInsights(DateTime start, DateTime end) async {
    final db = await _databaseService.database;
    if (db == null) return {};
    
    // Table utilization
    final tableUtilization = await db.rawQuery('''
      SELECT 
        table_id,
        COUNT(*) as usage_count,
        SUM(total_amount) as revenue,
        AVG(total_amount) as avg_order_value
      FROM orders 
      WHERE created_at BETWEEN ? AND ? AND status = 'completed'
      AND table_id IS NOT NULL
      GROUP BY table_id
      ORDER BY revenue DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    // Order timing analysis
    final orderTiming = await db.rawQuery('''
      SELECT 
        AVG(CASE 
          WHEN completed_time IS NOT NULL 
          THEN (julianday(completed_time) - julianday(order_time)) * 24 * 60 
        END) as avg_completion_time_minutes,
        MIN(CASE 
          WHEN completed_time IS NOT NULL 
          THEN (julianday(completed_time) - julianday(order_time)) * 24 * 60 
        END) as min_completion_time,
        MAX(CASE 
          WHEN completed_time IS NOT NULL 
          THEN (julianday(completed_time) - julianday(order_time)) * 24 * 60 
        END) as max_completion_time
      FROM orders 
      WHERE created_at BETWEEN ? AND ? AND status = 'completed'
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return {
      'table_utilization': tableUtilization,
      'order_timing': orderTiming.isNotEmpty ? orderTiming.first : {},
    };
  }

  /// Generate revenue optimization insights
  Future<Map<String, dynamic>> _generateRevenueOptimizationInsights(Map<String, dynamic> data) async {
    final insights = <String, dynamic>{};
    
    try {
      final basicAnalytics = data['basic_analytics'] as Map<String, dynamic>;
      final popularItems = data['popular_items'] as List<dynamic>;
      final hourlyData = data['hourly_data'] as List<dynamic>;
      
      // Peak hours analysis
      if (hourlyData.isNotEmpty) {
        final sortedByRevenue = List<Map<String, dynamic>>.from(hourlyData)
          ..sort((a, b) => (b['revenue'] ?? 0).compareTo(a['revenue'] ?? 0));
        
        insights['peak_revenue_hours'] = sortedByRevenue.take(3).toList();
        insights['low_revenue_hours'] = sortedByRevenue.reversed.take(3).toList();
      }
      
      // Menu pricing optimization
      if (popularItems.isNotEmpty) {
        final highMarginItems = popularItems.where((item) {
          final revenue = item['total_revenue'] ?? 0;
          final orderCount = item['order_count'] ?? 1;
          return (revenue / orderCount) > 15; // Items with high average value
        }).toList();
        
        insights['high_margin_opportunities'] = highMarginItems;
      }
      
      // Revenue growth potential
      final avgOrderValue = basicAnalytics['avg_order_value'] ?? 0;
      insights['revenue_potential'] = {
        'current_aov': avgOrderValue,
        'target_aov': avgOrderValue * 1.15, // 15% increase target
        'potential_increase': avgOrderValue * 0.15,
      };
      
    } catch (e) {
      debugPrint('Error generating revenue optimization insights: $e');
    }
    
    return insights;
  }

  /// Generate menu optimization insights
  Future<Map<String, dynamic>> _generateMenuOptimizationInsights(Map<String, dynamic> data) async {
    final insights = <String, dynamic>{};
    
    try {
      final popularItems = data['popular_items'] as List<dynamic>;
      
      if (popularItems.isNotEmpty) {
        // Identify star performers
        final starPerformers = popularItems.take(5).toList();
        
        // Identify underperformers (need promotion or removal)
        final underPerformers = popularItems.where((item) {
          final orderCount = item['order_count'] ?? 0;
          return orderCount < 5; // Less than 5 orders in the period
        }).toList();
        
        // Suggest menu engineering strategies
        insights['star_performers'] = starPerformers;
        insights['underperformers'] = underPerformers;
        insights['menu_engineering_suggestions'] = _generateMenuEngineeringSuggestions(popularItems);
      }
      
    } catch (e) {
      debugPrint('Error generating menu optimization insights: $e');
    }
    
    return insights;
  }

  /// Generate operational efficiency insights
  Future<Map<String, dynamic>> _generateOperationalEfficiencyInsights(Map<String, dynamic> data) async {
    final insights = <String, dynamic>{};
    
    try {
      final performanceMetrics = data['performance_metrics'] as Map<String, dynamic>;
      final operationalInsights = data['operational_insights'] as Map<String, dynamic>;
      
      // Kitchen efficiency analysis
      final kitchenPerformance = performanceMetrics['kitchen_performance'] as Map<String, dynamic>;
      if (kitchenPerformance.isNotEmpty) {
        final avgDelay = kitchenPerformance['avg_delay_minutes'] ?? 0;
        final onTimeRate = _calculateOnTimeRate(kitchenPerformance);
        
        insights['kitchen_efficiency'] = {
          'avg_delay_minutes': avgDelay,
          'on_time_rate': onTimeRate,
          'efficiency_score': _calculateEfficiencyScore(avgDelay, onTimeRate),
        };
      }
      
      // Table turnover analysis
      final tableUtilization = operationalInsights['table_utilization'] as List<dynamic>;
      if (tableUtilization.isNotEmpty) {
        insights['table_optimization'] = _analyzeTableOptimization(tableUtilization);
      }
      
    } catch (e) {
      debugPrint('Error generating operational efficiency insights: $e');
    }
    
    return insights;
  }

  /// Generate customer experience insights
  Future<Map<String, dynamic>> _generateCustomerExperienceInsights(Map<String, dynamic> data) async {
    final insights = <String, dynamic>{};
    
    try {
      final customerInsights = data['customer_insights'] as Map<String, dynamic>;
      final loyalCustomers = customerInsights['loyal_customers'] as List<dynamic>;
      
      if (loyalCustomers.isNotEmpty) {
        // Customer lifetime value analysis
        final totalCustomers = loyalCustomers.length;
        final avgLifetimeValue = loyalCustomers.fold<double>(0, (sum, customer) {
          return sum + (customer['total_spent'] ?? 0);
        }) / totalCustomers;
        
        insights['customer_loyalty'] = {
          'loyal_customer_count': totalCustomers,
          'avg_lifetime_value': avgLifetimeValue,
          'top_customers': loyalCustomers.take(10).toList(),
        };
      }
      
    } catch (e) {
      debugPrint('Error generating customer experience insights: $e');
    }
    
    return insights;
  }

  /// Generate predictive analytics
  Future<Map<String, dynamic>> _generatePredictiveAnalytics(Map<String, dynamic> data) async {
    final insights = <String, dynamic>{};
    
    try {
      final dailyData = data['daily_data'] as List<dynamic>;
      final hourlyData = data['hourly_data'] as List<dynamic>;
      
      // Revenue trend prediction
      if (dailyData.length >= 7) {
        final revenuePredict = _predictRevenueTrend(dailyData);
        insights['revenue_forecast'] = revenuePredict;
      }
      
      // Peak time prediction
      if (hourlyData.isNotEmpty) {
        insights['predicted_peak_times'] = _predictPeakTimes(hourlyData);
      }
      
    } catch (e) {
      debugPrint('Error generating predictive analytics: $e');
    }
    
    return insights;
  }

  /// Generate actionable recommendations
  Future<List<Map<String, dynamic>>> _generateActionableRecommendations(Map<String, dynamic> data) async {
    final recommendations = <Map<String, dynamic>>[];
    
    try {
      // Revenue optimization recommendations
      final revenueInsights = await _generateRevenueOptimizationInsights(data);
      if (revenueInsights['peak_revenue_hours'] != null) {
        recommendations.add({
          'category': 'Revenue Optimization',
          'priority': 'High',
          'title': 'Optimize Staffing for Peak Hours',
          'description': 'Increase staff during peak revenue hours to maximize service quality and sales',
          'impact': 'Potential 10-15% revenue increase',
          'action_items': [
            'Schedule more servers during peak hours',
            'Prepare popular items in advance',
            'Consider dynamic pricing for peak times',
          ],
        });
      }
      
      // Menu optimization recommendations
      final menuInsights = await _generateMenuOptimizationInsights(data);
      if (menuInsights['underperformers'] != null) {
        final underPerformers = menuInsights['underperformers'] as List<dynamic>;
        if (underPerformers.isNotEmpty) {
          recommendations.add({
            'category': 'Menu Optimization',
            'priority': 'Medium',
            'title': 'Review Underperforming Menu Items',
            'description': 'Several menu items have low order frequency and may need promotion or removal',
            'impact': 'Improved menu efficiency and cost reduction',
            'action_items': [
              'Promote underperforming items with special offers',
              'Consider seasonal menu adjustments',
              'Remove items with consistently low sales',
            ],
          });
        }
      }
      
      // Operational efficiency recommendations
      final operationalInsights = await _generateOperationalEfficiencyInsights(data);
      if (operationalInsights['kitchen_efficiency'] != null) {
        final kitchenEff = operationalInsights['kitchen_efficiency'] as Map<String, dynamic>;
        final onTimeRate = kitchenEff['on_time_rate'] ?? 1.0;
        if (onTimeRate < 0.8) {
          recommendations.add({
            'category': 'Kitchen Operations',
            'priority': 'High',
            'title': 'Improve Kitchen Timing',
            'description': 'Kitchen on-time performance is below 80%. Focus on preparation efficiency',
            'impact': 'Better customer satisfaction and table turnover',
            'action_items': [
              'Review kitchen workflow processes',
              'Implement prep-ahead strategies',
              'Consider kitchen equipment upgrades',
            ],
          });
        }
      }
      
    } catch (e) {
      debugPrint('Error generating recommendations: $e');
    }
    
    return recommendations;
  }

  // Helper methods for calculations
  double _calculateOnTimeRate(Map<String, dynamic> kitchenData) {
    final onTime = kitchenData['on_time_orders'] ?? 0;
    final total = kitchenData['total_timed_orders'] ?? 1;
    return total > 0 ? onTime / total : 1.0;
  }

  double _calculateEfficiencyScore(double avgDelay, double onTimeRate) {
    // Score from 0-100 based on delay and on-time rate
    final delayScore = max(0, 100 - (avgDelay * 2)); // Penalty for delays
    final timeScore = onTimeRate * 100;
    return (delayScore + timeScore) / 2;
  }

  List<Map<String, dynamic>> _generateMenuEngineeringSuggestions(List<dynamic> items) {
    // Implement menu engineering matrix (Stars, Plowhorses, Puzzles, Dogs)
    return items.map<Map<String, dynamic>>((item) {
      final popularity = (item['order_count'] ?? 0) as int;
      final profitability = (item['total_revenue'] ?? 0) / max(1, popularity);
      
      String category;
      String suggestion;
      
      if (popularity > 10 && profitability > 15) {
        category = 'Star';
        suggestion = 'Promote and maintain quality';
      } else if (popularity > 10 && profitability <= 15) {
        category = 'Plowhorse';
        suggestion = 'Increase price or reduce costs';
      } else if (popularity <= 10 && profitability > 15) {
        category = 'Puzzle';
        suggestion = 'Promote to increase popularity';
      } else {
        category = 'Dog';
        suggestion = 'Consider removing from menu';
      }
      
      return {
        'item': item,
        'category': category,
        'suggestion': suggestion,
      };
    }).toList();
  }

  Map<String, dynamic> _analyzeTableOptimization(List<dynamic> tableData) {
    final totalRevenue = tableData.fold<double>(0, (sum, table) => sum + (table['revenue'] ?? 0));
    final avgRevenuePerTable = totalRevenue / tableData.length;
    
    final highPerformingTables = tableData.where((table) => 
        (table['revenue'] ?? 0) > avgRevenuePerTable * 1.2).toList();
    
    final underutilizedTables = tableData.where((table) => 
        (table['revenue'] ?? 0) < avgRevenuePerTable * 0.5).toList();
    
    return {
      'avg_revenue_per_table': avgRevenuePerTable,
      'high_performing_tables': highPerformingTables,
      'underutilized_tables': underutilizedTables,
    };
  }

  Map<String, dynamic> _predictRevenueTrend(List<dynamic> dailyData) {
    // Simple linear regression for trend prediction
    final revenues = dailyData.map<double>((day) => (day['revenue'] ?? 0).toDouble()).toList();
    final n = revenues.length;
    
    if (n < 2) return {'trend': 'insufficient_data'};
    
    final x = List.generate(n, (i) => i.toDouble());
    final sumX = x.fold<double>(0, (sum, val) => sum + val);
    final sumY = revenues.fold<double>(0, (sum, val) => sum + val);
    final sumXY = List.generate(n, (i) => x[i] * revenues[i]).fold<double>(0, (sum, val) => sum + val);
    final sumX2 = x.fold<double>(0, (sum, val) => sum + val * val);
    
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;
    
    final trendDirection = slope > 0 ? 'increasing' : slope < 0 ? 'decreasing' : 'stable';
    final nextDayPrediction = intercept + slope * n;
    
    return {
      'trend': trendDirection,
      'slope': slope,
      'next_day_prediction': nextDayPrediction,
      'confidence': _calculateTrendConfidence(revenues, slope, intercept),
    };
  }

  List<Map<String, dynamic>> _predictPeakTimes(List<dynamic> hourlyData) {
    final sortedByRevenue = List<Map<String, dynamic>>.from(hourlyData)
      ..sort((a, b) => (b['revenue'] ?? 0).compareTo(a['revenue'] ?? 0));
    
    return sortedByRevenue.take(3).map<Map<String, dynamic>>((hour) => {
      'hour': hour['hour'],
      'predicted_revenue': hour['revenue'],
      'confidence': 'high',
    }).toList();
  }

  double _calculateTrendConfidence(List<double> values, double slope, double intercept) {
    if (values.length < 3) return 0.5;
    
    // Calculate R-squared
    final mean = values.fold<double>(0, (sum, val) => sum + val) / values.length;
    final ssTotal = values.fold<double>(0, (sum, val) => sum + pow(val - mean, 2));
    
    double ssResidual = 0;
    for (int i = 0; i < values.length; i++) {
      final predicted = intercept + slope * i;
      ssResidual += pow(values[i] - predicted, 2);
    }
    
    final rSquared = 1 - (ssResidual / ssTotal);
    return max(0, min(1, rSquared));
  }

  /// Clear analytics cache
  void clearCache() {
    _cachedDashboardData = null;
    _lastCacheUpdate = null;
    _aiInsights = null;
    _lastAiUpdate = null;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getTotalSales() async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        return await db.rawQuery('''
          SELECT SUM(total_amount) as total_sales, COUNT(*) as total_orders
          FROM orders 
          WHERE payment_status = 'completed'
        ''');
      }
      return [];
    } catch (e) {
      debugPrint('Error getting total sales: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSalesToday() async {
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      
      final db = await _databaseService.database;
      if (db != null) {
        return await db.rawQuery('''
          SELECT SUM(total_amount) as today_sales, COUNT(*) as today_orders
          FROM orders 
          WHERE payment_status = 'completed'
          AND order_time >= ? AND order_time < ?
        ''', [todayStart.toIso8601String(), todayEnd.toIso8601String()]);
      }
      return [];
    } catch (e) {
      debugPrint('Error getting today sales: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTopSellingItems() async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        final result = await db.rawQuery('''
          SELECT 
            oi.menu_item_id,
            mi.name as item_name,
            SUM(oi.quantity) as total_quantity,
            SUM(oi.total_price) as total_revenue
          FROM order_items oi
          JOIN menu_items mi ON oi.menu_item_id = mi.id
          JOIN orders o ON oi.order_id = o.id
          WHERE o.payment_status = 'completed'
          GROUP BY oi.menu_item_id, mi.name
          ORDER BY total_quantity DESC
          LIMIT 10
        ''');
        return result;
      }
      return [];
    } catch (e) {
      debugPrint('Error getting top selling items: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getOrdersByHour() async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        final result = await db.rawQuery('''
          SELECT 
            CAST(strftime('%H', order_time) AS INTEGER) as hour,
            COUNT(*) as order_count,
            SUM(total_amount) as total_sales
          FROM orders
          WHERE payment_status = 'completed'
          GROUP BY hour
          ORDER BY hour
        ''');
        return result;
      }
      return [];
    } catch (e) {
      debugPrint('Error getting orders by hour: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getOrdersByDay() async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        final result = await db.rawQuery('''
          SELECT 
            DATE(order_time) as date,
            COUNT(*) as order_count,
            SUM(total_amount) as total_sales
          FROM orders
          WHERE payment_status = 'completed'
          GROUP BY date
          ORDER BY date DESC
          LIMIT 30
        ''');
        return result;
      }
      return [];
    } catch (e) {
      debugPrint('Error getting orders by day: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getOrdersByStatus() async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        return await db.rawQuery('''
          SELECT status, COUNT(*) as count
          FROM orders
          GROUP BY status
        ''');
      }
      return [];
    } catch (e) {
      debugPrint('Error getting orders by status: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAverageOrderValue() async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        return await db.rawQuery('''
          SELECT AVG(total_amount) as average_order_value
          FROM orders 
          WHERE payment_status = 'completed'
        ''');
      }
      return [];
    } catch (e) {
      debugPrint('Error getting average order value: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCustomerAnalytics() async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        return await db.rawQuery('''
          SELECT 
            customer_name,
            customer_phone,
            COUNT(*) as order_count,
            SUM(total_amount) as total_spent,
            AVG(total_amount) as average_order_value
          FROM orders
          WHERE payment_status = 'completed'
          AND customer_name IS NOT NULL
          AND customer_name != ''
          GROUP BY customer_name, customer_phone
          ORDER BY total_spent DESC
          LIMIT 50
        ''');
      }
      return [];
    } catch (e) {
      debugPrint('Error getting customer analytics: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPaymentMethodAnalytics() async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        return await db.rawQuery('''
          SELECT 
            payment_method,
            COUNT(*) as transaction_count,
            SUM(total_amount) as total_amount
          FROM orders
          WHERE payment_status = 'completed'
          GROUP BY payment_method
          ORDER BY total_amount DESC
        ''');
      }
      return [];
    } catch (e) {
      debugPrint('Error getting payment method analytics: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        final result = await db.rawQuery('''
          SELECT 
            COUNT(*) as total_orders,
            SUM(CASE WHEN payment_status = 'completed' THEN total_amount ELSE 0 END) as total_revenue,
            COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_orders,
            COUNT(CASE WHEN status = 'in_progress' THEN 1 END) as active_orders
          FROM orders
        ''');
        
        return result.isNotEmpty ? result.first : {
          'total_orders': 0,
          'total_revenue': 0.0,
          'pending_orders': 0,
          'active_orders': 0,
        };
      }
      return {
        'total_orders': 0,
        'total_revenue': 0.0,
        'pending_orders': 0,
        'active_orders': 0,
      };
    } catch (e) {
      debugPrint('Error getting dashboard stats: $e');
      return {
        'total_orders': 0,
        'total_revenue': 0.0,
        'pending_orders': 0,
        'active_orders': 0,
      };
    }
  }
} 