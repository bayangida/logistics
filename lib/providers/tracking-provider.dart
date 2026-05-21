// tracking_provider.dart
import 'package:flutter/foundation.dart';

class TrackingProvider extends ChangeNotifier {
  String? _currentOrderId;
  String? _currentStep; // 'arrived' or 'pickup'

  String? get currentOrderId => _currentOrderId;
  String? get currentStep => _currentStep;

  void startTracking(String orderId) {
    _currentOrderId = orderId;
    _currentStep = 'arrived';
    notifyListeners();
  }

  void proceedToPickup() {
    _currentStep = 'pickup';
    notifyListeners();
  }

  void completeTracking() {
    _currentOrderId = null;
    _currentStep = null;
    notifyListeners();
  }
}