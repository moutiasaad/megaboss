import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/motif_model.dart';
import '../../data/services/motifs_service.dart';

const _kMotifsBox = 'mb_motifs';
const _kKey = 'all';

// Caches the motifs list so the return / refuse sheets can open instantly even
// offline. Server response rarely changes — a single cache entry is enough.
class MotifsRepository {
  MotifsRepository({
    required MotifsService service,
    required Box<String> box,
  })  : _service = service,
        _box = box;

  final MotifsService _service;
  final Box<String> _box;

  static Future<Box<String>> openBox() => Hive.openBox<String>(_kMotifsBox);

  MotifsModel? get cached {
    final raw = _box.get(_kKey);
    if (raw == null) return null;
    try {
      return MotifsModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<MotifsModel> get() async {
    final motifs = await _service.get();
    await _box.put(_kKey, jsonEncode(motifs.toJson()));
    return motifs;
  }
}
