import '../models/body_measurement.dart';
import '../services/database_service.dart';

class BodyMeasurementRepository {
  BodyMeasurementRepository(this._databaseService);

  final DatabaseService _databaseService;

  Future<BodyMeasurement> addMeasurement(BodyMeasurement measurement) async {
    final id = await _databaseService.insert('body_measurements', measurement.toMap());
    return measurement.copyWith(id: id);
  }

  Future<List<BodyMeasurement>> fetchMeasurements({int limit = 50}) async {
    final rows = await _databaseService.query(
      'body_measurements',
      orderBy: 'recorded_at DESC',
      limit: limit,
    );
    return rows.map(BodyMeasurement.fromMap).toList();
  }

  Future<BodyMeasurement?> latest() async {
    final rows = await _databaseService.query(
      'body_measurements',
      orderBy: 'recorded_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return BodyMeasurement.fromMap(rows.first);
  }

  Future<BodyMeasurement?> previous() async {
    final rows = await _databaseService.query(
      'body_measurements',
      orderBy: 'recorded_at DESC',
      limit: 2,
    );
    if (rows.length < 2) {
      return null;
    }
    return BodyMeasurement.fromMap(rows[1]);
  }
}
