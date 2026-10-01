import 'dart:convert';
import 'dart:io';

import 'package:driver/core/interceptors/base_url_interceptor.dart';
import 'package:driver/core/interceptors/header_interceptor.dart';
import 'package:driver/core/interceptors/logging_interceptor.dart';
import 'package:driver/core/preferences/shared_preference_manager.dart';
import 'package:driver/core/utils/validator/validator.dart';
import 'package:driver/data/api/api_client.dart';
import 'package:driver/data/api/response_state.dart';
import 'package:driver/data/repository/app_repository.dart';
import 'package:driver/models/responses/base/error_response.dart';
import 'package:driver/features/at_ai_driver/data/ai_driver_document_submission_gateway.dart';
import 'package:driver/features/at_ai_driver/models/ai_driver_document_draft.dart';
import 'package:driver/features/at_ai_driver/models/ai_driver_registration_draft.dart';
import 'package:driver/models/responses/document/document_response.dart';
import 'package:driver/viewmodels/auth/register_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CapturingMultipartClient extends http.BaseClient {
  http.MultipartRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.MultipartRequest) {
      lastRequest = request;
    }

    final payload = jsonEncode({'documentStatus': 20});
    return http.StreamedResponse(
      Stream.value(utf8.encode(payload)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _RetryRepository extends AppRepository {
  final uploads = <String>[];
  bool failInsurance = true;

  _RetryRepository(SharedPreferenceManager preferences)
    : super(
        ApiClient(
          BaseUrlInterceptor('https://example.com'),
          HeaderInterceptor(preferences),
          LoggingInterceptor(),
        ),
      );

  @override
  Future<ResponseState<DocumentListResponse>> getDocuments({
    String? authorization,
  }) async => Success(
    data: DocumentListResponse(
      documents: [
        Document(
          documentId: 'core_license',
          documentDetail: DocumentDetail(name: 'Driver License'),
        ),
        Document(
          documentId: 'core_insurance',
          documentDetail: DocumentDetail(name: 'Insurance'),
        ),
      ],
    ),
  );

  @override
  Future<ResponseState<UploadDocumentResponse>> uploadDocument({
    required String documentId,
    String? filePath,
    String? expiryDate,
    String? uniqueCode,
    String? authorization,
  }) async {
    uploads.add(documentId);
    if (documentId == 'core_insurance' && failInsurance) {
      return Error(
        responseCode: 400,
        error: ErrorResponse(message: 'Temporary upload error'),
      );
    }
    return Success(data: UploadDocumentResponse(documentStatus: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses the server phone length rules for login validation', () {
    ValidatorConfig.phoneNumberMinLength = 8;
    ValidatorConfig.phoneNumberMaxLength = 10;

    expect('1234567'.isValidPhoneNumberForLogin(), isFalse);
    expect('12345678'.isValidPhoneNumberForLogin(), isTrue);
    expect('1234567890'.isValidPhoneNumberForLogin(), isTrue);
    expect('12345678901'.isValidPhoneNumberForLogin(), isFalse);
  });

  test('collects only document IDs that have a file to upload', () {
    final draft = AiDriverRegistrationDraft.create().copyWith(
      documents: [
        const AiDriverDocumentDraft(
          id: 'driver_license',
          title: 'Driver license',
          description: 'Front side',
          localFilePath: '/tmp/driver_license.jpg',
        ),
        const AiDriverDocumentDraft(
          id: 'email',
          title: 'Email',
          description: 'Email field',
        ),
        const AiDriverDocumentDraft(
          id: 'insurance',
          title: 'Insurance policy',
          description: 'Policy file',
          localFilePath: '/tmp/insurance.pdf',
        ),
      ],
    );

    expect(collectUploadableDocumentIds(draft), [
      'driver_license',
      'insurance',
    ]);
  });

  test('resolves server document IDs using backend metadata', () {
    final remoteDocuments = [
      Document(
        documentId: 'doc_driver_license_012',
        documentDetail: DocumentDetail(
          name: 'Driver License',
          title: 'Driver License',
        ),
      ),
      Document(
        documentId: 'doc_insurance_999',
        documentDetail: DocumentDetail(
          name: 'Insurance Policy',
          title: 'Insurance Policy',
        ),
      ),
    ];

    expect(
      resolveDocumentIdForAiDriver(
        localDocumentId: 'driver_license',
        remoteDocuments: remoteDocuments,
      ),
      'doc_driver_license_012',
    );

    expect(
      resolveDocumentIdForAiDriver(
        localDocumentId: 'insurance',
        remoteDocuments: remoteDocuments,
      ),
      'doc_insurance_999',
    );
  });

  test('never invents a Core document ID for an unknown local file', () {
    expect(
      resolveDocumentIdForAiDriver(
        localDocumentId: 'diamond_sticker',
        remoteDocuments: [],
      ),
      isEmpty,
    );
  });

  test(
    'uploaded document progress survives draft serialization and a new photo resets it',
    () {
      final uploaded = const AiDriverDocumentDraft(
        id: 'driver_license',
        title: 'License',
        description: 'Photo',
        localFilePath: '/tmp/license.jpg',
      ).markUploaded();
      final draft = AiDriverRegistrationDraft.create().copyWith(
        documents: [uploaded],
        phase: 'awaitingRegistration',
      );
      final restored = AiDriverRegistrationDraft.fromJson(draft.toJson());
      expect(restored.documents.single.uploadStatus, 'uploaded');
      expect(restored.phase, 'awaitingRegistration');
      expect(
        restored.documents.single
            .copyWith(localFilePath: '/tmp/new.jpg')
            .uploadStatus,
        'notSubmitted',
      );
    },
  );

  test(
    'document submission stops when Core has no matching document type',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferenceManager.create();
      var uploadCount = 0;
      final repository = AppRepository(
        ApiClient(
          BaseUrlInterceptor('https://example.com'),
          HeaderInterceptor(preferences),
          LoggingInterceptor(),
          httpClient: MockClient((request) async {
            if (request.method == 'PUT') uploadCount++;
            return http.Response(
              jsonEncode({
                'data': {'documents': <Object>[]},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      final dir = await Directory.systemTemp.createTemp('ai_core_mapping_test');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/sticker.jpg');
      await file.writeAsBytes([1, 2, 3]);
      final draft = AiDriverRegistrationDraft.create().copyWith(
        documents: [
          AiDriverDocumentDraft(
            id: 'diamond_sticker',
            title: 'FHV diamond sticker',
            description: 'Photo',
            localFilePath: file.path,
          ),
        ],
      );
      await expectLater(
        AppRepositoryAiDriverDocumentSubmissionGateway(
          repository,
        ).submit(draft),
        throwsA(isA<StateError>()),
      );
      expect(uploadCount, 0);
    },
  );

  test('partial Core upload retries only the remaining document', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferenceManager.create();
    final repository = _RetryRepository(preferences);
    final dir = await Directory.systemTemp.createTemp('ai_partial_upload_test');
    addTearDown(() => dir.delete(recursive: true));
    final license = File('${dir.path}/license.jpg');
    final insurance = File('${dir.path}/insurance.jpg');
    await license.writeAsBytes([1, 2, 3]);
    await insurance.writeAsBytes([4, 5, 6]);
    var draft = AiDriverRegistrationDraft.create().copyWith(
      documents: [
        AiDriverDocumentDraft(
          id: 'driver_license',
          title: 'Driver License',
          description: 'Photo',
          localFilePath: license.path,
        ),
        AiDriverDocumentDraft(
          id: 'insurance',
          title: 'Insurance',
          description: 'Photo',
          localFilePath: insurance.path,
        ),
      ],
    );
    final gateway = AppRepositoryAiDriverDocumentSubmissionGateway(repository);
    Future<void> record(String id) async {
      draft = draft.replaceDocument(
        draft.documents.firstWhere((item) => item.id == id).markUploaded(),
      );
    }

    await expectLater(
      gateway.submit(draft, onUploaded: record),
      throwsA(isA<StateError>()),
    );
    expect(draft.documents.first.uploadStatus, 'uploaded');
    expect(repository.uploads.where((id) => id == 'core_license').length, 1);
    repository.failInsurance = false;
    await gateway.submit(draft, onUploaded: record);
    expect(repository.uploads.where((id) => id == 'core_license').length, 1);
    expect(repository.uploads.where((id) => id == 'core_insurance').length, 2);
    expect(
      draft.documents.every((item) => item.uploadStatus == 'uploaded'),
      isTrue,
    );
  });

  test('prefers the server document id when uploading a document', () {
    final document = Document(
      documentId: 'server_doc_123',
      id: 'local_doc_456',
    );

    expect(resolveDocumentUploadId(document), 'server_doc_123');
  });

  test(
    'builds a multipart document upload request with the imageUrl field name',
    () async {
      SharedPreferences.setMockInitialValues({});

      final sharedPref = await SharedPreferenceManager.create();
      final apiClient = ApiClient(
        BaseUrlInterceptor('https://example.com'),
        HeaderInterceptor(sharedPref),
        LoggingInterceptor(),
      );

      final tempDir = await Directory.systemTemp.createTemp(
        'document_upload_test',
      );
      final tempFile = File('${tempDir.path}/license.jpg');
      await tempFile.writeAsBytes([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);

      final request = await apiClient.createMultipartRequest(
        'uploaded_document/server_doc_123',
        filePath: tempFile.path,
        fileFieldName: 'imageUrl',
        headers: {'Accept': 'application/json'},
        fields: {'expiryDate': '2030-01-01'},
      );

      expect(request.method, 'PUT');
      expect(request.url.path, endsWith('/uploaded_document/server_doc_123'));
      expect(request.files.single.field, 'imageUrl');
      expect(request.fields['expiryDate'], '2030-01-01');

      await tempFile.delete();
      await tempDir.delete();
    },
  );

  test(
    'skips the duplicate name step when AI-driver prefill already has a name',
    () async {
      SharedPreferences.setMockInitialValues({});
      final sharedPref = await SharedPreferenceManager.create();
      final repository = AppRepository(
        ApiClient(
          BaseUrlInterceptor('https://example.com'),
          HeaderInterceptor(sharedPref),
          LoggingInterceptor(),
        ),
      );

      final viewModel = RegisterViewModel(repository, sharedPref);
      viewModel.applyConfirmedPrefill(
        const ConfirmedRegistrationPrefill(firstName: 'John', lastName: 'Doe'),
      );

      expect(viewModel.state.currentStep, RegisterStep.terms);
      expect(viewModel.state.firstName, 'John');
      expect(viewModel.state.lastName, 'Doe');
    },
  );

  testWidgets(
    'review photo dialog renders without intrinsic-width layout crash',
    (tester) async {
      final tempDir = await Directory.systemTemp.createTemp(
        'review_photo_dialog_test',
      );
      final imageFile = File('${tempDir.path}/review_photo.png');
      await imageFile.writeAsBytes([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x10,
        0x00,
        0x00,
        0x00,
        0x10,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0xF3,
        0xFF,
        0xF3,
        0x00,
        0x00,
        0x00,
        0x06,
        0x50,
        0x4C,
        0x54,
        0x45,
        0x00,
        0x00,
        0x00,
        0xFF,
        0x00,
        0x00,
        0xFF,
        0x00,
        0x00,
        0x00,
        0xFF,
        0x00,
        0x00,
        0xFF,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]);

      addTearDown(() async {
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Review photo'),
                        content: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: SizedBox(
                            width: 280,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 280,
                                  height: 240,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      imageFile,
                                      width: 280,
                                      height: 240,
                                      fit: BoxFit.cover,
                                      cacheWidth: 280,
                                      cacheHeight: 240,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Make sure the document is clear and readable.',
                                ),
                              ],
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Retake'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Looks good'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Open dialog'),
                );
              },
            ),
          ),
        ),
      );

      print('before open dialog tap');
      await tester.tap(find.text('Open dialog'));
      await tester.pump();
      print('after open dialog pump');

      expect(find.text('Review photo'), findsOneWidget);

      print('before looks good tap');
      await tester.tap(find.text('Looks good'));
      await tester.pump();
      print('after looks good pump');

      expect(find.text('Review photo'), findsNothing);
    },
  );
}
