import 'dart:io';

import '../../../data/api/response_state.dart';
import '../../../data/repository/app_repository.dart';
import '../../../models/responses/document/document_response.dart';
import '../models/ai_driver_registration_draft.dart';

String _normalizeServerName(String? value) {
  return (value ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '')
      .trim();
}

String resolveDocumentIdForAiDriver({
  required String localDocumentId,
  required List<Document> remoteDocuments,
}) {
  for (final document in remoteDocuments) {
    final serverId = document.documentId ?? document.id;
    if (serverId != null &&
        _normalizeServerName(serverId) ==
            _normalizeServerName(localDocumentId)) {
      return serverId;
    }
  }

  final localNormalized = _normalizeServerName(localDocumentId);
  for (final document in remoteDocuments) {
    final candidates = <String?>[
      document.documentId,
      document.id,
      document.documentDetail?.name,
      document.documentDetail?.title,
      document.documentDetail?.description,
    ];

    for (final candidate in candidates) {
      if (candidate != null &&
          _normalizeServerName(candidate) == localNormalized) {
        final serverId = document.documentId ?? document.id;
        if (serverId != null && serverId.isNotEmpty) {
          return serverId;
        }
      }
    }
  }

  for (final document in remoteDocuments) {
    final title = _normalizeServerName(
      document.documentDetail?.name ?? document.documentDetail?.title,
    );
    final localName = _normalizeServerName(localDocumentId);
    if (title.isNotEmpty && title.contains(localName)) {
      final serverId = document.documentId ?? document.id;
      if (serverId != null && serverId.isNotEmpty) {
        return serverId;
      }
    }
    if (localName.contains(title) && title.isNotEmpty) {
      final serverId = document.documentId ?? document.id;
      if (serverId != null && serverId.isNotEmpty) {
        return serverId;
      }
    }
  }

  return '';
}

List<String> collectUploadableDocumentIds(AiDriverRegistrationDraft draft) {
  return draft.documents
      .where(
        (document) =>
            document.localFilePath != null &&
            document.localFilePath!.trim().isNotEmpty,
      )
      .map((document) => document.id)
      .toList(growable: false);
}

/// Boundary for AT AI Driver document submission.
abstract interface class AiDriverDocumentSubmissionGateway {
  Future<void> submit(
    AiDriverRegistrationDraft draft, {
    Future<void> Function(String documentId)? onUploaded,
    Future<void> Function(String documentId)? onUncertain,
    String? authorization,
    Future<void> Function()? ensureSameSession,
  });
}

class AppRepositoryAiDriverDocumentSubmissionGateway
    implements AiDriverDocumentSubmissionGateway {
  final AppRepository _appRepository;

  const AppRepositoryAiDriverDocumentSubmissionGateway(this._appRepository);

  @override
  Future<void> submit(
    AiDriverRegistrationDraft draft, {
    Future<void> Function(String documentId)? onUploaded,
    Future<void> Function(String documentId)? onUncertain,
    String? authorization,
    Future<void> Function()? ensureSameSession,
  }) async {
    final uploadableIds = draft.documents
        .where((item) => item.isCollected && item.uploadStatus != 'uploaded')
        .map((item) => item.id)
        .toList();
    if (uploadableIds.isEmpty) {
      return;
    }

    await ensureSameSession?.call();
    final remoteDocumentsResponse = await _appRepository.getDocuments(
      authorization: authorization,
    );
    final remoteDocuments = switch (remoteDocumentsResponse) {
      Success<DocumentListResponse>() =>
        remoteDocumentsResponse.data?.documents ??
            (throw StateError(
              'Core returned no document list. Try again later.',
            )),
      Error() => throw StateError(
        'Could not load Core document types: ${remoteDocumentsResponse.error?.message ?? 'please try again.'}',
      ),
      Loading() => throw StateError('Core document types are still loading.'),
    };

    for (final localDocumentId in uploadableIds) {
      await ensureSameSession?.call();
      final document = draft.documents.firstWhere(
        (item) => item.id == localDocumentId,
      );
      final filePath = document.localFilePath;
      if (filePath == null || filePath.trim().isEmpty) {
        continue;
      }
      final file = File(filePath);
      if (!file.existsSync()) {
        throw StateError(
          'The selected document file is missing and cannot be uploaded: $filePath',
        );
      }

      final resolvedDocumentId = resolveDocumentIdForAiDriver(
        localDocumentId: localDocumentId,
        remoteDocuments: remoteDocuments,
      );
      if (resolvedDocumentId.isEmpty) {
        throw StateError(
          'Core has no matching document type for "${document.title}". '
          'This file remains on your device. Complete this item in the '
          'Core Documents section when its document type is available.',
        );
      }
      final remote = remoteDocuments.where(
        (item) => (item.documentId ?? item.id) == resolvedDocumentId,
      );
      final detail = remote.isEmpty ? null : remote.first.documentDetail;
      if (remote.isNotEmpty &&
          remote.first.imageUrl?.isNotEmpty == true &&
          (remote.first.status == 20 || remote.first.status == 30)) {
        // A previous PUT may have succeeded while its response was lost.
        await ensureSameSession?.call();
        await onUploaded?.call(localDocumentId);
        continue;
      }
      if (document.uploadStatus == 'uncertain') {
        throw StateError(
          '${document.title}: Core has not confirmed whether the previous '
          'upload succeeded. Check Documents again later; this file will '
          'not be resent automatically.',
        );
      }
      if (detail?.isExpiry == true || detail?.isUniqueCode == true) {
        throw StateError(
          '${document.title}: Core requires an expiry date or unique code. '
          'Open this item in Documents to complete its required fields.',
        );
      }

      final response = await _appRepository.uploadDocument(
        documentId: resolvedDocumentId,
        filePath: filePath,
        authorization: authorization,
      );
      await ensureSameSession?.call();

      switch (response) {
        case Success():
          await onUploaded?.call(localDocumentId);
          continue;
        case Error():
          if (response.responseCode == null || response.responseCode! >= 500) {
            await onUncertain?.call(localDocumentId);
          }
          throw StateError(
            '${document.title}: ${response.error?.message ?? 'upload failed. Try again.'}',
          );
        case Loading():
          throw StateError('${document.title}: upload is still in progress.');
      }
    }
  }
}

class DisabledAiDriverDocumentSubmissionGateway
    implements AiDriverDocumentSubmissionGateway {
  const DisabledAiDriverDocumentSubmissionGateway();

  @override
  Future<void> submit(
    AiDriverRegistrationDraft draft, {
    Future<void> Function(String documentId)? onUploaded,
    Future<void> Function(String documentId)? onUncertain,
    String? authorization,
    Future<void> Function()? ensureSameSession,
  }) {
    return Future.value();
  }
}
