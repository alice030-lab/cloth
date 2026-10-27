import 'dart:typed_data';
import 'package:sembast/sembast.dart';
import 'package:sembast/blob.dart';
import '../core/models.dart';

/// Atomic document writes and durable binary assets. Web uses IndexedDB;
/// native uses an app-owned Sembast file. No remote backend or temporary paths.
class Repository {
  final Database db;
  Repository(this.db);
  final _meta = StoreRef<String, dynamic>('meta');
  final _assets = StoreRef<String, Blob>('assets');
  final _items = stringMapStoreFactory.store('items');
  final _outfits = stringMapStoreFactory.store('outfits');
  Future<Map<String, dynamic>?> draft() async {
    final j = await _meta.record('draft').get(db);
    return j == null ? null : Map<String, dynamic>.from(j as Map);
  }

  Future<void> saveDraft(CanvasDocument doc) =>
      _meta.record('draft').put(db, doc.toJson());
  Future<void> saveOutfit(CanvasDocument doc) =>
      _outfits.record(doc.id).put(db, doc.toJson());
  Future<List<CanvasDocument>> outfits() async =>
      (await _outfits.find(
          db,
        )).map((r) => CanvasDocument.fromJson(r.value)).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  Future<void> deleteOutfit(String id) => _outfits.record(id).delete(db);
  Future<void> saveItem(Item item) =>
      _items.record(item.id).put(db, item.toJson());
  Future<List<Item>> items() async =>
      (await _items.find(db)).map((r) => Item.fromJson(r.value)).toList();
  Future<void> putAsset(String id, Uint8List bytes) =>
      _assets.record(id).put(db, Blob(bytes));
  Future<Uint8List?> asset(String id) async =>
      (await _assets.record(id).get(db))?.bytes;
  Future<bool> welcomed() async =>
      await _meta.record('welcomed').get(db) == true;
  Future<void> setWelcomed() => _meta.record('welcomed').put(db, true);
  Future<bool> guided() async => await _meta.record('guided').get(db) == true;
  Future<void> setGuided() async {
    await _meta.record('guided').put(db, true);
  }

  Future<void> clear() async {
    await db.transaction((txn) async {
      await _meta.delete(txn);
      await _assets.delete(txn);
      await _items.delete(txn);
      await _outfits.delete(txn);
    });
  }

  /// Only delete blobs absent from every saved document and active wardrobe.
  /// A transaction makes the reference scan and deletions a single operation.
  Future<void> collectGarbage() async {
    await db.transaction((txn) async {
      final keep = <String>{}, usedItems = <String>{};
      void scan(Map<String, dynamic> doc) {
        for (final key in [
          'beforeSnapshotAssetId',
          'afterSnapshotAssetId',
          'sceneId',
        ]) {
          final value = doc[key];
          if (value is String) keep.add(value);
        }
        for (final raw in doc['layers'] as List? ?? []) {
          final value = (raw as Map)['item_id'];
          if (value is String) usedItems.add(value);
        }
      }

      final draft = await _meta.record('draft').get(txn);
      if (draft is Map) scan(Map<String, dynamic>.from(draft));
      for (final record in await _outfits.find(txn)) {
        scan(record.value);
      }
      for (final record in await _items.find(txn)) {
        final item = record.value, asset = item['assetId'];
        if (asset is String &&
            (item['hidden'] != true || usedItems.contains(item['id']))) {
          keep.add(asset);
        }
      }
      for (final key in await _assets.findKeys(txn)) {
        if (!keep.contains(key)) await _assets.record(key).delete(txn);
      }
    });
  }

  /// Archive wardrobe entry, retain bytes for draft and saved references.
  Future<void> hideItem(Item item) async {
    item.hidden = true;
    await saveItem(item);
  }
}
