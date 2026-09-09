import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/providers.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/error/result.dart';
import '../../../core/network/firebase_error_mapper.dart';
import '../../../models/support_ticket.dart';

/// Support tickets and their categories.
///
/// Both collections are camelCase (`supportTickets`, `ticketCategories`),
/// unlike every other multi-word collection here. That is what the shipped
/// client reads, so it is not a typo to be tidied up.
class SupportRepository {
  const SupportRepository(this._db);

  final FirebaseFirestore _db;

  Stream<List<TicketCategory>> watchCategories() => _db
      .collection(FsPaths.ticketCategories)
      .where('isActive', isEqualTo: true)
      .orderBy('sortOrder')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => TicketCategory.fromMap(d.id, d.data()))
            .toList(),
      );

  Stream<List<SupportTicket>> watchMine(String uid) => _db
      .collection(FsPaths.supportTickets)
      .where('uid', isEqualTo: uid)
      .orderBy('updatedAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => SupportTicket.fromMap(d.id, d.data()))
            .toList(),
      );

  Future<Result<String>> create({
    required String uid,
    required String categoryId,
    required String subject,
    required String message,
    String? attachmentUrl,
  }) async {
    try {
      final doc = await _db.collection(FsPaths.supportTickets).add({
        'uid': uid,
        'categoryId': categoryId,
        'subject': subject.trim(),
        'message': message.trim(),
        'attachmentUrl': attachmentUrl,
        'status': 'open',
        'messages': <Map<String, dynamic>>[],
        'hasUnreadForUser': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return Result.success(doc.id);
    } on Object catch (e, s) {
      return Result.failure(FirebaseErrorMapper.map(e, s));
    }
  }

  /// Appends a reply.
  ///
  /// `fromAdmin` is hard-coded false and the rules enforce it, so a user
  /// cannot forge a message that appears to come from support.
  Future<Result<void>> reply({
    required String ticketId,
    required String body,
  }) async {
    try {
      await _db.collection(FsPaths.supportTickets).doc(ticketId).update({
        'messages': FieldValue.arrayUnion([
          {'body': body.trim(), 'fromAdmin': false, 'sentAt': Timestamp.now()},
        ]),
        'status': 'open',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Result.success(null);
    } on Object catch (e, s) {
      return Result.failure(FirebaseErrorMapper.map(e, s));
    }
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.watch(firestoreProvider));
});
