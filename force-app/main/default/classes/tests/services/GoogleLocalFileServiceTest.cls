@IsTest
private class GoogleLocalFileServiceTest {
	private static final String LINK_SELECTOR_MOCK_ID = 'GoogleFileLinkSelector';
	private static final String FILE_SELECTOR_MOCK_ID = 'GoogleFileSelector';
	private static final String VERSION_SELECTOR_MOCK_ID = 'GoogleFileVersionSelector';

	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static void initMocks() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleLocalFileServiceTest.TestGoogleAuthorizer';
	}

	private static void coverServiceFactories() {
		GoogleLocalFileService s = new GoogleLocalFileService();
		System.assertNotEquals(null, s.createGoogleFileRecord());
		System.assertNotEquals(null, s.createGoogleFileSharing());
		System.assertNotEquals(null, s.deleteGoogleFileRecord());
		System.assertNotEquals(null, s.deleteGoogleFileSharing());
		System.assertNotEquals(null, s.modifyGoogleFileSharing());
		System.assertNotEquals(null, s.retrieveSharingDetails());
		System.assertNotEquals(null, s.retrieveGoogleFileHeaderDetails());
		System.assertNotEquals(null, s.stripInaccessibleRecords());
	}

	@IsTest
	private static void stripInaccessibleRecordsTestSuccessOwner() {
		initMocks();
		coverServiceFactories();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('F1').withDescription('D').insertRecord();
		List<GoogleFile__c> out = new GoogleFileAccessCheckCommand().forFile(f.Id).forUser(UserInfo.getUserId()).strip();

		System.assertEquals(1, out.size());
		System.assertEquals('Edit', out[0].UserAccessLevel__c);
	}

	@IsTest
	private static void stripInaccessibleRecordsTestSuccessShareView() {
		initMocks();
		coverServiceFactories();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('F2').withDescription('D').insertRecord();

		GoogleFile__Share sh = new GoogleFile__Share(ParentId = f.Id, UserOrGroupId = u.Id, AccessLevel = 'Read', RowCause = Schema.GoogleFile__Share.RowCause.Manual);
		insert sh;

		List<GoogleFile__c> out = new GoogleFileAccessCheckCommand().forFile(new GoogleFile__c(Id = f.Id)).forUser(u.Id).strip();

		System.assertEquals(1, out.size());
		System.assertEquals('View', out[0].UserAccessLevel__c);
	}

	@IsTest
	private static void stripInaccessibleRecordsTestSuccessShareEdit() {
		initMocks();
		coverServiceFactories();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('F3').withDescription('D').insertRecord();

		GoogleFile__Share sh = new GoogleFile__Share(ParentId = f.Id, UserOrGroupId = u.Id, AccessLevel = 'Edit', RowCause = Schema.GoogleFile__Share.RowCause.Manual);
		insert sh;

		List<GoogleFile__c> out = new GoogleFileAccessCheckCommand().forFile(f).forUser(u.Id).strip();

		System.assertEquals(1, out.size());
		System.assertEquals('Edit', out[0].UserAccessLevel__c);
	}

	@IsTest
	private static void stripInaccessibleRecordsTestSuccessLinkView() {
		initMocks();
		coverServiceFactories();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('F4').withDescription('D').insertRecord();

		GoogleCloudTestFactory.link().forFile(f.Id).withShareType('Viewer').withVisibility('AllUsers').insertRecord();

		List<GoogleFileLink__c> links = [
			SELECT Id, Name, GoogleFileId__c, LinkedObjectId__c, LinkedObjectType__c, ShareType__c, Visibility__c
			FROM GoogleFileLink__c
			WHERE GoogleFileId__c = :f.Id
		];
		GSOQL.mock(LINK_SELECTOR_MOCK_ID).thenReturn(links);

		List<GoogleFile__c> out = new GoogleFileAccessCheckCommand().forFile(f.Id).forUser(u.Id).strip();

		System.assertEquals(1, out.size());
		System.assertEquals('View', out[0].UserAccessLevel__c);
	}

	@IsTest
	private static void stripInaccessibleRecordsTestSuccessLinkEdit() {
		initMocks();
		coverServiceFactories();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('F5').withDescription('D').insertRecord();

		GoogleCloudTestFactory.link().forFile(f.Id).withShareType('Collaborator').withVisibility('InternalUsers').insertRecord();

		List<GoogleFileLink__c> links = [
			SELECT Id, Name, GoogleFileId__c, LinkedObjectId__c, LinkedObjectType__c, ShareType__c, Visibility__c
			FROM GoogleFileLink__c
			WHERE GoogleFileId__c = :f.Id
		];
		GSOQL.mock(LINK_SELECTOR_MOCK_ID).thenReturn(links);

		List<GoogleFile__c> out = new GoogleFileAccessCheckCommand().forFile(new GoogleFile__c(Id = f.Id)).forUser(u.Id).strip();

		System.assertEquals(1, out.size());
		System.assertEquals('Edit', out[0].UserAccessLevel__c);
	}

	@IsTest
	private static void stripInaccessibleRecordsTestSuccessInferred() {
		initMocks();
		coverServiceFactories();

		User u = GoogleCloudTestFactory.newUser();
		Account a = new Account(Name = 'A1', OwnerId = u.Id);
		insert a;

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('F6').withDescription('D').insertRecord();

		GoogleCloudTestFactory.link().forFile(f.Id).withShareType('InferredFromRecord').withVisibility('AllUsers').withLinkedRecord(a.Id).withLinkedType('Account').insertRecord();

		List<GoogleFileLink__c> links = [
			SELECT Id, Name, GoogleFileId__c, LinkedObjectId__c, LinkedObjectType__c, ShareType__c, Visibility__c
			FROM GoogleFileLink__c
			WHERE GoogleFileId__c = :f.Id
		];
		GSOQL.mock(LINK_SELECTOR_MOCK_ID).thenReturn(links);

		List<GoogleFile__c> out = new GoogleFileAccessCheckCommand().forFile(f.Id).forUser(u.Id).strip();

		System.assertEquals(1, out.size());
		System.assertEquals('Edit', out[0].UserAccessLevel__c);
	}

	@IsTest
	private static void stripInaccessibleRecordsTestSuccessEmpty() {
		initMocks();
		coverServiceFactories();

		List<GoogleFile__c> out = new GoogleFileAccessCheckCommand().forFiles(new List<GoogleFile__c>()).strip();
		System.assertEquals(0, out.size());
	}

	@IsTest
	private static void stripInaccessibleRecordsTestFailUserMissing() {
		initMocks();
		coverServiceFactories();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('F8').withDescription('D').insertRecord();
		Id missingUserId = (Id)('005000000000000AAA');

		try {
			new GoogleFileAccessCheckCommand().forFile(f.Id).forUser(missingUserId).strip();
			System.assert(false);
		} catch (GoogleFileAccessCheckCommand.GoogleFileAccessCheckException ex) {
			System.assert(ex.getMessage().contains('Target user was not found'));
		}
	}

	@IsTest
	private static void deleteGoogleFileRecordTestSuccessLocalOnly() {
		initMocks();
		coverServiceFactories();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('Del1').withDescription('D').insertRecord();
		GoogleCloudTestFactory.version().forFile(f.Id).withName('V1.pdf').withType('application/pdf').withSize(1).withDriveId('GD1').withDocsId('DOCS1').insertRecord();

		GSOQL.mock(VERSION_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{
			[SELECT Id, Name, GoogleDriveFolderId__c, IsLatestFile__c, PublicLink__c, PublicLinkExpirationDate__c, PublicLinkPermissionId__c, CreatedDate, LastModifiedDate, IsPreviewableFile__c, GoogleFileId__c, GoogleDriveFileId__c, GoogleDocsFileId__c, Type__c, Size__c FROM GoogleFileVersion__c WHERE GoogleFileId__c = :f.Id]
		});

		Test.startTest();
		Boolean ok = new GoogleLocalFileService().deleteGoogleFileRecord().setRecordId(f.Id).setCloudDeletion(false).save();
		Test.stopTest();

		System.assertEquals(true, ok);
		System.assertEquals(0, [SELECT count() FROM GoogleFile__c WHERE Id = :f.Id]);
		System.assertEquals(0, [SELECT count() FROM GoogleFileVersion__c WHERE GoogleFileId__c = :f.Id]);
	}

	@IsTest
	private static void deleteGoogleFileRecordTestSuccessWithCloud() {
		initMocks();
		coverServiceFactories();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('Del2').withDescription('D').insertRecord();
		GoogleCloudTestFactory.version().forFile(f.Id).withName('V1.pdf').withType('application/pdf').withSize(1).withDriveId('GD1').withDocsId('DOCS1').insertRecord();

		GSOQL.mock(VERSION_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{
			[SELECT Id, Name, GoogleDriveFolderId__c, IsLatestFile__c, PublicLink__c, PublicLinkExpirationDate__c, PublicLinkPermissionId__c, CreatedDate, LastModifiedDate, IsPreviewableFile__c, GoogleFileId__c, GoogleDriveFileId__c, GoogleDocsFileId__c, Type__c, Size__c FROM GoogleFileVersion__c WHERE GoogleFileId__c = :f.Id]
		});

		Test.startTest();
		Boolean ok = new GoogleLocalFileService().deleteGoogleFileRecord().setRecordId(f.Id).setCloudDeletion(true).save();
		Test.stopTest();

		System.assertEquals(true, ok);
		System.assertEquals(0, [SELECT count() FROM GoogleFile__c WHERE Id = :f.Id]);
		System.assertEquals(0, [SELECT count() FROM GoogleFileVersion__c WHERE GoogleFileId__c = :f.Id]);
	}

	@IsTest
	private static void createGoogleFileRecordTestSuccessNew() {
		initMocks();
		coverServiceFactories();

		Account a = new Account(Name = 'R1');
		insert a;

		GoogleFile__c fileFromSelector = new GoogleFile__c(Name = 'Any');
		GSOQL.mock(FILE_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{ fileFromSelector });

		Test.startTest();
		GoogleFile__c out = new GoogleLocalFileService().createGoogleFileRecord()
			.setRecordId(a.Id)
			.setGoogleDriveId('GD_NEW')
			.setFileName('MyVeryLongName_' + String.valueOf(Crypto.getRandomLong()) + '.pdf')
			.setFileType('application/pdf')
			.setFileSize(123)
			.setParentFolderId('FOLDER1')
			.setSource('Notes & Attachments')
			.setLocalGoogleFileId(null)
			.save();
		Test.stopTest();

		System.assertNotEquals(null, out);
	}

	@IsTest
	private static void createGoogleFileRecordTestSuccessVersion() {
		initMocks();
		coverServiceFactories();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('Base').withDescription('D').insertRecord();
		GoogleCloudTestFactory.version().forFile(f.Id).withName('Old.pdf').withType('application/pdf').withSize(1).withDriveId('GD_OLD').withDocsId('DOCS_OLD').insertRecord();

		GoogleFile__c fileFromSelector = new GoogleFile__c(Id = f.Id, Name = 'Base');
		GSOQL.mock(FILE_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{ fileFromSelector });

		Test.startTest();
		GoogleFile__c out = new GoogleLocalFileService().createGoogleFileRecord()
			.setLocalGoogleFileId(f.Id)
			.setGoogleDriveId('GD_NEWVER')
			.setFileName('New.docx')
			.setFileType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.setFileSize(10)
			.setParentFolderId('FOLDER2')
			.save();
		Test.stopTest();

		System.assertNotEquals(null, out);
	}

	private static List<String> resolveHeaderFieldApiNamesForTest() {
		List<String> requestedApiNames = new List<String>();
		Schema.DescribeSObjectResult describeResult = GoogleFile__c.SObjectType.getDescribe();
		Map<String, Schema.FieldSet> fieldSetMap = describeResult.fieldSets.getMap();
		if (fieldSetMap == null || !fieldSetMap.containsKey('Header')) return requestedApiNames;

		Schema.FieldSet headerFieldSet = fieldSetMap.get('Header');
		if (headerFieldSet == null) return requestedApiNames;

		for (Schema.FieldSetMember member : headerFieldSet.getFields()) {
			String fieldPath = member.getFieldPath();
			if (String.isBlank(fieldPath)) continue;
			Integer dotIndex = fieldPath.indexOf('.');
			String baseApiName = dotIndex > 0 ? fieldPath.substring(0, dotIndex) : fieldPath;
			if (!requestedApiNames.contains(baseApiName)) requestedApiNames.add(baseApiName);
		}
		return requestedApiNames;
	}

	private static GoogleFile__c buildHeaderMockRecord(Id fileId, String fileName, List<String> headerApiNames) {
		GoogleFile__c fileRecord = new GoogleFile__c();
		fileRecord.put('Id', fileId);
		fileRecord.put('Name', fileName);

		Map<String, Schema.SObjectField> fieldTokenByApiName = GoogleFile__c.SObjectType.getDescribe().fields.getMap();
		for (String apiName : headerApiNames) {
			Schema.SObjectField token = fieldTokenByApiName.get(apiName);
			if (token == null || apiName == 'Id' || apiName == 'Name' || apiName == 'CreatedDate' || apiName == 'LastModifiedDate') continue;

			Schema.DescribeFieldResult d = token.getDescribe();
			if (!d.isUpdateable()) continue;
			if (d.getType() == Schema.DisplayType.REFERENCE) {
				List<Schema.SObjectType> refs = d.getReferenceTo();
				if (refs == null || refs.isEmpty()) continue;

				Schema.SObjectType refType = refs[0];
				SObject related = refType.newSObject();
				related.put('Id', UserInfo.getUserId());
				related.put('Name', 'RelatedName');

				fileRecord.put(apiName, (Id) related.get('Id'));
				String relName = d.getRelationshipName();
				if (!String.isBlank(relName)) fileRecord.putSObject(relName, related);
			} else if (d.getType() == Schema.DisplayType.BOOLEAN) {
				fileRecord.put(apiName, true);
			} else if (d.getType() == Schema.DisplayType.DATE) {
				fileRecord.put(apiName, Date.today());
			} else if (d.getType() == Schema.DisplayType.DATETIME) {
				fileRecord.put(apiName, System.now());
			} else if (d.getType() == Schema.DisplayType.DOUBLE || d.getType() == Schema.DisplayType.CURRENCY || d.getType() == Schema.DisplayType.PERCENT) {
				fileRecord.put(apiName, 1.0);
			} else if (d.getType() == Schema.DisplayType.INTEGER) {
				fileRecord.put(apiName, 1);
			} else {
				fileRecord.put(apiName, 'Val');
			}
		}

		return fileRecord;
	}

	@IsTest
	private static void retrieveGoogleFileHeaderDetailsTestSuccessNullId() {
		initMocks();
		coverServiceFactories();

		GoogleFileHeaderInfoDTO out = new GoogleFilePageDetailsCommand().retrieveHeader().forFile(null).execute();

		System.assertNotEquals(null, out);
		System.assertEquals(null, out.name);
		System.assertNotEquals(null, out.compactFields);
		System.assertEquals(0, out.compactFields.size());
	}

	@IsTest
	private static void retrieveGoogleFileHeaderDetailsTestSuccessMissing() {
		initMocks();
		coverServiceFactories();

		List<String> headerApiNames = resolveHeaderFieldApiNamesForTest();
		if (headerApiNames.isEmpty()) {
			GoogleFileHeaderInfoDTO outNoFieldSet = new GoogleFilePageDetailsCommand().retrieveHeader().forFile('a0B000000000001AAA').execute();
			System.assertEquals(null, outNoFieldSet.name);
			System.assertEquals(0, outNoFieldSet.compactFields.size());
			return;
		}

		GSOQL.mock(FILE_SELECTOR_MOCK_ID).thenReturn(new List<SObject>());

		GoogleFileHeaderInfoDTO out = new GoogleFilePageDetailsCommand().retrieveHeader().forFile('a0B000000000001AAA').execute();

		System.assertNotEquals(null, out);
		System.assertEquals(null, out.name);
		System.assertNotEquals(null, out.compactFields);
		System.assertEquals(0, out.compactFields.size());
	}

	@IsTest
	private static void retrieveGoogleFileHeaderDetailsTestSuccessFields() {
		initMocks();
		coverServiceFactories();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('Hdr1').withDescription('D').insertRecord();

		List<String> headerApiNames = resolveHeaderFieldApiNamesForTest();
		if (headerApiNames.isEmpty()) {
			GoogleFileHeaderInfoDTO outNoFieldSet = new GoogleFilePageDetailsCommand().retrieveHeader().forFile(f.Id).execute();
			System.assertEquals(null, outNoFieldSet.name);
			System.assertEquals(0, outNoFieldSet.compactFields.size());
			return;
		}

		GoogleFile__c mocked = buildHeaderMockRecord(f.Id, 'Hdr1', headerApiNames);
		GSOQL.mock(FILE_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{ mocked });

		GoogleFileHeaderInfoDTO out = new GoogleFilePageDetailsCommand().retrieveHeader().forFile(f.Id).execute();

		System.assertNotEquals(null, out);
		System.assertEquals('Hdr1', out.name);
		System.assertNotEquals(null, out.compactFields);
		System.assertEquals(headerApiNames.size(), out.compactFields.size());

		for (GoogleFileHeaderInfoDTO.CompactFieldDTO dto : out.compactFields) {
			System.assertNotEquals(null, dto);
			System.assert(String.isNotBlank(dto.apiName));
			System.assertNotEquals(null, dto.isReference);
			if (dto.isReference == true && dto.referenceId != null) {
				System.assert(String.isNotBlank(dto.displayValue));
			}
		}
	}

	@IsTest
	private static void retrieveSharingDetailsTestSuccessEmpty() {
		initMocks();
		coverServiceFactories();

		Map<Id, GoogleSharingInfoDTO> out = new GoogleLocalFileService()
			.retrieveSharingDetails()
			.includeAll()
			.fetch();

		System.assertNotEquals(null, out);
		System.assertEquals(0, out.size());
	}

	@IsTest
	private static void retrieveSharingDetailsTestSuccessIncludeNone() {
		initMocks();
		coverServiceFactories();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('RS1').withDescription('D').insertRecord();

		// Selector is used in RetrieveSharingCommand.fetch() to load local files
		GSOQL.mock(FILE_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = f.Id, OwnerId = UserInfo.getUserId(), Name = 'RS1')
		});

		Map<Id, GoogleSharingInfoDTO> out = new GoogleLocalFileService()
			.retrieveSharingDetails()
			.forFile(f.Id)
			.includeNone()
			.fetch();

		System.assertEquals(1, out.size());
		System.assert(out.containsKey(f.Id));

		GoogleSharingInfoDTO dto = out.get(f.Id);
		System.assertEquals(f.Id, dto.fileId);
		System.assertEquals(null, dto.owner);
		System.assertNotEquals(null, dto.entitiesSharedTo);
		System.assertEquals(0, dto.entitiesSharedTo.size());
		System.assertNotEquals(null, dto.recordsSharedTo);
		System.assertEquals(0, dto.recordsSharedTo.size());
	}

	@IsTest
	private static void retrieveSharingDetailsTestSuccessIncludeAll() {
		initMocks();
		coverServiceFactories();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('RS2').withDescription('D').insertRecord();

		// User share (not owner) should be returned when includeUsersAndGroups = true
		GoogleFile__Share sh = new GoogleFile__Share(
			ParentId = f.Id,
			UserOrGroupId = u.Id,
			AccessLevel = 'Read',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);
		insert sh;

		// Record link should be returned when includeRecords = true
		Account a = new Account(Name = 'RS2-A');
		insert a;

		GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(a.Id)
			.withLinkedType('Account')
			.insertRecord();

		// IMPORTANT: RetrieveSharingCommand fetches local files through GoogleFileSelector.query()
		// We only need fields used by the command: Id, OwnerId, Name
		GSOQL.mock(FILE_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = f.Id, OwnerId = UserInfo.getUserId(), Name = 'RS2')
		});

		Map<Id, GoogleSharingInfoDTO> out = new GoogleLocalFileService()
			.retrieveSharingDetails()
			.forFile(f.Id)
			.includeAll()
			.fetch();

		System.assertEquals(1, out.size());

		GoogleSharingInfoDTO dto = out.get(f.Id);
		System.assertEquals(f.Id, dto.fileId);

		// Owner should be present (for current user)
		System.assertNotEquals(null, dto.owner);
		System.assertEquals(UserInfo.getUserId(), dto.owner.Id);

		// Shares should include the non-owner share
		System.assertNotEquals(null, dto.entitiesSharedTo);
		System.assertEquals(1, dto.entitiesSharedTo.size());
		System.assertEquals(u.Id, dto.entitiesSharedTo[0].UserOrGroupId);

		// Links should include the record link
		System.assertNotEquals(null, dto.recordsSharedTo);
		System.assertEquals(1, dto.recordsSharedTo.size());
		System.assertEquals(String.valueOf(a.Id), dto.recordsSharedTo[0].LinkedObjectId__c);
	}

	@IsTest
	private static void createSharingTestSuccessViewer() {
		initMocks();
		coverServiceFactories();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('CS1').withDescription('D').insertRecord();

		Test.startTest();
		Id shareId = new GoogleLocalFileService()
			.createGoogleFileSharing()
			.forFile(f.Id)
			.forUser(u.Id)
			.withUiAccessLevel('viewer')
			.apply();
		Test.stopTest();

		System.assertNotEquals(null, shareId);

		GoogleFile__Share created = [
			SELECT Id, ParentId, UserOrGroupId, AccessLevel, RowCause
			FROM GoogleFile__Share
			WHERE Id = :shareId
			LIMIT 1
		];

		System.assertEquals(f.Id, created.ParentId);
		System.assertEquals(u.Id, created.UserOrGroupId);
		System.assertEquals('Read', created.AccessLevel);
		System.assertEquals(String.valueOf(Schema.GoogleFile__Share.RowCause.Manual), String.valueOf(created.RowCause));
	}

	@IsTest
	private static void createSharingTestSuccessCollaborator() {
		initMocks();
		coverServiceFactories();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('CS2').withDescription('D').insertRecord();

		Test.startTest();
		Id shareId = new GoogleLocalFileService()
			.createGoogleFileSharing()
			.forFile(f.Id)
			.shareTo('User', u.Id)
			.withUiAccessLevel('Collaborator')
			.apply();
		Test.stopTest();

		System.assertNotEquals(null, shareId);

		GoogleFile__Share created = [
			SELECT Id, AccessLevel
			FROM GoogleFile__Share
			WHERE Id = :shareId
			LIMIT 1
		];
		System.assertEquals('Edit', created.AccessLevel);
	}

	@IsTest
	private static void createSharingTestFailNullFileId() {
		initMocks();
		coverServiceFactories();

		User u = GoogleCloudTestFactory.newUser();

		try {
			new GoogleLocalFileService()
				.createGoogleFileSharing()
				.forFile(null)
				.forUser(u.Id)
				.withUiAccessLevel('viewer')
				.apply();
			System.assert(false);
		} catch (GoogleFileSharingCommand.GoogleFileSharingException ex) {
			System.assert(ex.getMessage().contains('File Record Id must not be null'));
		}
	}

	@IsTest
	private static void createSharingTestFailNullShareTo() {
		initMocks();
		coverServiceFactories();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('CS3').withDescription('D').insertRecord();

		try {
			new GoogleLocalFileService()
				.createGoogleFileSharing()
				.forFile(f.Id)
				.shareTo('User', null)
				.withUiAccessLevel('viewer')
				.apply();
			System.assert(false);
		} catch (GoogleFileSharingCommand.GoogleFileSharingException ex) {
			System.assert(ex.getMessage().contains('Share to Record Id must not be null'));
		}
	}

	@IsTest
	private static void createSharingTestFailBlankAccess() {
		initMocks();
		coverServiceFactories();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('CS4').withDescription('D').insertRecord();

		try {
			new GoogleLocalFileService()
				.createGoogleFileSharing()
				.forFile(f.Id)
				.forUser(u.Id)
				.withUiAccessLevel('   ')
				.apply();
			System.assert(false);
		} catch (GoogleFileSharingCommand.GoogleFileSharingException ex) {
			System.assert(ex.getMessage().contains('Access level must not be blank'));
		}
	}

	@IsTest
	private static void createSharingTestFailBadAccess() {
		initMocks();
		coverServiceFactories();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('CS5').withDescription('D').insertRecord();

		try {
			new GoogleLocalFileService()
				.createGoogleFileSharing()
				.forFile(f.Id)
				.forUser(u.Id)
				.withUiAccessLevel('admin')
				.apply();
			System.assert(false);
		} catch (GoogleFileSharingCommand.GoogleFileSharingException ex) {
			System.assert(ex.getMessage().contains('Unsupported AccessLevel'));
		}
	}

	@IsTest
	private static void deleteSharingTestSuccessUser() {
		initMocks();
		coverServiceFactories();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('DS1').withDescription('D').insertRecord();

		GoogleFile__Share sh = new GoogleFile__Share(
			ParentId = f.Id,
			UserOrGroupId = u.Id,
			AccessLevel = 'Read',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);
		insert sh;

		Test.startTest();
		new GoogleLocalFileService()
			.deleteGoogleFileSharing()
			.forFile(f.Id)
			.shareTo(u.Id)
			.apply();
		Test.stopTest();

		System.assertEquals(0, [
			SELECT count()
			FROM GoogleFile__Share
			WHERE ParentId = :f.Id AND UserOrGroupId = :u.Id
		]);
	}

	@IsTest
	private static void deleteSharingTestFailUserShareMissing() {
		initMocks();
		coverServiceFactories();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('DS2').withDescription('D').insertRecord();

		try {
			new GoogleLocalFileService()
				.deleteGoogleFileSharing()
				.forFile(f.Id)
				.shareTo(u.Id)
				.apply();
			System.assert(false);
		} catch (GoogleFileSharingCommand.GoogleFileSharingException ex) {
			System.assert(ex.getMessage().contains('No matching user/group share found'));
		}
	}

	@IsTest
	private static void deleteSharingTestSuccessLink() {
		initMocks();
		coverServiceFactories();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('DS3').withDescription('D').insertRecord();
		Account a = new Account(Name = 'DS3-A');
		insert a;

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(a.Id)
			.withLinkedType('Account')
			.insertRecord();

		Test.startTest();
		new GoogleLocalFileService()
			.deleteGoogleFileSharing()
			.forFile(f.Id)
			.shareTo(a.Id)
			.apply();
		Test.stopTest();

		System.assertEquals(0, [
			SELECT count()
			FROM GoogleFileLink__c
			WHERE Id = :link.Id
		]);
	}

	@IsTest
	private static void deleteSharingTestFailLinkMissing() {
		initMocks();
		coverServiceFactories();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('DS4').withDescription('D').insertRecord();
		Account a = new Account(Name = 'DS4-A');
		insert a;

		try {
			new GoogleLocalFileService()
				.deleteGoogleFileSharing()
				.forFile(f.Id)
				.shareTo(a.Id)
				.apply();
			System.assert(false);
		} catch (GoogleFileSharingCommand.GoogleFileSharingException ex) {
			System.assert(ex.getMessage().contains('No matching record link found'));
		}
	}

	@IsTest
	private static void modifySharingTestSuccessUser() {
		initMocks();
		coverServiceFactories();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('MS1').withDescription('D').insertRecord();

		GoogleFile__Share sh = new GoogleFile__Share(
			ParentId = f.Id,
			UserOrGroupId = u.Id,
			AccessLevel = 'Read',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);
		insert sh;

		Test.startTest();
		new GoogleLocalFileService()
			.modifyGoogleFileSharing()
			.forFile(f.Id)
			.shareTo(u.Id)
			.withUiAccessLevel('Collaborator')
			.apply();
		Test.stopTest();

		GoogleFile__Share updated = [
			SELECT AccessLevel
			FROM GoogleFile__Share
			WHERE Id = :sh.Id
			LIMIT 1
		];
		System.assertEquals('Edit', updated.AccessLevel);
	}

	@IsTest
	private static void modifySharingTestFailMissingAccess() {
		initMocks();
		coverServiceFactories();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('MS2').withDescription('D').insertRecord();

		GoogleFile__Share sh = new GoogleFile__Share(
			ParentId = f.Id,
			UserOrGroupId = u.Id,
			AccessLevel = 'Read',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);
		insert sh;

		try {
			new GoogleLocalFileService()
				.modifyGoogleFileSharing()
				.forFile(f.Id)
				.shareTo(u.Id)
				.withUiAccessLevel(null)
				.apply();
			System.assert(false);
		} catch (GoogleFileSharingCommand.GoogleFileSharingException ex) {
			System.assert(ex.getMessage().contains('Access level is required for modifying user/group shares'));
		}
	}

	@IsTest
	private static void modifySharingTestFailUserShareMissing() {
		initMocks();
		coverServiceFactories();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('MS3').withDescription('D').insertRecord();

		try {
			new GoogleLocalFileService()
				.modifyGoogleFileSharing()
				.forFile(f.Id)
				.shareTo(u.Id)
				.withUiAccessLevel('viewer')
				.apply();
			System.assert(false);
		} catch (GoogleFileSharingCommand.GoogleFileSharingException ex) {
			System.assert(ex.getMessage().contains('Matching user/group share not found'));
		}
	}

	@IsTest
	private static void modifySharingTestSuccessLink() {
		initMocks();
		coverServiceFactories();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML1').withDescription('D').insertRecord();
		Account a = new Account(Name = 'ML1-A');
		insert a;

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(a.Id)
			.withLinkedType('Account')
			.insertRecord();

		Test.startTest();
		new GoogleLocalFileService()
			.modifyGoogleFileSharing()
			.forFile(f.Id)
			.shareTo(a.Id)
			.withUiAccessLevel('Collaborator')
			.withVisibility('InternalUsers')
			.apply();
		Test.stopTest();

		GoogleFileLink__c updated = [
			SELECT ShareType__c, Visibility__c
			FROM GoogleFileLink__c
			WHERE Id = :link.Id
			LIMIT 1
		];
		System.assertEquals('Collaborator', updated.ShareType__c);
		System.assertEquals('InternalUsers', updated.Visibility__c);
	}

	@IsTest
	private static void modifySharingTestFailNoInput() {
		initMocks();
		coverServiceFactories();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML2').withDescription('D').insertRecord();
		Account a = new Account(Name = 'ML2-A');
		insert a;

		GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(a.Id)
			.withLinkedType('Account')
			.insertRecord();

		try {
			new GoogleLocalFileService()
				.modifyGoogleFileSharing()
				.forFile(f.Id)
				.shareTo(a.Id)
				.withUiAccessLevel(' ')
				.withVisibility(null)
				.apply();
			System.assert(false);
		} catch (GoogleFileSharingCommand.GoogleFileSharingException ex) {
			System.assert(ex.getMessage().contains('Provide at least access level or visibility'));
		}
	}

	@IsTest
	private static void modifySharingTestFailLinkMissing() {
		initMocks();
		coverServiceFactories();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML3').withDescription('D').insertRecord();
		Account a = new Account(Name = 'ML3-A');
		insert a;

		try {
			new GoogleLocalFileService()
				.modifyGoogleFileSharing()
				.forFile(f.Id)
				.shareTo(a.Id)
				.withUiAccessLevel('Viewer')
				.apply();
			System.assert(false);
		} catch (GoogleFileSharingCommand.GoogleFileSharingException ex) {
			System.assert(ex.getMessage().contains('Matching GoogleFileLink__c not found'));
		}
	}

	@IsTest
	private static void modifySharingTestFailBadShareType() {
		initMocks();
		coverServiceFactories();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML4').withDescription('D').insertRecord();
		Account a = new Account(Name = 'ML4-A');
		insert a;

		GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(a.Id)
			.withLinkedType('Account')
			.insertRecord();

		try {
			new GoogleLocalFileService()
				.modifyGoogleFileSharing()
				.forFile(f.Id)
				.shareTo(a.Id)
				.withUiAccessLevel('NotARealType')
				.apply();
			System.assert(false);
		} catch (GoogleFileSharingCommand.GoogleFileSharingException ex) {
			System.assert(ex.getMessage().contains('Unsupported ShareType'));
		}
	}

	@IsTest
	private static void modifySharingTestFailBadVisibility() {
		initMocks();
		coverServiceFactories();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML5').withDescription('D').insertRecord();
		Account a = new Account(Name = 'ML5-A');
		insert a;

		GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(a.Id)
			.withLinkedType('Account')
			.insertRecord();

		try {
			new GoogleLocalFileService()
				.modifyGoogleFileSharing()
				.forFile(f.Id)
				.shareTo(a.Id)
				.withVisibility('Public')
				.apply();
			System.assert(false);
		} catch (GoogleFileSharingCommand.GoogleFileSharingException ex) {
			System.assert(ex.getMessage().contains('Unsupported Visibility'));
		}
	}
}
