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
@isTest
public class GoogleCloudTestFactory {
	private static final String TEST_AUTHORIZER_CLASS_NAME = 'GoogleCloudTestFactory.TestGoogleAuthorizer';
	private static Integer fakeIdCounter = 0;

	private static final String SHARE_KEY_PREFIX = '02c';

	public static Id fakeId(SObjectType sot) {
		return fakeId(sot.getDescribe().getKeyPrefix());
	}

	public static Id fakeId(String keyPrefix) {
		fakeIdCounter++;
		String idx = String.valueOf(fakeIdCounter);
		return (Id)(keyPrefix + '0'.repeat(12 - idx.length()) + idx);
	}

	public static void initMocks() {
		initMocks(new GoogleDriveHttpMock().withDefaultHappyPath());
	}

	public static void initMocks(HttpCalloutMock httpMock) {
		Test.setMock(HttpCalloutMock.class, httpMock);
		GoogleClientApiProvider.authorizerClassNameOverride = TEST_AUTHORIZER_CLASS_NAME;
		GoogleCacheDriveFolderService.cacheProviderOverride = new GoogleInMemoryCacheProvider();
		setPrivilegedFloor(null);

		if (GoogleMetadataConfigService.configRecordOverride == null) {
			GoogleMetadataConfigService.configRecordOverride = config().build();
		}
	}

	public static Id otherUserId() {
		return fakeId(User.SObjectType);
	}

	public static void bypassTriggers() {
		GTriggerHandler.setBypass('GoogleFileVersionTriggerHandler', true);
		GTriggerHandler.setBypass('GoogleFileLinkTriggerHandler', true);
	}

	public static void grantRecordAccess(Id recordId, Boolean canRead, Boolean canEdit) {
		if (GoogleRecordAccessResolver.accessOverrideByRecordId == null) {
			GoogleRecordAccessResolver.accessOverrideByRecordId = new Map<Id, GoogleRecordAccessDTO>();
		}

		GoogleRecordAccessResolver.accessOverrideByRecordId.put(recordId, new GoogleRecordAccessDTO(recordId, canRead, canEdit));
	}

	public static void denyAllRecordAccess() {
		GoogleRecordAccessResolver.accessOverrideByRecordId = new Map<Id, GoogleRecordAccessDTO>();
	}

	public static Id linkedRecord(String recordName, Boolean canRead, Boolean canEdit) {
		Id linkedRecordId = fakeId(GoogleFile__c.SObjectType);
		grantRecordAccess(linkedRecordId, canRead, canEdit);
		GSOQL.mock(GoogleFileLinkedRecordSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = linkedRecordId, Name = recordName)
		});

		return linkedRecordId;
	}

	public static Id linkedRecord(String recordName) {
		return linkedRecord(recordName, true, true);
	}

	public static Id mockInternalUser() {
		return mockUser(fakeId(User.SObjectType), 'Standard');
	}

	public static Id mockExternalUser() {
		return mockUser(fakeId(User.SObjectType), 'CspLitePortal');
	}

	public static Id mockUser(Id userId, String userType) {
		return mockUser(userId, userType, null);
	}

	public static Id mockUser(Id userId, String userType, String email) {
		GSOQL.mock(GoogleUserSelector.MOCK_ID).thenReturn(new List<SObject>{ buildUser(userId, userType, email) });
		return userId;
	}

	public static User buildUser(Id userId, String userType) {
		return buildUser(userId, userType, null);
	}

	public static User buildUser(Id userId, String userType, String email) {
		return (User) JSON.deserialize(
			JSON.serialize(new Map<String, Object>{
				'attributes' => new Map<String, Object>{ 'type' => 'User' },
				'Id' => userId,
				'UserType' => userType,
				'Email' => email
			}),
			User.class
		);
	}

	public static void mockShares(List<GoogleFile__Share> shares) {
		GSOQL.mock(GoogleFileShareSelector.MOCK_ID).thenReturn(shares);
	}

	public static void mockNoGroupMemberships() {
		GSOQL.mock(GoogleGroupMemberSelector.MOCK_ID).thenReturn(new List<SObject>());
	}

	public static void mockLinks(List<GoogleFileLink__c> links) {
		GSOQL.mock(GoogleFileLinkSelector.MOCK_ID).thenReturn(links);
	}

	public static void setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel floor) {
		GoogleFileAccessResolver.privilegedFloorOverrideSet = true;
		GoogleFileAccessResolver.privilegedFloorOverride = floor;
	}

	public static IGoogleUnitOfWork unitOfWork() {
		return new GoogleCloudUnitOfWork(GoogleCloudConstants.DEFAULT_WRITE_ORDER);
	}

	public static ConfigBuilder config() {
		return new ConfigBuilder();
	}

	public static FileBuilder file() {
		return new FileBuilder();
	}

	public static VersionBuilder version() {
		return new VersionBuilder();
	}

	public static LinkBuilder link() {
		return new LinkBuilder();
	}

	public static ShareBuilder share() {
		return new ShareBuilder();
	}

	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	public class FileBuilder {
		private GoogleFile__c r = new GoogleFile__c();

		public FileBuilder withName(String v) { r.Name = v; return this; }
		public FileBuilder withDescription(String v) { r.Description__c = v; return this; }
		public FileBuilder withSource(String v) { r.Source__c = v; return this; }
		public FileBuilder withOwner(Id ownerId) { r.OwnerId = ownerId; return this; }
		public FileBuilder withUserAccessLevel(String v) { r.UserAccessLevel__c = v; return this; }

		public GoogleFile__c build() {
			if (String.isBlank(r.Name)) r.Name = 'Test File';
			if (String.isBlank(r.Source__c)) r.Source__c = 'Notes & Attachments';
			return r;
		}

		public GoogleFile__c insertRecord() {
			GoogleFile__c out = build();
			insert out;
			return out;
		}
	}

	public class VersionBuilder {
		private GoogleFileVersion__c r = new GoogleFileVersion__c();

		public VersionBuilder forFile(Id fileId) { r.GoogleFileId__c = fileId; return this; }
		public VersionBuilder withName(String v) { r.Name = v; return this; }
		public VersionBuilder withDescription(String v) { r.Description__c = v; return this; }
		public VersionBuilder isLatest(Boolean v) { r.IsLatestFile__c = v; return this; }
		public VersionBuilder withSummary(String v) { r.Summary__c = v; return this; }
		public VersionBuilder withType(String v) { r.Type__c = v; return this; }
		public VersionBuilder withSize(Long v) { r.Size__c = v; return this; }
		public VersionBuilder withDriveId(String v) { r.GoogleDriveFileId__c = v; return this; }
		public VersionBuilder withFolderId(String v) { r.GoogleDriveFolderId__c = v; return this; }
		public VersionBuilder withDocsId(String v) { r.GoogleDocsFileId__c = v; return this; }
		public VersionBuilder withPublicLink(String v) { r.PublicLink__c = v; return this; }
		public VersionBuilder withPublicLinkPermissionId(String v) { r.PublicLinkPermissionId__c = v; return this; }
		public VersionBuilder withPublicLinkExpiration(Datetime v) { r.PublicLinkExpirationDate__c = v; return this; }
		public VersionBuilder withPublicLinkStatus(String v) { r.PublicLinkStatus__c = v; return this; }

		public GoogleFileVersion__c build() {
			if (String.isBlank(r.Name)) r.Name = 'Test Version.pdf';
			if (r.IsLatestFile__c == null) r.IsLatestFile__c = true;
			if (String.isBlank(r.Type__c)) r.Type__c = 'application/pdf';
			if (r.Size__c == null) r.Size__c = 1;
			if (String.isBlank(r.GoogleDriveFileId__c)) r.GoogleDriveFileId__c = 'GD_FILE_ID';
			return r;
		}

		public GoogleFileVersion__c insertRecord() {
			GoogleFileVersion__c out = build();
			insert out;
			return out;
		}
	}

	public class LinkBuilder {
		private GoogleFileLink__c r = new GoogleFileLink__c();

		public LinkBuilder forFile(Id fileId) { r.GoogleFileId__c = fileId; return this; }
		public LinkBuilder withLinkedRecord(Id recordId) { r.LinkedObjectId__c = recordId == null ? null : String.valueOf(recordId); return this; }
		public LinkBuilder withLinkedType(String v) { r.LinkedObjectType__c = v; return this; }
		public LinkBuilder withSource(String v) { r.Source__c = v; return this; }
		public LinkBuilder withShareType(String v) { r.ShareType__c = v; return this; }
		public LinkBuilder withVisibility(String v) { r.Visibility__c = v; return this; }

		public GoogleFileLink__c build() {
			if (String.isBlank(r.ShareType__c)) r.ShareType__c = 'Viewer';
			if (String.isBlank(r.Visibility__c)) r.Visibility__c = 'AllUsers';
			if (String.isBlank(r.LinkedObjectType__c)) r.LinkedObjectType__c = 'GoogleFile__c';
			if (String.isBlank(r.LinkedObjectId__c)) {
				r.LinkedObjectId__c = String.valueOf(fakeId(GoogleFile__c.SObjectType));
			}
			return r;
		}

		public GoogleFileLink__c insertRecord() {
			GoogleFileLink__c out = build();
			insert out;
			return out;
		}
	}

	public class ShareBuilder {
		private GoogleFile__Share r = new GoogleFile__Share();

		public ShareBuilder forFile(Id fileId) { r.ParentId = fileId; return this; }
		public ShareBuilder sharedWith(Id userOrGroupId) { r.UserOrGroupId = userOrGroupId; return this; }
		public ShareBuilder withAccessLevel(String v) { r.AccessLevel = v; return this; }

		public GoogleFile__Share build() {
			if (String.isBlank(r.AccessLevel)) r.AccessLevel = 'Read';
			if (r.UserOrGroupId == null) r.UserOrGroupId = otherUserId();
			r.RowCause = Schema.GoogleFile__Share.RowCause.Manual;

			return (GoogleFile__Share) JSON.deserialize(
				JSON.serialize(new Map<String, Object>{
					'attributes' => new Map<String, Object>{ 'type' => 'GoogleFile__Share' },
					'Id' => fakeId(SHARE_KEY_PREFIX),
					'ParentId' => r.ParentId,
					'UserOrGroupId' => r.UserOrGroupId,
					'AccessLevel' => r.AccessLevel,
					'RowCause' => r.RowCause
				}),
				GoogleFile__Share.class
			);
		}
	}

	public class ConfigBuilder {
		private GoogleClientConfig__mdt r = new GoogleClientConfig__mdt();

		public ConfigBuilder asPackagedRecord() {
			r.DeveloperName = 'GoogleClient';
			r.MasterLabel = 'Google Client';
			return this;
		}

		public ConfigBuilder withUploadFolderId(String v) { r.DefaultGoogleUploadFolderId__c = v; return this; }
		public ConfigBuilder withAdditionalUploadFolderIds(String v) { r.AdditionalGoogleUploadFolderIds__c = v; return this; }
		public ConfigBuilder withFolderStructure(String v) { r.CustomGoogleUploadFolderStructure__c = v; return this; }
		public ConfigBuilder withServiceAccount(String v) { r.CustomGoogleServiceAccount__c = v; return this; }
		public ConfigBuilder withCertificate(String v) { r.CustomGoogleCertificate__c = v; return this; }
		public ConfigBuilder withOrganizationalDomain(String v) { r.OrganizationalDomain__c = v; return this; }
		public ConfigBuilder withPreviewDisabled(Boolean v) { r.IsFilePreviewDisabled__c = v; return this; }
		public ConfigBuilder withBigFileSize(Long v) { r.DefaultBigFileSize__c = v; return this; }
		public ConfigBuilder withDeleteChainSize(Integer v) { r.MaxDeleteChainSize__c = v; return this; }
		public ConfigBuilder withDirectBrowserUpload(Boolean v) { r.IsDirectBrowserUploadEnabled__c = v; return this; }
		public ConfigBuilder withOpenInDrive(Boolean v) { r.IsOpenInDriveEnabled__c = v; return this; }
		public ConfigBuilder withFileExplorerColumns(String v) { r.FileExplorerColumns__c = v; return this; }
		public ConfigBuilder withFileIntelligence(Boolean v) { r.IsFileIntelligenceEnabled__c = v; return this; }
		public ConfigBuilder withGeminiApiKey(String v) { r.CustomGeminiApiKey__c = v; return this; }
		public ConfigBuilder withAiModel(String v) { r.CustomModelName__c = v; return this; }
		public ConfigBuilder withAgentProjectId(String v) { r.CustomAgentProjectId__c = v; return this; }
		public ConfigBuilder withAgentLocation(String v) { r.CustomAgentLocation__c = v; return this; }
		public ConfigBuilder withAiSafetyMode(String v) { r.AiSafetyMode__c = v; return this; }
		public ConfigBuilder withAiPromptSafetyGuardClass(String v) { r.CustomAiPromptSafetyGuardClass__c = v; return this; }
		public ConfigBuilder withSummaryPrompt(String v) { r.CustomSummaryPrompt__c = v; return this; }
		public ConfigBuilder withQuestionPrompt(String v) { r.CustomQuestionPrompt__c = v; return this; }
		public ConfigBuilder withQuestionMaxOutputTokens(Integer v) { r.QuestionMaxOutputTokens__c = v; return this; }

		public GoogleClientConfig__mdt build() {
			return r;
		}

		public GoogleClientConfig__mdt apply() {
			GoogleClientConfig__mdt out = build();
			GoogleMetadataConfigService.configRecordOverride = out;
			return out;
		}
	}
}