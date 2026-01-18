@IsTest
private class GoogleLocalFileServiceTest {
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
		System.assertNotEquals(null, s.deleteGoogleFileRecord());
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
			SELECT Id, Name, GoogleFileId__c, LinkedObjectName__c, LinkedObjectId__c, LinkedObjectType__c, ShareType__c, Visibility__c
			FROM GoogleFileLink__c
			WHERE GoogleFileId__c = :f.Id
		];

		GSOQL.mock(GoogleFileLinkSelector.MOCK_ID).thenReturn(links);

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
			SELECT Id, Name, GoogleFileId__c, LinkedObjectName__c, LinkedObjectId__c, LinkedObjectType__c, ShareType__c, Visibility__c
			FROM GoogleFileLink__c
			WHERE GoogleFileId__c = :f.Id
		];
		GSOQL.mock(GoogleFileLinkSelector.MOCK_ID).thenReturn(links);

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
			SELECT Id, Name, GoogleFileId__c, LinkedObjectName__c, LinkedObjectId__c, LinkedObjectType__c, ShareType__c, Visibility__c
			FROM GoogleFileLink__c
			WHERE GoogleFileId__c = :f.Id
		];
		GSOQL.mock(GoogleFileLinkSelector.MOCK_ID).thenReturn(links);

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

		GSOQL.mock(GoogleFileVersionSelector.MOCK_ID).thenReturn(new List<SObject>{
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

		GSOQL.mock(GoogleFileVersionSelector.MOCK_ID).thenReturn(new List<SObject>{
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
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{ fileFromSelector });

		GoogleFileCreateRequestDTO request = new GoogleFileCreateRequestDTO();
		request.recordId = a.Id;
		request.googleDriveId = 'GD_NEW';
		request.fileName = 'MyVeryLongName_' + String.valueOf(Crypto.getRandomLong()) + '.pdf';
		request.fileType = 'application/pdf';
		request.fileSize = 123L;
		request.parentFolderId = 'FOLDER1';
		request.source = 'Notes & Attachments';
		request.localGoogleFileId = null;

		Test.startTest();
		GoogleFile__c out = new GoogleLocalFileService().createGoogleFileRecord(request);
		Test.stopTest();
	}

	@IsTest
	private static void createGoogleFileRecordTestSuccessVersion() {
		initMocks();
		coverServiceFactories();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('Base').withDescription('D').insertRecord();
		GoogleCloudTestFactory.version().forFile(f.Id).withName('Old.pdf').withType('application/pdf').withSize(1).withDriveId('GD_OLD').withDocsId('DOCS_OLD').insertRecord();

		GoogleFile__c fileFromSelector = new GoogleFile__c(Id = f.Id, Name = 'Base');
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{ fileFromSelector });

		GoogleFileCreateRequestDTO request = new GoogleFileCreateRequestDTO();
		request.localGoogleFileId = f.Id;
		request.googleDriveId = 'GD_NEWVER';
		request.fileName = 'New.docx';
		request.fileType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
		request.fileSize = 10L;
		request.parentFolderId = 'FOLDER2';

		Test.startTest();
		GoogleFile__c out = new GoogleLocalFileService().createGoogleFileRecord(request);
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

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>());

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
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{ mocked });

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
}