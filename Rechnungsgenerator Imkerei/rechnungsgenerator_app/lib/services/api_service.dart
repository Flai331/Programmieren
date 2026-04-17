import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/models.dart';

class ApiService {
  // TODO: Replace with actual Render API URL when backend is ready
  static const String baseUrl = 'https://api.example.com';
  static const String apiVersion = 'v1';

  static final ApiService _instance = ApiService._internal();

  ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  // ============ COMPANIES ============

  Future<CompanyModel?> getCompany(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/companies/$id'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        return CompanyModel.fromMap(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error fetching company: $e');
      return null;
    }
  }

  Future<List<CompanyModel>> getAllCompanies() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/companies'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => CompanyModel.fromMap(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching companies: $e');
      return [];
    }
  }

  Future<bool> createCompany(CompanyModel company) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$apiVersion/companies'),
        headers: _headers(),
        body: jsonEncode(company.toMap()),
      );

      return response.statusCode == 201;
    } catch (e) {
      print('Error creating company: $e');
      return false;
    }
  }

  Future<bool> updateCompany(CompanyModel company) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$apiVersion/companies/${company.id}'),
        headers: _headers(),
        body: jsonEncode(company.toMap()),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating company: $e');
      return false;
    }
  }

  // ============ CUSTOMERS ============

  Future<CustomerModel?> getCustomer(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/customers/$id'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        return CustomerModel.fromMap(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error fetching customer: $e');
      return null;
    }
  }

  Future<List<CustomerModel>> getAllCustomers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/customers'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => CustomerModel.fromMap(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching customers: $e');
      return [];
    }
  }

  Future<bool> createCustomer(CustomerModel customer) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$apiVersion/customers'),
        headers: _headers(),
        body: jsonEncode(customer.toMap()),
      );

      return response.statusCode == 201;
    } catch (e) {
      print('Error creating customer: $e');
      return false;
    }
  }

  // ============ INVOICES ============

  Future<InvoiceModel?> getInvoice(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/invoices/$id'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        return InvoiceModel.fromMap(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error fetching invoice: $e');
      return null;
    }
  }

  Future<List<InvoiceModel>> getAllInvoices() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/invoices'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => InvoiceModel.fromMap(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching invoices: $e');
      return [];
    }
  }

  Future<bool> createInvoice(InvoiceModel invoice) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$apiVersion/invoices'),
        headers: _headers(),
        body: jsonEncode(invoice.toMap()),
      );

      return response.statusCode == 201;
    } catch (e) {
      print('Error creating invoice: $e');
      return false;
    }
  }

  Future<bool> syncInvoices(List<InvoiceModel> invoices) async {
    try {
      final data = invoices.map((inv) => inv.toMap()).toList();
      final response = await http.post(
        Uri.parse('$baseUrl/$apiVersion/invoices/sync'),
        headers: _headers(),
        body: jsonEncode({'invoices': data}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error syncing invoices: $e');
      return false;
    }
  }

  // ============ DESIGN SETTINGS ============

  Future<DesignSettingsModel?> getDesignSettings(String companyId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/design-settings/$companyId'),
        headers: _headers(),
      );

      if (response.statusCode == 200) {
        return DesignSettingsModel.fromMap(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error fetching design settings: $e');
      return null;
    }
  }

  Future<bool> updateDesignSettings(DesignSettingsModel settings) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$apiVersion/design-settings/${settings.companyId}'),
        headers: _headers(),
        body: jsonEncode(settings.toMap()),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating design settings: $e');
      return false;
    }
  }

  // ============ UTILITIES ============

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // TODO: Add authentication headers when backend is ready
      // 'Authorization': 'Bearer $token',
    };
  }

  Future<void> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/health'),
        headers: _headers(),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('API returned status ${response.statusCode}');
      }
    } catch (e) {
      print('Connection test failed: $e');
      rethrow;
    }
  }
}
