// Firestore handle, the signed-in user id and the JSON type aliases every file uses.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef Json = Map<String, dynamic>;
typedef Doc = DocumentSnapshot<Json>;
typedef QDoc = QueryDocumentSnapshot<Json>;

final db = FirebaseFirestore.instance;
String get myUid => FirebaseAuth.instance.currentUser!.uid;
