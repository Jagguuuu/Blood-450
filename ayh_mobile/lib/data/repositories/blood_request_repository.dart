import '../services/blood_request_service.dart';
import '../models/blood_request.dart';

/// Blood requests via Django API (Vercel). Supabase is the database on the server only.
class BloodRequestRepository {
  final BloodRequestService _service = BloodRequestService();

  Future<List<BloodRequest>> getAllRequests() async {
    return await _service.getAllRequests();
  }

  Future<List<BloodRequest>> getActiveRequests() async {
    return await _service.getActiveRequests();
  }

  Future<List<BloodRequest>> getMyRequests() async {
    return await _service.getMyRequests();
  }

  Future<BloodRequest?> getRequestDetail(int id) async {
    return await _service.getRequestDetail(id);
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
    return await _service.createRequest(
      bloodGroup: bloodGroup,
      unitsNeeded: unitsNeeded,
      urgency: urgency,
      note: note,
      reqLat: reqLat,
      reqLng: reqLng,
      locationName: locationName,
      radiusKm: radiusKm,
    );
  }

  Future<bool> updateRequest(int id, {bool? isActive}) async {
    return await _service.updateRequest(id, isActive: isActive);
  }

  Future<bool> deleteRequest(int id) async {
    return await _service.deleteRequest(id);
  }
}
