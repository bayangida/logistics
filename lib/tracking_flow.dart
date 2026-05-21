import 'package:bayangida_logistics/providers/tracking-provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_navigator.dart';
import 'logistics/mapview.dart';
// tracking_flow_manager.dart
// tracking_flow_manager.dart
class TrackingFlowManager {
  static void startTrackingFlow(BuildContext context, String orderId) {
    // Access the tracking provider
    final trackingProvider = Provider.of<TrackingProvider>(context, listen: false);
    trackingProvider.startTracking(orderId);

    _showTrackingStep(
      context,
      orderId: orderId,
      currentStep: 'arrived',
      nextAction: () {
        trackingProvider.proceedToPickup();
        _showTrackingStep(
          context,
          orderId: orderId,
          currentStep: 'pickup',
          nextAction: () {
            trackingProvider.completeTracking();
            AppNavigator.navigateToHome(context);
          },
        );
      },
    );
  }

  static void _showTrackingStep(
      BuildContext context, {
        required String orderId,
        required String currentStep,
        required VoidCallback nextAction,
      }) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DeliveryTrackingPage(
          orderId: orderId,
          currentStep: currentStep,
          onStepCompleted: nextAction,
        ),
      ),
    );
  }
}