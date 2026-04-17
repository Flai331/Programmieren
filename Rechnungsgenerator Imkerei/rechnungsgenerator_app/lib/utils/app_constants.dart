class AppConstants {
  // App Info
  static const String appName = 'Rechnungsgenerator Pro';
  static const String appVersion = '1.0.0';

  // Colors (Material Design inspired + original theme)
  static const int primaryColor = 0xFFfda085; // Peach/Orange
  static const int primaryLightColor = 0xFFf6d365; // Light orange
  static const int primaryDarkColor = 0xFFf29c71; // Dark orange
  static const int accentColor = 0xFF2c3e50; // Dark blue-gray

  // Sizes
  static const double paddingSmall = 8.0;
  static const double paddingNormal = 16.0;
  static const double paddingLarge = 24.0;

  static const double borderRadiusSmall = 4.0;
  static const double borderRadiusNormal = 8.0;
  static const double borderRadiusLarge = 12.0;

  // Invoice defaults
  static const double defaultTaxRate = 19.0; // Germany VAT
  static const int defaultPaymentTermsDays = 14;
  static const String defaultInvoiceNumberPrefix = 'RE';

  // Database
  static const String dbName = 'rechnungsgenerator.db';
  static const int dbVersion = 1;

  // API
  static const String apiBaseUrl = 'https://api.example.com';
  static const String apiVersion = 'v1';
  static const Duration apiTimeout = Duration(seconds: 30);

  // Sync
  static const int maxSyncRetries = 5;
  static const Duration syncRetryDelay = Duration(seconds: 5);
  static const Duration syncCheckInterval = Duration(minutes: 5);

  // Image constraints
  static const int logoMaxWidth = 300;
  static const int logoMaxHeight = 300;
  static const int headerImageMaxWidth = 600;
  static const int headerImageMaxHeight = 200;
  static const double imageCompressionQuality = 0.8;

  // PDF
  static const double pdfPageWidth = 210.0; // A4 in mm
  static const double pdfPageHeight = 297.0;
  static const double pdfMargin = 15.0;

  // Validation
  static const int invoiceNumberMinLength = 3;
  static const int invoiceNumberMaxLength = 20;
  static const int customerNameMaxLength = 100;
  static const int descriptionMaxLength = 500;

  // Pagination
  static const int invoicesPerPage = 20;
  static const int customersPerPage = 50;

  // Error messages
  static const String errorNoInternet = 'Keine Internetverbindung';
  static const String errorSyncFailed = 'Synchronisierung fehlgeschlagen';
  static const String errorInvalidData = 'Ungültige Daten';
  static const String errorDatabaseError = 'Datenbankfehler';
}
