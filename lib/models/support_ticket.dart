import 'package:equatable/equatable.dart';

import 'model_utils.dart';

/// A ticket category (`ticketCategories/{id}`).
///
/// Note the camelCase collection name — unlike `geo_tiers` and every other
/// multi-word collection in this database, which are snake_case. It is
/// verified against the shipped bundle; renaming it would orphan every
/// existing ticket.
class TicketCategory extends Equatable {
  const TicketCategory({
    required this.id,
    required this.title,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory TicketCategory.fromMap(String id, Map<String, dynamic> map) =>
      TicketCategory(
        id: id,
        title: Parse.toStr(map['title']),
        sortOrder: Parse.toInt(map['sortOrder']),
        isActive: Parse.toBool(map['isActive'], true),
      );

  final String id;
  final String title;
  final int sortOrder;
  final bool isActive;

  @override
  List<Object?> get props => [id, title, sortOrder, isActive];
}

enum TicketStatus {
  open('open'),
  awaitingUser('awaiting_user'),
  resolved('resolved'),
  closed('closed');

  const TicketStatus(this.wire);

  final String wire;

  static TicketStatus fromWire(String? v) => TicketStatus.values.firstWhere(
        (s) => s.wire == v,
        orElse: () => TicketStatus.open,
      );

  bool get isOpen => this == open || this == awaitingUser;
}

/// A support ticket (`supportTickets/{id}`) — also camelCase, see
/// [TicketCategory].
class SupportTicket extends Equatable {
  const SupportTicket({
    required this.id,
    required this.uid,
    required this.categoryId,
    required this.subject,
    required this.message,
    this.status = TicketStatus.open,
    this.attachmentUrl,
    this.messages = const [],
    this.hasUnreadForUser = false,
    this.createdAt,
    this.updatedAt,
  });

  factory SupportTicket.fromMap(String id, Map<String, dynamic> map) =>
      SupportTicket(
        id: id,
        uid: Parse.toStr(map['uid']),
        categoryId: Parse.toStr(map['categoryId'], 'other'),
        subject: Parse.toStr(map['subject']),
        message: Parse.toStr(map['message']),
        status: TicketStatus.fromWire(map['status'] as String?),
        attachmentUrl: map['attachmentUrl'] as String?,
        messages: (map['messages'] as List<dynamic>? ?? const [])
            .map((e) => TicketMessage.fromMap(Parse.toMap(e)))
            .toList(),
        hasUnreadForUser: Parse.toBool(map['hasUnreadForUser']),
        createdAt: Parse.toDate(map['createdAt']),
        updatedAt: Parse.toDate(map['updatedAt']),
      );

  final String id;
  final String uid;
  final String categoryId;
  final String subject;

  /// The opening message. Replies live in [messages]; keeping the first one
  /// separate means the ticket list can show a preview without reading the
  /// whole thread.
  final String message;
  final TicketStatus status;
  final String? attachmentUrl;
  final List<TicketMessage> messages;
  final bool hasUnreadForUser;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [id, status, updatedAt, messages.length];
}

class TicketMessage extends Equatable {
  const TicketMessage({
    required this.body,
    required this.fromAdmin,
    this.authorName,
    this.sentAt,
  });

  factory TicketMessage.fromMap(Map<String, dynamic> map) => TicketMessage(
        body: Parse.toStr(map['body']),
        fromAdmin: Parse.toBool(map['fromAdmin']),
        authorName: map['authorName'] as String?,
        sentAt: Parse.toDate(map['sentAt']),
      );

  final String body;
  final bool fromAdmin;
  final String? authorName;
  final DateTime? sentAt;

  @override
  List<Object?> get props => [body, fromAdmin, sentAt];
}
