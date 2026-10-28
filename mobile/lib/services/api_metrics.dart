class ApiMetrics {
  int _requestAttempts = 0;
  int _retryCount = 0;
  int _responseBytes = 0;
  int _inFlightGetHits = 0;

  int get requestAttempts => _requestAttempts;
  int get retryCount => _retryCount;
  int get responseBytes => _responseBytes;
  int get inFlightGetHits => _inFlightGetHits;

  void recordRequestAttempt() => _requestAttempts++;
  void recordRetry() => _retryCount++;
  void recordResponseBytes(int bytes) => _responseBytes += bytes;
  void recordInFlightGetHit() => _inFlightGetHits++;

  Map<String, int> snapshot() => {
        'requestAttempts': _requestAttempts,
        'retryCount': _retryCount,
        'responseBytes': _responseBytes,
        'inFlightGetHits': _inFlightGetHits,
      };
}
