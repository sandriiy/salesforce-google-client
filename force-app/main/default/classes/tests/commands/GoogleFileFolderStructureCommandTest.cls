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
}