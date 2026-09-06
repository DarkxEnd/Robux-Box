import 'package:equatable/equatable.dart';

import 'model_utils.dart';

/// Lifecycle of a withdrawal request (`redemptions/{id}`).
///
/// Coins leave the wallet at [pending] — not at [completed] — so a user can't
/// queue ten withdrawals against one balance. [rejected] and [cancelled] both
/// refund; [completed] does not.
enum RedemptionStatus {
  pending('pending'),
  processing('processing'),
  completed('completed'),
  rejected('rejected'),
  cancelled('cancelled');

  const RedemptionStatus(this.wire);

  final String wire;

  static RedemptionStatus fromWire(String? v) => RedemptionStatus.values
      .firstWhere((s) => s.wire == v, orElse: () => RedemptionStatus.pending);

  bool get isTerminal => this != pending && this != processing;
  bool get wasRefunded => this == rejected || this == cancelled;

  /// Only a request nobody has started working on can be withdrawn by the
  /// user; once an admin moves it to `processing` a code may already have
  /// been bought.
  bool get isCancellableByUser => this == pending;
}

class Redemption extends Equatable {
  const Redemption({
    required this.id,
    required this.uid,
    required this.rewardId,
    required this.rewardTitle,
    required this.coinCost,
    this.status = RedemptionStatus.pending,
    this.kind = 'robux',
    this.faceValue = 0,
    this.currency = 'RBX',
    this.robloxUsername,
    this.email,
    this.deliveredCode,
    this.adminNote,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  factory Redemption.fromMap(String id, Map<String, dynamic> map) => Redemption(
    id: id,
    uid: Parse.toStr(map['uid']),
    rewardId: Parse.toStr(map['rewardId']),
    rewardTitle: Parse.toStr(map['rewardTitle']),
    coinCost: Parse.toInt(map['coinCost']),
    status: RedemptionStatus.fromWire(map['status'] as String?),
    kind: Parse.toStr(map['kind'], 'robux'),
    faceValue: Parse.toDouble(map['faceValue']),
    currency: Parse.toStr(map['currency'], 'RBX'),
    robloxUsername: map['robloxUsername'] as String?,
    email: map['email'] as String?,
    deliveredCode: map['deliveredCode'] as String?,
    adminNote: map['adminNote'] as String?,
    rejectionReason: map['rejectionReason'] as String?,
    createdAt: Parse.toDate(map['createdAt']),
    updatedAt: Parse.toDate(map['updatedAt']),
    completedAt: Parse.toDate(map['completedAt']),
  );

  final String id;
  final String uid;
  final String rewardId;

  /// Copied from the reward at request time, not looked up on read: the
  /// catalogue entry can be renamed or deleted afterwards and the user's
  /// history must still say what they actually asked for.
  final String rewardTitle;
  final int coinCost;
  final RedemptionStatus status;
  final String kind;
  final double faceValue;
  final String currency;

  /// Fulfilment target — a Roblox username for Robux, an email for cards.
  final String? robloxUsername;
  final String? email;

  /// The gift-card code, once an admin has delivered it. Readable only by the
  /// owning user (see `firestore.rules`).
  final String? deliveredCode;
  final String? adminNote;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  bool get hasCode => (deliveredCode ?? '').isNotEmpty;

  @override
  List<Object?> get props => [id, status, deliveredCode, updatedAt];
}
