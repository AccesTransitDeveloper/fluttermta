import '../../../core/preferences/shared_preference_manager.dart';
import '../../../data/repository/app_repository.dart';
import '../../../models/responses/auth/entity_detail_response.dart';
import '../models/ai_driver_registration_draft.dart';
import 'ai_driver_document_submission_gateway.dart';
import 'ai_driver_draft_store.dart';

/// The pre-registration draft stays in its email/phone scope until Core has
/// created and authenticated the driver. Never use the token-scoped store here.
class PendingAiDriverDocuments {
  final AiDriverDraftStore store;
  AiDriverRegistrationDraft draft;

  PendingAiDriverDocuments(this.store, this.draft);

  bool get hasPendingFiles => draft.documents.any(
    (item) => item.isCollected && item.uploadStatus != 'uploaded',
  );

  static Future<PendingAiDriverDocuments?> forEntity(Entity entity) async {
    final identities = <String>[
      if (entity.email?.trim().isNotEmpty == true) entity.email!,
      if (entity.phone?.trim().isNotEmpty == true)
        '${entity.countryPhoneCode ?? ''}:${entity.phone}',
    ];
    for (final identity in identities) {
      final store = await AiDriverDraftStore.forRegistrationIdentity(identity);
      final draft = await store.loadExisting();
      if (draft != null &&
          (draft.phase == 'awaitingRegistration' ||
              draft.phase == 'submitted')) {
        return PendingAiDriverDocuments(store, draft);
      }
    }
    return null;
  }

  Future<void> submit(
    AppRepository repository,
    SharedPreferenceManager preferences, {
    void Function(AiDriverRegistrationDraft draft)? onProgress,
  }) async {
    final entity = preferences.getEntity();
    if (preferences.getAuthorization()?.isNotEmpty != true ||
        entity?.id?.isNotEmpty != true) {
      throw StateError(
        'Your Core account was created, but you must sign in before sending documents.',
      );
    }
    final emailMatches =
        draft.email.trim().isNotEmpty &&
        entity!.email?.trim().toLowerCase() == draft.email.trim().toLowerCase();
    final phoneMatches =
        draft.phone.trim().isNotEmpty &&
        entity!.phone?.trim() == draft.phone.trim();
    if (!emailMatches && !phoneMatches) {
      throw StateError(
        'This document draft belongs to a different driver. '
        'Sign in with the registration account.',
      );
    }
    if (!hasPendingFiles) return;

    final authorization = preferences.getAuthorization()!;
    final coreDriverId = entity.id!;
    Future<void> ensureSameSession() async {
      if (!preferences.isLoggedIn() ||
          preferences.getAuthorization() != authorization ||
          preferences.getEntity()?.id != coreDriverId) {
        throw StateError(
          'The Core account changed during upload. Sign in to the original '
          'driver account and retry; no further files were sent.',
        );
      }
    }

    final gateway = AppRepositoryAiDriverDocumentSubmissionGateway(repository);
    await gateway.submit(
      draft,
      authorization: authorization,
      ensureSameSession: ensureSameSession,
      onUploaded: (documentId) async {
        draft = draft.replaceDocument(
          draft.documents
              .firstWhere((item) => item.id == documentId)
              .markUploaded(),
        );
        await store.save(draft);
        onProgress?.call(draft);
      },
      onUncertain: (documentId) async {
        draft = draft.replaceDocument(
          draft.documents
              .firstWhere((item) => item.id == documentId)
              .markUncertain(),
        );
        await store.save(draft);
        onProgress?.call(draft);
      },
    );
    draft = draft.copyWith(phase: 'submitted');
    await store.save(draft);
    onProgress?.call(draft);
  }
}
