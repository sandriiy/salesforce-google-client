/**
 * MIT License
 *
 * Copyright (c) 2026 Andrii Sukhetskyi
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
@IsTest
private class GoogleFileFolderStructureCommandTest {
	private static final String ROOT_FOLDER_ID = 'ROOT_FOLDER_01';
	private static final String CACHED_FOLDER_ID = 'CACHED_FOLDER_01';
	private static final String FOUND_FOLDER_ID = 'FOUND_FOLDER_01';
	private static final String CREATED_FOLDER_ID = 'gfile_small_001';
	private static final String USER_FOLDER_ID = 'USER_FOLDER_01';
	private static final String RECORD_FOLDER_ID = 'RECORD_FOLDER_01';
	private static final String RECORD_NAME = 'Acme Brochure';
	private static final String TODAYS_RECORD_FOLDER_NAME = 'GoogleFile__c : Acme Brochure';
	private static final String PATTERN_WITH_SOURCE = 'Name & " - " & TEXT(Source__c)';
	private static final String DRIVE_SERVER_ERROR_BODY = '{"error":{"code":500,"message":"Internal Error","errors":[{"domain":"global","reason":"internalError","message":"Internal Error"}]}}';
	private static final String DRIVE_NOT_FOUND_BODY = '{"error":{"code":404,"message":"File not found.","errors":[{"domain":"global","reason":"notFound","message":"File not found."}]}}';

	private static GoogleClientConfig__mdt buildFolderConfig(String uploadFolderId, String folderStructure) {
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = uploadFolderId;
		config.CustomGoogleUploadFolderStructure__c = folderStructure;
		return config;
	}

	private static GoogleDriveHttpMock buildMissingFolderMock() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[]}');
		return driveMock;
	}

	private static GoogleDriveHttpMock buildExistingFolderMock(String folderId) {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[{"id":"' + folderId + '","name":"Existing Folder"}]}');
		return driveMock;
	}

	private static GoogleDriveHttpMock buildDuplicateFoldersMock(List<String> folderIds) {
		List<String> serializedFolders = new List<String>();
		for (String folderId : folderIds) {
			serializedFolders.add('{"id":"' + folderId + '","name":"Duplicate Folder"}');
		}

		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[' + String.join(serializedFolders, ',') + ']}');
		return driveMock;
	}

	private static GoogleClientConfig__mdt buildRenameConfig(String folderStructure, Boolean isRenameEnabled, String patternsJson) {
		GoogleClientConfig__mdt config = buildFolderConfig(ROOT_FOLDER_ID, folderStructure);
		config.IsFolderRenameEnabled__c = isRenameEnabled;
		config.RecordFolderNamePatterns__c = patternsJson;
		return config;
	}

	private static String patternRows(String objectApiName, String pattern) {
		return JSON.serialize(new List<Map<String, String>>{
			new Map<String, String>{ 'objectApiName' => objectApiName, 'pattern' => pattern }
		});
	}

	private static GoogleFile__c insertRecord(String recordName) {
		return GoogleCloudTestFactory.file().withName(recordName).withSource('Migration').insertRecord();
	}

	private static String todaysUserFolderName() {
		List<String> nameParts = new List<String>();
		if (String.isNotBlank(UserInfo.getFirstName())) nameParts.add(UserInfo.getFirstName());
		if (String.isNotBlank(UserInfo.getLastName())) nameParts.add(UserInfo.getLastName());
		return 'User : ' + String.join(nameParts, ' ');
	}

	private static void cacheFolder(String parentFolderId, Id uniqueId, String folderId) {
		GoogleCacheDriveFolderService folderCache = new GoogleCacheDriveFolderService();
		folderCache.putFolderId(folderCache.buildFolderKey(parentFolderId, uniqueId), folderId);
	}

	private static String cachedFolderId(String parentFolderId, Id uniqueId) {
		GoogleCacheDriveFolderService folderCache = new GoogleCacheDriveFolderService();
		return folderCache.getFolderId(folderCache.buildFolderKey(parentFolderId, uniqueId));
	}

	private static void answerFolderName(GoogleDriveHttpMock driveMock, String folderId, String folderName) {
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('/files/' + folderId)
		).thenReturnStatus(200, JSON.serialize(new Map<String, String>{ 'id' => folderId, 'name' => folderName }));
	}

	private static void answerRename(GoogleDriveHttpMock driveMock, String folderId, Integer statusCode, String body) {
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('PATCH')
				.endpointContains('/files/' + folderId)
		).thenReturnStatus(statusCode, body);
	}

	private static void answerSearch(GoogleDriveHttpMock driveMock, String folderId, String folderName) {
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[' + JSON.serialize(new Map<String, String>{ 'id' => folderId, 'name' => folderName }) + ']}');
	}

	private static GoogleDriveHttpMock buildCachedFolderMock(String folderId, String currentName) {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		answerFolderName(driveMock, folderId, currentName);
		answerRename(driveMock, folderId, 200, JSON.serialize(new Map<String, String>{ 'id' => folderId }));
		return driveMock;
	}

	private static List<GoogleDriveHttpMock.CapturedRequest> requestsTo(GoogleDriveHttpMock driveMock, String method, String folderId) {
		List<GoogleDriveHttpMock.CapturedRequest> matchingRequests = new List<GoogleDriveHttpMock.CapturedRequest>();
		String folderPath = ('/files/' + folderId).toLowerCase();
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			String endpoint = capturedRequest.endpoint == null ? '' : capturedRequest.endpoint.toLowerCase();
			if (capturedRequest.method == method && endpoint.contains(folderPath)) matchingRequests.add(capturedRequest);
		}

		return matchingRequests;
	}

	private static String renameBody(GoogleDriveHttpMock driveMock, String folderId) {
		List<GoogleDriveHttpMock.CapturedRequest> renames = requestsTo(driveMock, 'PATCH', folderId);
		return renames.isEmpty() || renames[0].body == null ? '' : renames[0].body;
	}

	private static String createdFolderBody(GoogleDriveHttpMock driveMock) {
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			String endpoint = capturedRequest.endpoint == null ? '' : capturedRequest.endpoint.toLowerCase();
			if (capturedRequest.method == 'POST' && endpoint.contains('uploadtype=multipart')) {
				return capturedRequest.body == null ? '' : capturedRequest.body;
			}
		}

		return '';
	}

	private static List<String> loggedEntries(List<String> loggedFailures, String level) {
		List<String> entries = new List<String>();
		if (loggedFailures == null) return entries;

		for (String entry : loggedFailures) {
			if (entry != null && entry.startsWith(level + ' ')) entries.add(entry);
		}

		return entries;
	}

	@IsTest
	private static void testEnsureFolderPositiveBlankStructure() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '');

		Id linkedRecordId = GoogleCloudTestFactory.linkedRecord('Blank Structure Record');

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(linkedRecordId);
		Test.stopTest();

		Assert.areEqual(null, folderId);
	}

	@IsTest
	private static void testEnsureFolderPositiveUserStructure() {
		GoogleCloudTestFactory.initMocks(buildMissingFolderMock());
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{User}');

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(null);
		Test.stopTest();

		Assert.isNotNull(folderId);
	}

	@IsTest
	private static void testEnsureFolderPositiveRecordStructure() {
		GoogleCloudTestFactory.initMocks(buildMissingFolderMock());
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');

		Id linkedRecordId = GoogleCloudTestFactory.linkedRecord('Record Structure Record');

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(linkedRecordId);
		Test.stopTest();

		Assert.isNotNull(folderId);
	}

	@IsTest
	private static void testEnsureFolderPositiveRecordStructureWithoutRecord() {
		GoogleCloudTestFactory.initMocks(buildMissingFolderMock());
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(null);
		Test.stopTest();

		Assert.areEqual(null, folderId);
	}

	@IsTest
	private static void testEnsureFolderPositiveRecordUserStructure() {
		GoogleCloudTestFactory.initMocks(buildMissingFolderMock());
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}-{User}');

		Id linkedRecordId = GoogleCloudTestFactory.linkedRecord('Nested Structure Record');

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(linkedRecordId);
		Test.stopTest();

		Assert.isNotNull(folderId);
	}

	@IsTest
	private static void testEnsureFolderPositiveRecordUserStructureWithoutRecord() {
		GoogleCloudTestFactory.initMocks(buildMissingFolderMock());
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}-{User}');

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(null);
		Test.stopTest();

		Assert.areEqual(null, folderId);
	}

	@IsTest
	private static void testEnsureFolderPositiveUserRecordStructureWithoutRecord() {
		GoogleCloudTestFactory.initMocks(buildMissingFolderMock());
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{User}-{Record}');

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(null);
		Test.stopTest();

		Assert.areEqual(null, folderId);
	}

	@IsTest
	private static void testFindExistingFolderPositive() {
		GoogleCloudTestFactory.initMocks(buildExistingFolderMock('EXISTING_FOLDER_01'));
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');

		Id linkedRecordId = GoogleCloudTestFactory.linkedRecord('Existing Folder Record');

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().findExistingFolder(UserInfo.getUserId(), linkedRecordId);
		Test.stopTest();

		Assert.areEqual('EXISTING_FOLDER_01', folderId);
	}

	@IsTest
	private static void testEnsureFolderPositiveExplicitRootOverride() {
		GoogleCloudTestFactory.initMocks(buildMissingFolderMock());
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('PRIMARY_ROOT', '{Record}');

		Id linkedRecordId = GoogleCloudTestFactory.linkedRecord('Fallback Root Record');

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder('FALLBACK_ROOT', UserInfo.getUserId(), linkedRecordId);
		Test.stopTest();

		Assert.isNotNull(folderId);
	}

	@IsTest
	private static void testEnsureFolderPositiveExplicitRootBlankReturnsNull() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('PRIMARY_ROOT', '{User}');

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder('', UserInfo.getUserId(), null);
		Test.stopTest();

		Assert.areEqual(null, folderId);
	}

	@IsTest
	private static void testFindExistingFolderPositiveExplicitRootOverride() {
		GoogleCloudTestFactory.initMocks(buildExistingFolderMock('EXISTING_FALLBACK_FOLDER'));
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('PRIMARY_ROOT', '{Record}');

		Id linkedRecordId = GoogleCloudTestFactory.linkedRecord('Fallback Existing Record');

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().findExistingFolder('FALLBACK_ROOT', UserInfo.getUserId(), linkedRecordId);
		Test.stopTest();

		Assert.areEqual('EXISTING_FALLBACK_FOLDER', folderId);
	}

	@IsTest
	private static void testEnsureFolderPositiveCachedFolderSkipsDriveCallouts() {
		GoogleDriveHttpMock driveMock = buildMissingFolderMock();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');

		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCacheDriveFolderService folderCache = new GoogleCacheDriveFolderService();
		folderCache.putFolderId(folderCache.buildFolderKey('ROOT_FOLDER_01', linkedRecordId), 'CACHED_FOLDER_01');

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(linkedRecordId);
		Test.stopTest();

		Assert.areEqual('CACHED_FOLDER_01', folderId);
		Assert.isTrue(driveMock.getCapturedRequests().isEmpty(), 'A cached folder must never reach Google Drive');
	}

	@IsTest
	private static void testEnsureFolderPositiveRepeatedResolutionSearchesOnce() {
		GoogleDriveHttpMock driveMock = buildMissingFolderMock();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');

		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleFileFolderStructureCommand folderStructureCommand = new GoogleFileFolderStructureCommand();

		Test.startTest();
		String firstFolderId = folderStructureCommand.ensureFolder(linkedRecordId);
		Integer calloutsAfterFirstResolution = driveMock.getCapturedRequests().size();
		String secondFolderId = folderStructureCommand.ensureFolder(linkedRecordId);
		Test.stopTest();

		Assert.areEqual(firstFolderId, secondFolderId);
		Assert.areEqual(calloutsAfterFirstResolution, driveMock.getCapturedRequests().size(), 'A repeated resolution must be served from memory');
	}

	@IsTest
	private static void testEnsureFolderPositiveAdoptsSameFolderAmongDuplicates() {
		GoogleCloudTestFactory.initMocks(buildDuplicateFoldersMock(new List<String>{ 'FOLDER_C', 'FOLDER_A', 'FOLDER_B' }));
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');

		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(linkedRecordId);
		String repeatedFolderId = new GoogleFileFolderStructureCommand().ensureFolder(linkedRecordId);
		Test.stopTest();

		Assert.areEqual('FOLDER_A', folderId);
		Assert.areEqual('FOLDER_A', repeatedFolderId, 'Duplicated folders must resolve to the same folder every time');
	}

	@IsTest
	private static void testEnsureFolderNegativeDefersWhileAnotherTransactionCreates() {
		GoogleDriveHttpMock driveMock = buildMissingFolderMock();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');

		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCacheDriveFolderService folderCache = new GoogleCacheDriveFolderService();
		folderCache.markPending(folderCache.buildFolderKey('ROOT_FOLDER_01', linkedRecordId));

		GoogleFileFolderStructureCommand folderStructureCommand = new GoogleFileFolderStructureCommand();

		Test.startTest();
		String folderId = folderStructureCommand.ensureFolder(linkedRecordId);
		Test.stopTest();

		Assert.isNull(folderId);
		Assert.isTrue(folderStructureCommand.isResolutionDeferred(), 'A pending claim must defer instead of creating a second folder');
		Assert.isTrue(driveMock.getCapturedRequests().isEmpty(), 'A deferred resolution must not touch Google Drive');
	}

	@IsTest
	private static void testEnsureFolderPositiveIgnoresPendingClaimOnFinalAttempt() {
		GoogleCloudTestFactory.initMocks(buildMissingFolderMock());
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');

		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCacheDriveFolderService folderCache = new GoogleCacheDriveFolderService();
		folderCache.markPending(folderCache.buildFolderKey('ROOT_FOLDER_01', linkedRecordId));

		GoogleFileFolderStructureCommand folderStructureCommand = new GoogleFileFolderStructureCommand().ignorePendingClaims();

		Test.startTest();
		String folderId = folderStructureCommand.ensureFolder(linkedRecordId);
		Test.stopTest();

		Assert.isNotNull(folderId);
		Assert.isFalse(folderStructureCommand.isResolutionDeferred());
	}

	@IsTest
	private static void testEnsureFolderPositiveResolvesWhenCacheIsUnavailable() {
		GoogleCloudTestFactory.initMocks(buildExistingFolderMock('EXISTING_FOLDER_01'));
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');
		GoogleCacheDriveFolderService.cacheProviderOverride = new GoogleInMemoryCacheProvider(true);

		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(linkedRecordId);
		Test.stopTest();

		Assert.areEqual('EXISTING_FOLDER_01', folderId, 'Folder placement must keep working without Platform Cache');
	}

	@IsTest
	private static void testEvictResolvedFoldersPositiveClearsCachedFolder() {
		GoogleCloudTestFactory.initMocks(buildExistingFolderMock('EXISTING_FOLDER_01'));
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');

		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleFileFolderStructureCommand folderStructureCommand = new GoogleFileFolderStructureCommand();

		Test.startTest();
		folderStructureCommand.ensureFolder(linkedRecordId);
		folderStructureCommand.evictResolvedFolders();
		Test.stopTest();

		GoogleCacheDriveFolderService folderCache = new GoogleCacheDriveFolderService();
		Assert.isNull(folderCache.getFolderId(folderCache.buildFolderKey('ROOT_FOLDER_01', linkedRecordId)));
	}

	@IsTest
	private static void testEnsureFolderPositiveCreatesRecordFolderWithTodaysName() {
		GoogleDriveHttpMock driveMock = buildMissingFolderMock();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig(ROOT_FOLDER_ID, '{Record}');
		GoogleFile__c record = insertRecord(RECORD_NAME);

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(record.Id);
		Test.stopTest();

		Assert.areEqual(CREATED_FOLDER_ID, folderId);
		Assert.isTrue(createdFolderBody(driveMock).contains(TODAYS_RECORD_FOLDER_NAME), 'A record folder is named "<Object> : <record name>", exactly as before');
	}

	@IsTest
	private static void testEnsureFolderPositiveCreatesUnknownRecordFolderForARecordThatIsGone() {
		GoogleDriveHttpMock driveMock = buildMissingFolderMock();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig(ROOT_FOLDER_ID, '{Record}');

		Test.startTest();
		new GoogleFileFolderStructureCommand().ensureFolder(GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType));
		Test.stopTest();

		Assert.isTrue(createdFolderBody(driveMock).contains('GoogleFile__c : Unknown Record'));
	}

	@IsTest
	private static void testEnsureFolderPositiveCreatesUserFolderWithTodaysName() {
		GoogleDriveHttpMock driveMock = buildMissingFolderMock();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig(ROOT_FOLDER_ID, '{User}');

		Test.startTest();
		new GoogleFileFolderStructureCommand().ensureFolder(null);
		Test.stopTest();

		Assert.isTrue(createdFolderBody(driveMock).contains(todaysUserFolderName()), 'A user folder is named "User : <First> <Last>", exactly as before');
	}

	@IsTest
	private static void testEnsureFolderPositiveNamesANewRecordFolderFromThePatternWithRenamingOff() {
		GoogleDriveHttpMock driveMock = buildMissingFolderMock();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{Record}', false, patternRows('GoogleFile__c', PATTERN_WITH_SOURCE));
		GoogleFile__c record = insertRecord(RECORD_NAME);

		Test.startTest();
		new GoogleFileFolderStructureCommand().followCurrentNames().ensureFolder(record.Id);
		Test.stopTest();

		String createdBody = createdFolderBody(driveMock);
		Assert.isTrue(createdBody.contains('Acme Brochure - Migration'), 'Patterns name new folders whether renaming is on or not');
		Assert.isFalse(createdBody.contains(TODAYS_RECORD_FOLDER_NAME));
	}

	@IsTest
	private static void testEnsureFolderPositiveNamesANewUserFolderFromTheUserPattern() {
		GoogleDriveHttpMock driveMock = buildMissingFolderMock();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{User}', false, patternRows('User', 'LastName & " team"'));

		Test.startTest();
		new GoogleFileFolderStructureCommand().ensureFolder(null);
		Test.stopTest();

		Assert.isTrue(createdFolderBody(driveMock).contains(UserInfo.getLastName() + ' team'));
	}

	@IsTest
	private static void testEnsureFolderPositiveRenamesACachedFolderWhoseRecordWasRenamed() {
		GoogleDriveHttpMock driveMock = buildCachedFolderMock(CACHED_FOLDER_ID, 'GoogleFile__c : Old Name');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{Record}', true, null);
		GoogleFile__c record = insertRecord(RECORD_NAME);
		cacheFolder(ROOT_FOLDER_ID, record.Id, CACHED_FOLDER_ID);
		GoogleFileFolderStructureCommand folderStructureCommand = new GoogleFileFolderStructureCommand().followCurrentNames();

		Test.startTest();
		String folderId = folderStructureCommand.ensureFolder(record.Id);
		Test.stopTest();

		Assert.areEqual(CACHED_FOLDER_ID, folderId, 'A renamed folder keeps its Id');
		Assert.areEqual(1, requestsTo(driveMock, 'PATCH', CACHED_FOLDER_ID).size());
		Assert.isTrue(renameBody(driveMock, CACHED_FOLDER_ID).contains(TODAYS_RECORD_FOLDER_NAME), 'The folder takes the record\'s current name');
		Assert.areEqual(CACHED_FOLDER_ID, cachedFolderId(ROOT_FOLDER_ID, record.Id), 'Files, links and the folder cache never notice a rename');
		Assert.isFalse(folderStructureCommand.hasRecordedErrors());
	}

	@IsTest
	private static void testEnsureFolderPositiveRenamesAFoundFolderWithoutReadingItAgain() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		answerSearch(driveMock, FOUND_FOLDER_ID, 'GoogleFile__c : Old Name');
		answerRename(driveMock, FOUND_FOLDER_ID, 200, JSON.serialize(new Map<String, String>{ 'id' => FOUND_FOLDER_ID }));
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{Record}', true, null);
		GoogleFile__c record = insertRecord(RECORD_NAME);

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().followCurrentNames().ensureFolder(record.Id);
		Test.stopTest();

		Assert.areEqual(FOUND_FOLDER_ID, folderId);
		Assert.areEqual(0, requestsTo(driveMock, 'GET', FOUND_FOLDER_ID).size(), 'The search already returned the folder\'s name');
		Assert.areEqual(1, requestsTo(driveMock, 'PATCH', FOUND_FOLDER_ID).size());
		Assert.isTrue(renameBody(driveMock, FOUND_FOLDER_ID).contains(TODAYS_RECORD_FOLDER_NAME));
	}

	@IsTest
	private static void testEnsureFolderPositiveLeavesAFolderWithTheCurrentNameAlone() {
		GoogleDriveHttpMock driveMock = buildCachedFolderMock(CACHED_FOLDER_ID, TODAYS_RECORD_FOLDER_NAME + ' ');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{Record}', true, null);
		GoogleFile__c record = insertRecord(RECORD_NAME);
		cacheFolder(ROOT_FOLDER_ID, record.Id, CACHED_FOLDER_ID);

		Test.startTest();
		new GoogleFileFolderStructureCommand().followCurrentNames().ensureFolder(record.Id);
		Test.stopTest();

		Assert.areEqual(0, requestsTo(driveMock, 'PATCH', CACHED_FOLDER_ID).size(), 'Switching renaming on renames only folders whose record really changed');
	}

	@IsTest
	private static void testEnsureFolderPositiveDoesNotRenameWithoutFollowCurrentNames() {
		GoogleDriveHttpMock driveMock = buildCachedFolderMock(CACHED_FOLDER_ID, 'GoogleFile__c : Old Name');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{Record}', true, null);
		GoogleFile__c record = insertRecord(RECORD_NAME);
		cacheFolder(ROOT_FOLDER_ID, record.Id, CACHED_FOLDER_ID);

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(record.Id);
		Test.stopTest();

		Assert.areEqual(CACHED_FOLDER_ID, folderId);
		Assert.isTrue(driveMock.getCapturedRequests().isEmpty(), 'The upload\'s folder prefetch and the Create Folder action never rename, so they never wait for Drive');
	}

	@IsTest
	private static void testEnsureFolderPositiveDoesNotRenameWithTheSettingOff() {
		GoogleDriveHttpMock driveMock = buildCachedFolderMock(CACHED_FOLDER_ID, 'GoogleFile__c : Old Name');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{Record}', false, null);
		GoogleFile__c record = insertRecord(RECORD_NAME);
		cacheFolder(ROOT_FOLDER_ID, record.Id, CACHED_FOLDER_ID);

		Test.startTest();
		new GoogleFileFolderStructureCommand().followCurrentNames().ensureFolder(record.Id);
		Test.stopTest();

		Assert.isTrue(driveMock.getCapturedRequests().isEmpty(), 'With renaming off nothing is ever renamed');
	}

	@IsTest
	private static void testEnsureFolderPositiveDoesNotRenameOnAFreshInstall() {
		GoogleDriveHttpMock driveMock = buildCachedFolderMock(CACHED_FOLDER_ID, 'GoogleFile__c : Old Name');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig(ROOT_FOLDER_ID, '{Record}');
		GoogleFile__c record = insertRecord(RECORD_NAME);
		cacheFolder(ROOT_FOLDER_ID, record.Id, CACHED_FOLDER_ID);

		Test.startTest();
		new GoogleFileFolderStructureCommand().followCurrentNames().ensureFolder(record.Id);
		Test.stopTest();

		Assert.isTrue(driveMock.getCapturedRequests().isEmpty(), 'An upgraded org renames nothing until an administrator switches renaming on');
	}

	@IsTest
	private static void testEnsureFolderPositiveReadsAndRenamesOnceForRepeatedResolutions() {
		GoogleDriveHttpMock driveMock = buildCachedFolderMock(CACHED_FOLDER_ID, 'GoogleFile__c : Old Name');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{Record}', true, null);
		GoogleFile__c record = insertRecord(RECORD_NAME);
		cacheFolder(ROOT_FOLDER_ID, record.Id, CACHED_FOLDER_ID);
		GoogleFileFolderStructureCommand folderStructureCommand = new GoogleFileFolderStructureCommand().followCurrentNames();

		Test.startTest();
		folderStructureCommand.ensureFolder(record.Id);
		folderStructureCommand.ensureFolder(record.Id);
		folderStructureCommand.ensureFolder(record.Id);
		Test.stopTest();

		Assert.areEqual(1, requestsTo(driveMock, 'GET', CACHED_FOLDER_ID).size(), 'At most one read per folder per job');
		Assert.areEqual(1, requestsTo(driveMock, 'PATCH', CACHED_FOLDER_ID).size(), 'At most one rename per folder per job');
	}

	@IsTest
	private static void testEnsureFolderPositiveDoesNotRenameAFolderItCreated() {
		GoogleDriveHttpMock driveMock = buildMissingFolderMock();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{Record}', true, null);
		GoogleFile__c record = insertRecord(RECORD_NAME);

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().followCurrentNames().ensureFolder(record.Id);
		Test.stopTest();

		Assert.areEqual(CREATED_FOLDER_ID, folderId);
		Assert.areEqual(0, requestsTo(driveMock, 'PATCH', CREATED_FOLDER_ID).size(), 'A folder made now already carries the current name');
	}

	@IsTest
	private static void testEnsureFolderPositiveFailedRenameStillReturnsTheFolder() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		answerFolderName(driveMock, CACHED_FOLDER_ID, 'GoogleFile__c : Old Name');
		answerRename(driveMock, CACHED_FOLDER_ID, 500, DRIVE_SERVER_ERROR_BODY);
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{Record}', true, null);
		GoogleFile__c record = insertRecord(RECORD_NAME);
		cacheFolder(ROOT_FOLDER_ID, record.Id, CACHED_FOLDER_ID);
		GoogleFileFolderStructureCommand folderStructureCommand = new GoogleFileFolderStructureCommand().followCurrentNames();

		Exception resolutionFailure;
		String folderId;
		Test.startTest();
		try {
			folderId = folderStructureCommand.ensureFolder(record.Id);
		} catch (Exception ex) {
			resolutionFailure = ex;
		}
		Test.stopTest();

		Assert.isNull(resolutionFailure, 'A rename never fails a placement');
		Assert.areEqual(CACHED_FOLDER_ID, folderId, 'A rename never redirects a placement');
		Assert.areEqual(CACHED_FOLDER_ID, cachedFolderId(ROOT_FOLDER_ID, record.Id), 'A failed rename never evicts the cached folder');
		Assert.isTrue(folderStructureCommand.hasRecordedErrors(), 'The job must know to save the log');
		Assert.areEqual(1, loggedEntries(GoogleFileFolderStructureCommand.loggedFailures, 'ERROR').size());
		Assert.areEqual(0, loggedEntries(GoogleFileFolderStructureCommand.loggedFailures, 'WARN').size(), 'The log records failures as errors, never as warnings');
	}

	@IsTest
	private static void testEnsureFolderPositiveFailedNameReadStillReturnsTheFolder() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('/files/' + CACHED_FOLDER_ID)
		).thenReturnStatus(404, DRIVE_NOT_FOUND_BODY);
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{Record}', true, null);
		GoogleFile__c record = insertRecord(RECORD_NAME);
		cacheFolder(ROOT_FOLDER_ID, record.Id, CACHED_FOLDER_ID);
		GoogleFileFolderStructureCommand folderStructureCommand = new GoogleFileFolderStructureCommand().followCurrentNames();

		Test.startTest();
		String folderId = folderStructureCommand.ensureFolder(record.Id);
		Test.stopTest();

		Assert.areEqual(CACHED_FOLDER_ID, folderId);
		Assert.areEqual(0, requestsTo(driveMock, 'PATCH', CACHED_FOLDER_ID).size());
		Assert.isTrue(folderStructureCommand.hasRecordedErrors(), 'A name that could not be read is a rename failure');
	}

	@IsTest
	private static void testEnsureFolderPositiveDoesNotRenameWhenTheRecordIsGone() {
		GoogleDriveHttpMock driveMock = buildCachedFolderMock(CACHED_FOLDER_ID, 'GoogleFile__c : Old Name');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{Record}', true, null);
		Id missingRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		cacheFolder(ROOT_FOLDER_ID, missingRecordId, CACHED_FOLDER_ID);

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().followCurrentNames().ensureFolder(missingRecordId);
		Test.stopTest();

		Assert.areEqual(CACHED_FOLDER_ID, folderId);
		Assert.areEqual(0, requestsTo(driveMock, 'PATCH', CACHED_FOLDER_ID).size(), 'A folder is never renamed to "Unknown Record"');
	}

	@IsTest
	private static void testEnsureFolderPositiveBrokenPatternDoesNotRenameAndRecordsOneError() {
		GoogleDriveHttpMock driveMock = buildCachedFolderMock(CACHED_FOLDER_ID, 'GoogleFile__c : Old Name');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{Record}', true, patternRows('GoogleFile__c', 'Name & Nope__c'));
		GoogleFile__c record = insertRecord(RECORD_NAME);
		cacheFolder(ROOT_FOLDER_ID, record.Id, CACHED_FOLDER_ID);

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().followCurrentNames().ensureFolder(record.Id);
		Test.stopTest();

		Assert.areEqual(CACHED_FOLDER_ID, folderId, 'A pattern that no longer works never breaks an upload');
		Assert.areEqual(0, requestsTo(driveMock, 'PATCH', CACHED_FOLDER_ID).size(), 'An existing folder is not renamed while its pattern does not work');
		Assert.areEqual(1, loggedEntries(GoogleDriveFolderNameResolver.loggedFailures, 'ERROR').size());
	}

	@IsTest
	private static void testEnsureFolderPositiveRenamesUserAndRecordFoldersUnderUserRecord() {
		GoogleDriveHttpMock driveMock = buildCachedFolderMock(USER_FOLDER_ID, 'User : Old Name');
		answerFolderName(driveMock, RECORD_FOLDER_ID, 'GoogleFile__c : Old Name');
		answerRename(driveMock, RECORD_FOLDER_ID, 200, JSON.serialize(new Map<String, String>{ 'id' => RECORD_FOLDER_ID }));
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{User}-{Record}', true, null);
		GoogleFile__c record = insertRecord(RECORD_NAME);
		cacheFolder(ROOT_FOLDER_ID, UserInfo.getUserId(), USER_FOLDER_ID);
		cacheFolder(USER_FOLDER_ID, record.Id, RECORD_FOLDER_ID);

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().followCurrentNames().ensureFolder(record.Id);
		Test.stopTest();

		Assert.areEqual(RECORD_FOLDER_ID, folderId);
		Assert.isTrue(renameBody(driveMock, USER_FOLDER_ID).contains(todaysUserFolderName()), 'A user folder follows the user\'s current name under the same setting');
		Assert.isTrue(renameBody(driveMock, RECORD_FOLDER_ID).contains(TODAYS_RECORD_FOLDER_NAME));
	}

	@IsTest
	private static void testEnsureFolderPositiveRenamesRecordAndUserFoldersUnderRecordUser() {
		GoogleDriveHttpMock driveMock = buildCachedFolderMock(RECORD_FOLDER_ID, 'GoogleFile__c : Old Name');
		answerFolderName(driveMock, USER_FOLDER_ID, 'User : Old Name');
		answerRename(driveMock, USER_FOLDER_ID, 200, JSON.serialize(new Map<String, String>{ 'id' => USER_FOLDER_ID }));
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{Record}-{User}', true, null);
		GoogleFile__c record = insertRecord(RECORD_NAME);
		cacheFolder(ROOT_FOLDER_ID, record.Id, RECORD_FOLDER_ID);
		cacheFolder(RECORD_FOLDER_ID, UserInfo.getUserId(), USER_FOLDER_ID);

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().followCurrentNames().ensureFolder(record.Id);
		Test.stopTest();

		Assert.areEqual(USER_FOLDER_ID, folderId);
		Assert.isTrue(renameBody(driveMock, RECORD_FOLDER_ID).contains(TODAYS_RECORD_FOLDER_NAME));
		Assert.isTrue(renameBody(driveMock, USER_FOLDER_ID).contains(todaysUserFolderName()));
	}

	@IsTest
	private static void testEnsureFolderPositiveRenamesOnlyTheFolderThisUploadReaches() {
		String otherRootFolderId = 'ROOT_FOLDER_02';
		String otherDriveFolderId = 'OTHER_DRIVE_FOLDER_01';
		GoogleDriveHttpMock driveMock = buildCachedFolderMock(CACHED_FOLDER_ID, 'GoogleFile__c : Old Name');
		answerFolderName(driveMock, otherDriveFolderId, 'GoogleFile__c : Old Name');
		answerRename(driveMock, otherDriveFolderId, 200, JSON.serialize(new Map<String, String>{ 'id' => otherDriveFolderId }));
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{Record}', true, null);
		GoogleFile__c record = insertRecord(RECORD_NAME);
		cacheFolder(ROOT_FOLDER_ID, record.Id, CACHED_FOLDER_ID);
		cacheFolder(otherRootFolderId, record.Id, otherDriveFolderId);

		Test.startTest();
		new GoogleFileFolderStructureCommand().followCurrentNames().ensureFolder(ROOT_FOLDER_ID, UserInfo.getUserId(), record.Id);
		Test.stopTest();

		Assert.areEqual(1, requestsTo(driveMock, 'PATCH', CACHED_FOLDER_ID).size());
		Assert.areEqual(0, requestsTo(driveMock, 'GET', otherDriveFolderId).size(), 'The record\'s folder on another drive follows only when a file reaches it');
		Assert.areEqual(0, requestsTo(driveMock, 'PATCH', otherDriveFolderId).size());
	}

	@IsTest
	private static void testEnsureFolderPositiveFollowsAChangedPattern() {
		GoogleDriveHttpMock driveMock = buildCachedFolderMock(CACHED_FOLDER_ID, TODAYS_RECORD_FOLDER_NAME);
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{Record}', true, patternRows('GoogleFile__c', PATTERN_WITH_SOURCE));
		GoogleFile__c record = insertRecord(RECORD_NAME);
		cacheFolder(ROOT_FOLDER_ID, record.Id, CACHED_FOLDER_ID);

		Test.startTest();
		new GoogleFileFolderStructureCommand().followCurrentNames().ensureFolder(record.Id);
		Test.stopTest();

		Assert.isTrue(renameBody(driveMock, CACHED_FOLDER_ID).contains('Acme Brochure - Migration'), 'A folder picks up a new pattern the way it picks up a rename');
	}

	@IsTest
	private static void testEnsureFolderPositiveRemovedPatternRenamesBackToTodaysName() {
		GoogleDriveHttpMock driveMock = buildCachedFolderMock(CACHED_FOLDER_ID, 'Acme Brochure - Migration');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{Record}', true, null);
		GoogleFile__c record = insertRecord(RECORD_NAME);
		cacheFolder(ROOT_FOLDER_ID, record.Id, CACHED_FOLDER_ID);

		Test.startTest();
		new GoogleFileFolderStructureCommand().followCurrentNames().ensureFolder(record.Id);
		Test.stopTest();

		Assert.isTrue(renameBody(driveMock, CACHED_FOLDER_ID).contains(TODAYS_RECORD_FOLDER_NAME));
	}

	@IsTest
	private static void testEnsureFolderPositiveRenamesBackAFolderRenamedByHand() {
		GoogleDriveHttpMock driveMock = buildCachedFolderMock(CACHED_FOLDER_ID, 'Acme - renamed by hand in Drive');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{Record}', true, null);
		GoogleFile__c record = insertRecord(RECORD_NAME);
		cacheFolder(ROOT_FOLDER_ID, record.Id, CACHED_FOLDER_ID);

		Test.startTest();
		new GoogleFileFolderStructureCommand().followCurrentNames().ensureFolder(record.Id);
		Test.stopTest();

		Assert.isTrue(renameBody(driveMock, CACHED_FOLDER_ID).contains(TODAYS_RECORD_FOLDER_NAME));
	}

	@IsTest
	private static void testEnsureFolderPositiveDeferredResolutionDoesNotRename() {
		GoogleDriveHttpMock driveMock = buildCachedFolderMock(CACHED_FOLDER_ID, 'GoogleFile__c : Old Name');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{Record}', true, null);
		GoogleFile__c record = insertRecord(RECORD_NAME);
		GoogleCacheDriveFolderService folderCache = new GoogleCacheDriveFolderService();
		folderCache.markPending(folderCache.buildFolderKey(ROOT_FOLDER_ID, record.Id));
		GoogleFileFolderStructureCommand folderStructureCommand = new GoogleFileFolderStructureCommand().followCurrentNames();

		Test.startTest();
		String folderId = folderStructureCommand.ensureFolder(record.Id);
		Test.stopTest();

		Assert.isNull(folderId);
		Assert.isTrue(folderStructureCommand.isResolutionDeferred());
		Assert.isTrue(driveMock.getCapturedRequests().isEmpty());
	}

	@IsTest
	private static void testEnsureFolderPositiveNeverNamesAnotherUsersFolderAfterTheRunningUser() {
		String otherUserFolderId = 'OTHER_USER_FOLDER_01';
		GoogleDriveHttpMock driveMock = buildCachedFolderMock(otherUserFolderId, 'User : Someone Else');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildRenameConfig('{User}', true, null);
		Id otherUserId = GoogleCloudTestFactory.otherUserId();
		cacheFolder(ROOT_FOLDER_ID, otherUserId, otherUserFolderId);

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().followCurrentNames().ensureFolder(otherUserId, null);
		Test.stopTest();

		Assert.areEqual(otherUserFolderId, folderId);
		Assert.areEqual(0, requestsTo(driveMock, 'PATCH', otherUserFolderId).size(), 'A folder is named after the user it belongs to, never after whoever runs the job');
	}
}