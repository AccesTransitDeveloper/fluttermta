import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/router/app_navigation.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/api/server_config.dart';
import '../../../models/responses/document/document_response.dart';
import '../../../models/webview_data_model.dart';
import '../../../viewmodels/document_viewmodel.dart';
import '../../../viewmodels/home_viewmodel.dart';
import '../../../core/constants/app_constants.dart' show VehicleStatus;
import '../../../core/providers/app_providers.dart';
import '../../../data/api/response_state.dart';
import '../../../features/at_ai_driver/data/pending_ai_driver_documents.dart';
import '../../../models/responses/home/information_status_response.dart';
import '../../bottomsheets/document_edit_bottom_sheet.dart';
import '../../item/document_grid_item.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_text.dart';
import '../../widgets/app_toolbar.dart';

class DocumentScreen extends ConsumerStatefulWidget {
  const DocumentScreen({super.key});

  @override
  ConsumerState<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends ConsumerState<DocumentScreen> {
  PendingAiDriverDocuments? _pending;
  InformationStatus? _coreStatus;
  String? _submissionError;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _refreshOnboarding();
  }

  Future<void> _refreshOnboarding() async {
    try {
      final preferences = await ref.read(
        sharedPreferenceManagerProvider.future,
      );
      final entity = preferences.getEntity();
      final pending = entity == null
          ? null
          : await PendingAiDriverDocuments.forEntity(entity);
      final response = await ref
          .read(appRepositoryProvider)
          .getInformationStatus();
      if (!mounted) return;
      setState(() {
        _pending = pending;
        _coreStatus = response is Success<InformationStatusResponse>
            ? response.data?.informationStatus
            : null;
        _submissionError = response is Error
            ? 'Could not check Core review status. Pull down to retry.'
            : null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _submissionError =
              'Could not load saved documents or Core review status.',
        );
      }
    }
  }

  Future<void> _sendPending() async {
    final pending = _pending;
    if (pending == null || _sending) return;
    setState(() {
      _sending = true;
      _submissionError = null;
    });
    try {
      final preferences = await ref.read(
        sharedPreferenceManagerProvider.future,
      );
      await pending.submit(
        ref.read(appRepositoryProvider),
        preferences,
        onProgress: (_) {
          if (mounted) setState(() {});
        },
      );
      await ref.read(documentViewModelProvider.notifier).refresh();
      await _refreshOnboarding();
    } catch (error) {
      if (mounted) {
        setState(
          () => _submissionError = error is StateError
              ? error.message
              : 'Document submission failed. Retry later.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _buildOnboarding() {
    final pending = _pending;
    if (pending == null && _coreStatus == null && _submissionError == null) {
      return const SizedBox.shrink();
    }
    final status = _coreStatus;
    final approved =
        status?.documentStatus == DocumentStatus.accepted.value &&
        status?.vehicleDocumentStatus == DocumentStatus.accepted.value &&
        status?.vehicleApprovalStatus == VehicleStatus.approved &&
        status?.profileStatus == true &&
        status?.countryStatus == true &&
        status?.cityStatus == true &&
        status?.vehicleStatus == true &&
        const {
          EntityStatus.approve,
          EntityStatus.offline,
          EntityStatus.available,
          EntityStatus.inBooking,
          EntityStatus.availableForShare,
          EntityStatus.nearAvailable,
        }.contains(
          ref
              .read(sharedPreferenceManagerProvider)
              .maybeWhen(
                data: (prefs) => prefs.getEntity()?.status,
                orElse: () => null,
              ),
        );
    final rejected =
        status?.documentStatus == DocumentStatus.rejected.value ||
        status?.vehicleDocumentStatus == DocumentStatus.rejected.value;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approved
                  ? 'Core approved your driver documents'
                  : rejected
                  ? 'Core rejected a document. Review it below and upload a correction.'
                  : status == null
                  ? 'Core review status unavailable'
                  : 'Core review pending',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (pending != null) ...[
              const SizedBox(height: 8),
              ...pending.draft.documents
                  .where((doc) => doc.isCollected)
                  .map(
                    (doc) => Text(
                      '${doc.uploadStatus == 'uploaded'
                          ? 'Sent'
                          : doc.uploadStatus == 'uncertain'
                          ? 'Checking Core'
                          : 'On this device'}: ${doc.title}',
                    ),
                  ),
              if (pending.hasPendingFiles) ...[
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _sending ? null : _sendPending,
                  child: Text(
                    _sending ? 'Sending to Core…' : 'Send remaining documents',
                  ),
                ),
              ] else if (pending.draft.phase != 'submitted') ...[
                const Text(
                  'Some saved files are missing from this device. '
                  'Open each missing item below to select it again.',
                ),
              ],
            ],
            if (status != null &&
                !approved &&
                !rejected &&
                pending?.draft.phase == 'submitted')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Sent files await Core approval. Pull down to refresh.',
                ),
              ),
            if (_submissionError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _submissionError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            TextButton(
              onPressed: _refreshOnboarding,
              child: const Text('Refresh Core review status'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentViewModelProvider);

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppToolbar(
              title: getString(appStr.headingDocument, 'heading_document'),
            ),
            _buildOnboarding(),
            Expanded(child: _buildBody(context, ref, state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, DocumentState state) {
    final colors = context.colors;

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.colorText),
            const SizedBox(height: AppDimens.padding),
            AppText.body(state.error!, color: colors.colorText),
            TextButton(
              onPressed: () =>
                  ref.read(documentViewModelProvider.notifier).refresh(),
              child: const Text('Retry document list'),
            ),
          ],
        ),
      );
    }

    final documents = state.documents;
    if (documents == null || documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_outlined, size: 64, color: colors.colorText),
            const SizedBox(height: AppDimens.padding),
            AppText.body(
              getString(appStr.errorNoDocumentFound, 'error_no_document_found'),
              color: colors.colorText,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.read(documentViewModelProvider.notifier).refresh(),
          _refreshOnboarding(),
        ]);
      },
      child: MasonryGridView.count(
        padding: const EdgeInsets.all(AppDimens.padding),
        crossAxisCount: 2,
        mainAxisSpacing: AppDimens.paddingM,
        crossAxisSpacing: AppDimens.paddingM,
        itemCount: documents.length,
        itemBuilder: (context, index) {
          final doc = documents[index];
          return DocumentGridItem(
            document: doc,
            onTap: () => _showEditBottomSheet(context, ref, doc),
            onImageTap: () => _openDocument(context, doc),
          );
        },
      ),
    );
  }

  void _openDocument(BuildContext context, Document document) {
    final imageUrl = document.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return;

    final fullUrl = ServerConfig.getFullImageUrl(imageUrl);
    final isPdf = fullUrl.toLowerCase().endsWith('.pdf');

    if (isPdf) {
      context.navigateToWebView(
        webViewData: WebViewDataModel(webURL: fullUrl, webContent: null),
      );
    } else {
      context.navigateToImageViewer(imageUrl: fullUrl);
    }
  }

  void _showEditBottomSheet(
    BuildContext context,
    WidgetRef ref,
    Document document,
  ) {
    DocumentEditBottomSheet.show(
      context: context,
      document: document,
      onSubmit:
          ({
            required String documentId,
            String? filePath,
            String? expiryDate,
            String? uniqueCode,
          }) async {
            return ref
                .read(documentViewModelProvider.notifier)
                .uploadDocument(
                  documentId: documentId,
                  filePath: filePath,
                  expiryDate: expiryDate,
                  uniqueCode: uniqueCode,
                );
          },
    );
  }
}
