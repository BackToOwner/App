/// A failure the UI can show to a user.
///
/// The backend answers errors as `{ success: false, message, details }`, so `message` is already
/// human-readable and safe to display. `code` carries machine-readable cases the app reacts to
/// differently (an expired token triggers a refresh, a suspended account a different screen).
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final List<FieldError> fieldErrors;

  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.fieldErrors = const [],
  });

  bool get isNetworkError => statusCode == null;
  bool get isUnauthorized => statusCode == 401;
  bool get isAccountBlocked => code == 'ACCOUNT_SUSPENDED' || code == 'ACCOUNT_BANNED';
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => message;
}

class FieldError {
  final String path;
  final String message;

  const FieldError(this.path, this.message);
}
