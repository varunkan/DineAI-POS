/// Custom exception for database operations
class DatabaseException implements Exception {
  final String message;
  final String? operation;
  final dynamic originalError;

  DatabaseException(this.message, {this.operation, this.originalError});

  @override
  String toString() => 'DatabaseException: $message${operation != null ? ' (Operation: $operation)' : ''}';
}

/// Custom exception for order operations
class OrderServiceException implements Exception {
  final String message;
  final String? operation;
  final dynamic originalError;

  OrderServiceException(this.message, {this.operation, this.originalError});

  @override
  String toString() => 'OrderServiceException: $message${operation != null ? ' (Operation: $operation)' : ''}';
}

/// Custom exception for menu operations
class MenuServiceException implements Exception {
  final String message;
  final String? operation;
  final dynamic originalError;

  MenuServiceException(this.message, {this.operation, this.originalError});

  @override
  String toString() => 'MenuServiceException: $message${operation != null ? ' (Operation: $operation)' : ''}';
} 