// lib/core/constants/api_constants.dart

class ApiConstants {
  // Base URL for the FastAPI backend.
  // Use http://10.0.2.2:8000/api/v1 for Android emulator.
  // Use http://localhost:8000/api/v1 for iOS simulator, web, or physical devices on the same network.
  static const String baseUrl = 'http://localhost:8000/api/v1';

  // Endpoint Paths (appended to baseUrl)
  static const String register = '/ngos/register';
  static const String login = '/ngos/login';
  static const String submitRaw = '/submit/raw';
  static const String submitSpreadsheet = '/submit/spreadsheet';
  static const String applications = '/applications';
  static const String dashboardSummary = '/dashboard/summary';
  static const String firebaseCases = '/firebase/cases';
  static const String firebaseCaseDetail = '/firebase/cases/'; // Needs caseId appended
  static const String firebaseVolunteers = '/firebase/volunteers';
  static const String firebaseUpdateStatus = '/firebase/update-case-status';
  static const String firebaseLogTrace = '/firebase/log-trace';
  static const String firebaseLogDispatch = '/firebase/log-dispatch';
  static const String firebaseStats = '/firebase/stats';

  // Request timeout duration
  static const Duration timeoutDuration = Duration(seconds: 30);
}
