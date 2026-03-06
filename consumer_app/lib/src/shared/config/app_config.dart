class AppConfig {
  // Order Configuration
  static const double minimumOrderAmount = 15.0;
  
  // Fee Configuration
  static const double taxRate = 0.075; // 7.5%
  static const double serviceFeeRate = 0.10; // 10%
  
  // Delivery Fee Configuration
  static const double baseDeliveryFee = 3.0;
  static const double freeDeliveryDistance = 3.0; // miles
  static const double perMileFee = 1.0; // per mile after free distance
  
  // Store Information
  static const String storeAddress = '528 W Vine St, Kissimmee, FL 34741';
  
  // UI Configuration
  static const int snackBarDurationSeconds = 3;
  
  // Calculate delivery fee based on distance
  static double calculateDeliveryFee(double distanceInMiles) {
    if (distanceInMiles <= freeDeliveryDistance) {
      return baseDeliveryFee;
    }
    return baseDeliveryFee + ((distanceInMiles - freeDeliveryDistance) * perMileFee);
  }
  
  // Calculate tax
  static double calculateTax(double subtotal) {
    return subtotal * taxRate;
  }
  
  // Calculate service fee
  static double calculateServiceFee(double subtotal) {
    return subtotal * serviceFeeRate;
  }
  
  // Calculate total
  static double calculateTotal(double subtotal, double deliveryFee) {
    final tax = calculateTax(subtotal);
    final serviceFee = calculateServiceFee(subtotal);
    return subtotal + tax + serviceFee + deliveryFee;
  }
}
