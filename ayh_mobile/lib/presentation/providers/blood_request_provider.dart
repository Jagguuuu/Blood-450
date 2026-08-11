import 'package:flutter/foundation.dart';
import '../../data/repositories/blood_request_repository.dart';
import '../../data/models/blood_request.dart' show BloodRequest;

class BloodRequestProvider with ChangeNotifier {
  final BloodRequestRepository _repository = BloodRequestRepository();

  List<BloodRequest> _requests = [];
  List<BloodRequest> _activeRequests = [];
  List<BloodRequest> _myRequests = [];
  BloodRequest? _selectedRequest;
  bool _isLoading = false;
  String? _error;

  List<BloodRequest> get requests => _requests;
  List<BloodRequest> get activeRequests => _activeRequests;
  List<BloodRequest> get myRequests => _myRequests;
  BloodRequest? get selectedRequest => _selectedRequest;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAllRequests() async {
    _isLoading = true;
    notifyListeners();

    try {
      _requests = await _repository.getAllRequests();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadActiveRequests() async {
    _isLoading = true;
    notifyListeners();

    try {
      _activeRequests = await _repository.getActiveRequests();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMyRequests() async {
    _isLoading = true;
    notifyListeners();

    try {
      _myRequests = await _repository.getMyRequests();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadRequestDetail(int id) async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedRequest = await _repository.getRequestDetail(id);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> createRequest({
    required String bloodGroup,
    required int unitsNeeded,
    required String urgency,
    String? note,
    double? reqLat,
    double? reqLng,
    String? locationName,
    double? radiusKm,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _repository.createRequest(
        bloodGroup: bloodGroup,
        unitsNeeded: unitsNeeded,
        urgency: urgency,
        note: note,
        reqLat: reqLat,
        reqLng: reqLng,
        locationName: locationName,
        radiusKm: radiusKm,
      );
      
      if (result['success']) {
        await loadMyRequests();
      } else {
        _error = result['error'];
      }
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> updateRequest(int id, {bool? isActive}) async {
    final success = await _repository.updateRequest(id, isActive: isActive);
    if (success) {
      await loadAllRequests();
    }
    return success;
  }

  Future<bool> deleteRequest(int id) async {
    final success = await _repository.deleteRequest(id);
    if (success) {
      await loadAllRequests();
    }
    return success;
  }
}
