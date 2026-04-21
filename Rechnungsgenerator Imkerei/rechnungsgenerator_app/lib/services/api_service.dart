import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/models.dart';
import '../utils/feedback_service.dart';

class APIService {
  // Render Backend URL
  static const String baseUrl =
      'https://rechnungsgenerator-backend.onrender.com';
  static const String apiVersion = 'api';

  static final APIService _instance = APIService._internal();

  APIService._internal();

  factory APIService() {
    return _instance;
  }

  // ============ COMPANIES ============

  Future<CompanyModel?> getCompany(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/companies/$id'),
        headers: _headers(),
      );
      FeedbackService.logApiCall('/companies/$id', 'GET',
          statusCode: response.statusCode);
      if (response.statusCode == 200) {
        return CompanyModel.fromMap(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      FeedbackService.logApiCall('/companies/$id', 'GET', error: e.toString());
      return null;
    }
  }

  Future<List<CompanyModel>> getAllCompanies() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/companies'),
        headers: _headers(),
      );
      FeedbackService.logApiCall('/companies', 'GET',
          statusCode: response.statusCode);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((item) =>
                CompanyModel.fromMap(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      FeedbackService.logApiCall('/companies', 'GET', error: e.toString());
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
      FeedbackService.logApiCall('/companies', 'POST',
          statusCode: response.statusCode);
      return response.statusCode == 201;
    } catch (e) {
      FeedbackService.logApiCall('/companies', 'POST', error: e.toString());
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
      FeedbackService.logApiCall('/companies/${company.id}', 'PUT',
          statusCode: response.statusCode);
      return response.statusCode == 200;
    } catch (e) {
      FeedbackService.logApiCall('/companies/${company.id}', 'PUT',
          error: e.toString());
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
      FeedbackService.logApiCall('/customers/$id', 'GET',
          statusCode: response.statusCode);
      if (response.statusCode == 200) {
        return CustomerModel.fromMap(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      FeedbackService.logApiCall('/customers/$id', 'GET', error: e.toString());
      return null;
    }
  }

  Future<List<CustomerModel>> getAllCustomers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/customers'),
        headers: _headers(),
      );
      FeedbackService.logApiCall('/customers', 'GET',
          statusCode: response.statusCode);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((item) =>
                CustomerModel.fromMap(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      FeedbackService.logApiCall('/customers', 'GET', error: e.toString());
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
      FeedbackService.logApiCall('/customers', 'POST',
          statusCode: response.statusCode);
      return response.statusCode == 201;
    } catch (e) {
      FeedbackService.logApiCall('/customers', 'POST', error: e.toString());
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
      FeedbackService.logApiCall('/invoices/$id', 'GET',
          statusCode: response.statusCode);
      if (response.statusCode == 200) {
        return InvoiceModel.fromMap(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      FeedbackService.logApiCall('/invoices/$id', 'GET', error: e.toString());
      return null;
    }
  }

  Future<List<InvoiceModel>> getAllInvoices() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$apiVersion/invoices'),
        headers: _headers(),
      );
      FeedbackService.logApiCall('/invoices', 'GET',
          statusCode: response.statusCode);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((item) =>
                InvoiceModel.fromMap(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      FeedbackService.logApiCall('/invoices', 'GET', error: e.toString());
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
      FeedbackService.logApiCall('/invoices', 'POST',
          statusCode: response.statusCode);
      return response.statusCode == 201;
    } catch (e) {
      FeedbackService.logApiCall('/invoices', 'POST', error: e.toString());
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
      FeedbackService.logApiCall('/invoices/sync', 'POST',
          statusCode: response.statusCode);
      return response.statusCode == 200;
    } catch (e) {
      FeedbackService.logApiCall('/invoices/sync', 'POST',
          error: e.toString());
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
      FeedbackService.logApiCall('/design-settings/$companyId', 'GET',
          statusCode: response.statusCode);
      if (response.statusCode == 200) {
        return DesignSettingsModel.fromMap(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      FeedbackService.logApiCall('/design-settings/$companyId', 'GET',
          error: e.toString());
      return null;
    }
  }

  Future<bool> updateDesignSettings(DesignSettingsModel settings) async {
    try {
      final response = await http.put(
        Uri.parse(
            '$baseUrl/$apiVersion/design-settings/${settings.companyId}'),
        headers: _headers(),
        body: jsonEncode(settings.toMap()),
      );
      FeedbackService.logApiCall(
          '/design-settings/${settings.companyId}', 'PUT',
          statusCode: response.statusCode);
      return response.statusCode == 200;
    } catch (e) {
      FeedbackService.logApiCall(
          '/design-settings/${settings.companyId}', 'PUT',
          error: e.toString());
      return false;
    }
  }

  // ============ CONVENIENCE ALIASES ============

  Future<List<InvoiceModel>> getInvoices() => getAllInvoices();
  Future<List<CustomerModel>> getCustomers() => getAllCustomers();

  // ============ UTILITIES ============

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<void> testConnection() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/$apiVersion/health'),
            headers: _headers(),
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw Exception('Connection timeout');
            },
          );
      FeedbackService.logApiCall('/health', 'GET',
          statusCode: response.statusCode);
      if (response.statusCode != 200) {
        throw Exception('API returned status ${response.statusCode}');
      }
    } catch (e) {
      FeedbackService.logApiCall('/health', 'GET', error: e.toString());
      rethrow;
    }
  }
}
