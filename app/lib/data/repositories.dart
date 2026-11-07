import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

/// Everything the app shows about one kitchen.
final class KitchenData extends Equatable {
  const KitchenData({
    required this.kitchen,
    required this.state,
    required this.tags,
    required this.isSynced,
  });

  final Kitchen kitchen;
  final KitchenState state;
  final IList<Tag> tags;

  /// False while any of this comes from the local cache. Housekeeping that
  /// treats missing data as gone, like clearing, waits for this.
  final bool isSynced;

  @override
  List<Object> get props => [kitchen, state, tags, isSynced];
}

/// The kitchen doesn't exist (any more), or this user is no longer in it:
/// either way, it can only be forgotten.
final class KitchenGone implements Exception {
  const KitchenGone();
}

/// The data of a kitchen.
abstract interface class KitchenRepository {
  /// A live view of the kitchen. Works offline, from the local cache.
  ///
  /// Ends with an error when the kitchen can't be followed any further:
  /// [KitchenGone] when it is gone or the user was taken off it.
  Stream<KitchenData> watch(String kitchenId);

  /// Applies the effects of one decision. An effect on a document that has
  /// disappeared does nothing, and doesn't hold back the others.
  ///
  /// Completes when the server has it all, which doesn't happen while offline,
  /// so user actions don't wait for it. The effects are visible in [watch]
  /// right away.
  Future<void> apply(String kitchenId, Iterable<Effect> effects);

  /// An ID for a new document.
  String newId();

  /// A URL for a recipe photo in storage.
  Future<String> photoUrl(String storagePath);
}

final class AppUser extends Equatable {
  const AppUser({required this.id, this.name, this.photoUrl});

  final String id;
  final String? name;
  final String? photoUrl;

  @override
  List<Object?> get props => [id, name, photoUrl];
}

/// Signing in, and membership of kitchens.
abstract interface class AccountRepository {
  /// The signed-in user, or null.
  Stream<AppUser?> watchUser();

  /// The kitchens [userId] belongs to.
  Stream<IList<String>> watchKitchenIds(String userId);

  Future<void> signInWithGoogle();
  Future<void> signOut();

  Future<String> createKitchen({
    required String name,
    required String language,
  });

  /// A token for joining [kitchenId], valid for a week.
  Future<String> createInvite(String kitchenId);

  /// Joins the kitchen of an invite, and returns its ID.
  Future<String> acceptInvite(String token);

  Future<void> leaveKitchen(String kitchenId);

  /// Takes a kitchen that is gone, or that the user was taken off, off the
  /// user's list. Never deletes anything; refused while still a member.
  Future<void> forgetKitchen(String kitchenId);
  Future<void> transferOwnership(String kitchenId, String newOwnerId);
  Future<void> deleteAccount();
}
