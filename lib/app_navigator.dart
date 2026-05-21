import 'package:bayangida_logistics/profile/menuselect.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'logistics/orderhistory.dart';
import 'logistics/deliveryend.dart';
import 'logistics/entries.dart';
import 'logistics/home.dart';
import 'logistics/mapview.dart';
import 'logistics/ordersdetail.dart' hide OrderDetailsPage;
import 'logistics/ordersdetail1.dart';

class AppNavigator {


  static void navigateToHome(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => WelcomeDashboardPage()),
    );
  }

  static void navigateToOrders(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ManageOrdersPage()),
    );
  }

  static void navigateToOrderDetails(BuildContext context, {
    required Map<String, dynamic> order,
    required DocumentReference orderRef,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            OrderDetailsPage(
              order: order,
              orderRef: orderRef,
            ),
      ),
    );
  }


  static void navigateToDelivery(BuildContext context, {
    required String orderId,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeliveryPage(orderId: orderId),
      ),
    );
  }


  static void navigateToDeliveryEntries(BuildContext context, {
    required String orderId,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) =>
          Deliveryentries(orderId: orderId)),

    );
  }




  static void navigateToDeliveryTracking(BuildContext context, {
    required String orderId,
    required String currentStep,
    required VoidCallback onStepCompleted,
  }) {
    Navigator.push(
        context,
        MaterialPageRoute(builder: (context) =>
        DeliveryTrackingPage(
          orderId: orderId,
          currentStep: currentStep,
          onStepCompleted: onStepCompleted,
        ),
    ));
  }

  static void navigateToDeliveryEnd(BuildContext context, {
    required String orderId,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DeliveryPageend(orderId: orderId)),
    );
  }

  static void navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfilePage()),
    );
  }
}