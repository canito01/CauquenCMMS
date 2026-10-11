import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();
  
  bool _isManuallySimulatedOffline = false;
  bool _currentStatus = true; // true = online, false = offline

  ConnectivityService() {
    _init();
  }

  bool get isOnline => !_isManuallySimulatedOffline && _currentStatus;
  bool get isSimulatedOffline => _isManuallySimulatedOffline;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void _init() {
    _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((result) =>
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet);
      _currentStatus = hasConnection;
      _emit();
    });
  }

  void toggleSimulateOffline() {
    _isManuallySimulatedOffline = !_isManuallySimulatedOffline;
    _emit();
  }

  void _emit() {
    _controller.add(isOnline);
  }

  void dispose() {
    _controller.close();
  }
}

