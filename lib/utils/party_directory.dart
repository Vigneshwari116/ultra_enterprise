import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/ultra_repository.dart';
import 'api_errors.dart';

const customerListRouteMissingMessage = 'Customer list route not found on server';
const supplierListRouteMissingMessage = 'Supplier list route not found on server';

/// Loads customers for pickers; surfaces 404 as a dedicated message (not silent empty).
Future<List<Map<String, dynamic>>> loadCustomersDirectory(
  UltraRepository repo, {
  BuildContext? snackbarContext,
}) async {
  try {
    return await repo.customers();
  } on ApiException catch (e) {
    if (e.statusCode == 404 && snackbarContext != null && snackbarContext.mounted) {
      ScaffoldMessenger.of(snackbarContext).showSnackBar(
        const SnackBar(content: Text(customerListRouteMissingMessage)),
      );
    }
    rethrow;
  }
}

/// Loads suppliers for pickers; surfaces 404 as a dedicated message (not silent empty).
Future<List<Map<String, dynamic>>> loadSuppliersDirectory(
  UltraRepository repo, {
  BuildContext? snackbarContext,
}) async {
  try {
    return await repo.suppliers();
  } on ApiException catch (e) {
    if (e.statusCode == 404 && snackbarContext != null && snackbarContext.mounted) {
      ScaffoldMessenger.of(snackbarContext).showSnackBar(
        const SnackBar(content: Text(supplierListRouteMissingMessage)),
      );
    }
    rethrow;
  }
}

/// Inline hint under customer/supplier dropdowns: loading, empty, or nothing.
Widget partyDirectoryStatus({
  required bool loading,
  required bool isCustomer,
  required int itemCount,
}) {
  if (loading) {
    return const Padding(
      padding: EdgeInsets.only(top: 6),
      child: LinearProgressIndicator(minHeight: 2),
    );
  }
  if (itemCount == 0) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        isCustomer ? 'No customers found' : 'No suppliers found',
        style: const TextStyle(fontSize: 10, color: Color(0xFF748094)),
      ),
    );
  }
  return const SizedBox.shrink();
}
