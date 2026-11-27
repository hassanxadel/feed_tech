// Product and logo photos.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:feedtech/services/firebase_service.dart';

// shortcut: photos are stored compressed (≤ ~500 KB) in Firestore because the project is on the
// free Spark plan, where Firebase Storage needs Blaze. Move them to Storage after upgrading.

final _photoCache = <String, Uint8List>{};

Future<String> savePhoto(Uint8List bytes) async {
  final ref = await db.collection('photos').add({'owner': myUid, 'data': base64Encode(bytes), 'at': FieldValue.serverTimestamp()});
  _photoCache[ref.id] = bytes;
  return ref.id;
}

Future<Uint8List?> loadPhoto(String id) async {
  if (_photoCache.containsKey(id)) return _photoCache[id];
  final d = await db.collection('photos').doc(id).get();
  final data = d.data()?['data'];
  if (data is! String) return null;
  return _photoCache[id] = base64Decode(data);
}
