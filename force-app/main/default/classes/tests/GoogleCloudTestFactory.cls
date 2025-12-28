public with sharing class GoogleCloudTestFactory {
	public static FileBuilder file() { return new FileBuilder(); }
	public static VersionBuilder version() { return new VersionBuilder(); }
	public static LinkBuilder link() { return new LinkBuilder(); }

	public class FileBuilder {
		private GoogleFile__c r = new GoogleFile__c();

		public FileBuilder withName(String v) { r.Name = v; return this; }
		public FileBuilder withDescription(String v) { r.Description__c = v; return this; }
		public FileBuilder withSource(String v) { r.Source__c = v; return this; }
		public FileBuilder withOwner(Id ownerId) { r.OwnerId = ownerId; return this; }
		public FileBuilder withUserAccessLevel(String v) { r.UserAccessLevel__c = v; return this; }
		public FileBuilder forRecord(Id recordId) {
			Map<String, Schema.SObjectField> m = GoogleFile__c.SObjectType.getDescribe().fields.getMap();

			if (m.containsKey('RecordId__c')) {
				r.put('RecordId__c', recordId);
				return this;
			}
			if (m.containsKey('RelatedRecordId__c')) {
				r.put('RelatedRecordId__c', recordId);
				return this;
			}
			if (m.containsKey('LinkedRecordId__c')) {
				r.put('LinkedRecordId__c', recordId);
				return this;
			}

			// Otherwise, find the first updateable reference field that can point to Account (or generic)
			for (String api : m.keySet()) {
				Schema.DescribeFieldResult d = m.get(api).getDescribe();
				if (d.getType() != Schema.DisplayType.REFERENCE) continue;
				if (!d.isCreateable()) continue;

				List<Schema.SObjectType> refs = d.getReferenceTo();
				if (refs == null || refs.isEmpty()) continue;

				for (Schema.SObjectType t : refs) {
					if (t == Account.SObjectType) {
						r.put(api, recordId);
						return this;
					}
				}
			}

			return this;
		}

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
		public VersionBuilder withType(String v) { r.Type__c = v; return this; }
		public VersionBuilder withSize(Long v) { r.Size__c = v; return this; }
		public VersionBuilder withDriveId(String v) { r.GoogleDriveFileId__c = v; return this; }
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
		public LinkBuilder withShareType(String v) { r.ShareType__c = v; return this; }
		public LinkBuilder withVisibility(String v) { r.Visibility__c = v; return this; }

		public GoogleFileLink__c build() {
			if (String.isBlank(r.ShareType__c)) r.ShareType__c = 'Viewer';
			if (String.isBlank(r.Visibility__c)) r.Visibility__c = 'AllUsers';
			if (String.isBlank(r.LinkedObjectType__c)) r.LinkedObjectType__c = 'Account';
			if (String.isBlank(r.LinkedObjectId__c)) {
				Account a = new Account(Name = 'Test Linked Record');
				insert a;
				r.LinkedObjectId__c = String.valueOf(a.Id);
			}
			return r;
		}

		public GoogleFileLink__c insertRecord() {
			GoogleFileLink__c out = build();
			insert out;
			return out;
		}
	}

	public static User newUser() {
		Profile p = [SELECT Id FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
		User u = new User(
			ProfileId = p.Id,
			Alias = 'tuser',
			Email = 'tuser+' + String.valueOf(Crypto.getRandomLong()) + '@example.com',
			EmailEncodingKey = 'UTF-8',
			LastName = 'TestUser',
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US',
			TimeZoneSidKey = 'America/New_York',
			UserName = 'tuser+' + String.valueOf(Crypto.getRandomLong()) + '@example.com'
		);
		
		insert u;
		return u;
	}
}