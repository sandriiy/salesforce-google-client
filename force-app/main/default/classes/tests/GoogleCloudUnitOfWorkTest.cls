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
private class GoogleCloudUnitOfWorkTest {
	private static GoogleCloudUnitOfWork buildUow() {
		return new GoogleCloudUnitOfWork(GoogleCloudConstants.DEFAULT_WRITE_ORDER);
	}

	@IsTest
	private static void testCommitWorkPositiveInsert() {
		GoogleCloudTestFactory.bypassTriggers();
		GoogleCloudUnitOfWork uow = buildUow();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('UoW_Insert_1').build();
		uow.registerNew(localFile);

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Assert.isNotNull(localFile.Id);
		Assert.areEqual(1, [SELECT COUNT() FROM GoogleFile__c WHERE Name = 'UoW_Insert_1']);
	}

	@IsTest
	private static void testCommitWorkPositiveInsertList() {
		GoogleCloudTestFactory.bypassTriggers();
		GoogleCloudUnitOfWork uow = buildUow();

		List<GoogleFile__c> localFiles = new List<GoogleFile__c>{
			GoogleCloudTestFactory.file().withName('UoW_IL_1').build(),
			GoogleCloudTestFactory.file().withName('UoW_IL_2').build()
		};
		uow.registerNew(localFiles);

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Assert.areEqual(2, [SELECT COUNT() FROM GoogleFile__c WHERE Name LIKE 'UoW_IL_%']);
	}

	@IsTest
	private static void testCommitWorkPositiveUpdate() {
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('UoW_Update_Before').insertRecord();

		GoogleCloudUnitOfWork uow = buildUow();
		localFile.Name = 'UoW_Update_After';
		uow.registerDirty(localFile);

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Assert.areEqual('UoW_Update_After', [SELECT Name FROM GoogleFile__c WHERE Id = :localFile.Id].Name);
	}

	@IsTest
	private static void testCommitWorkPositiveUpdateList() {
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFile__c firstFile = GoogleCloudTestFactory.file().withName('UoW_UL_1').insertRecord();
		GoogleFile__c secondFile = GoogleCloudTestFactory.file().withName('UoW_UL_2').insertRecord();

		GoogleCloudUnitOfWork uow = buildUow();
		firstFile.Name = 'UoW_UL_1_Updated';
		secondFile.Name = 'UoW_UL_2_Updated';
		uow.registerDirty(new List<GoogleFile__c>{ firstFile, secondFile });

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Assert.areEqual(2, [SELECT COUNT() FROM GoogleFile__c WHERE Name LIKE 'UoW_UL_%_Updated']);
	}

	@IsTest
	private static void testCommitWorkPositiveSparseUpdate() {
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('UoW_Sparse_Before')
			.withDescription('Preserved Description')
			.insertRecord();

		GoogleCloudUnitOfWork uow = buildUow();
		localFile.Name = 'UoW_Sparse_After';
		localFile.Description__c = 'Discarded Description';
		uow.registerDirty(localFile, new List<Schema.SObjectField>{ GoogleFile__c.Name });

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		GoogleFile__c reloaded = [SELECT Name, Description__c FROM GoogleFile__c WHERE Id = :localFile.Id];
		Assert.areEqual('UoW_Sparse_After', reloaded.Name);
		Assert.areEqual('Preserved Description', reloaded.Description__c);
	}

	@IsTest
	private static void testCommitWorkPositiveDelete() {
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('UoW_Delete_1').insertRecord();

		GoogleCloudUnitOfWork uow = buildUow();
		uow.registerDeleted(localFile);

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Assert.areEqual(0, [SELECT COUNT() FROM GoogleFile__c WHERE Id = :localFile.Id]);
	}

	@IsTest
	private static void testCommitWorkPositiveDeleteList() {
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFile__c firstFile = GoogleCloudTestFactory.file().withName('UoW_DL_1').insertRecord();
		GoogleFile__c secondFile = GoogleCloudTestFactory.file().withName('UoW_DL_2').insertRecord();

		GoogleCloudUnitOfWork uow = buildUow();
		uow.registerDeleted(new List<GoogleFile__c>{ firstFile, secondFile });

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Assert.areEqual(0, [SELECT COUNT() FROM GoogleFile__c WHERE Id IN (:firstFile.Id, :secondFile.Id)]);
	}

	@IsTest
	private static void testRegisterDirtyNegativeNoId() {
		GoogleCloudUnitOfWork uow = buildUow();

		try {
			uow.registerDirty(GoogleCloudTestFactory.file().withName('NoId').build());
			Assert.fail('registerDirty should reject a record without an Id');
		} catch (GoogleCloudUnitOfWork.UnitOfWorkException ex) {
			Assert.isTrue(ex.getMessage().contains('requires a record with an Id'));
		}
	}

	@IsTest
	private static void testRegisterDeletedNegativeNoId() {
		GoogleCloudUnitOfWork uow = buildUow();

		try {
			uow.registerDeleted(GoogleCloudTestFactory.file().withName('NoId').build());
			Assert.fail('registerDeleted should reject a record without an Id');
		} catch (GoogleCloudUnitOfWork.UnitOfWorkException ex) {
			Assert.isTrue(ex.getMessage().contains('requires a record with an Id'));
		}
	}

	@IsTest
	private static void testCommitWorkPositiveWithRelationship() {
		GoogleCloudTestFactory.bypassTriggers();
		GoogleCloudUnitOfWork uow = buildUow();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('UoW_Rel_File').build();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version().withName('UoW_Rel_Version.pdf').build();

		uow.registerNew(localFile);
		uow.registerNew(localFileVersion, GoogleFileVersion__c.GoogleFileId__c, localFile);

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Assert.isNotNull(localFile.Id);
		Assert.isNotNull(localFileVersion.Id);

		GoogleFileVersion__c reloaded = [SELECT GoogleFileId__c FROM GoogleFileVersion__c WHERE Id = :localFileVersion.Id];
		Assert.areEqual(localFile.Id, reloaded.GoogleFileId__c);
	}

	@IsTest
	private static void testCommitWorkPositiveAllOrNoneFalse() {
		GoogleCloudTestFactory.bypassTriggers();
		GoogleCloudUnitOfWork uow = buildUow();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('UoW_Partial').build();
		uow.registerNew(localFile);

		Test.startTest();
		uow.commitWork(false);
		Test.stopTest();

		Assert.isNotNull(localFile.Id);
	}

	@IsTest
	private static void testCommitWorkPositiveNullInputs() {
		GoogleCloudUnitOfWork uow = new GoogleCloudUnitOfWork(null);

		uow.registerNew((SObject) null);
		uow.registerNew((List<SObject>) null);
		uow.registerDirty((List<SObject>) null);
		uow.registerDeleted((SObject) null);
		uow.registerDeleted((List<SObject>) null);
		uow.configureDeleteOrder(null);

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Assert.areEqual(0, [SELECT COUNT() FROM GoogleFile__c]);
	}

	@IsTest
	private static void testConfigureDeleteOrderPositive() {
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('UoW_DO_File').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version().forFile(localFile.Id).insertRecord();

		IGoogleUnitOfWork uow = buildUow();
		uow.configureDeleteOrder(new List<SObjectType>{
			GoogleFileVersion__c.SObjectType,
			GoogleFile__c.SObjectType
		});
		uow.registerDeleted(localFileVersion);
		uow.registerDeleted(localFile);

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Assert.areEqual(0, [SELECT COUNT() FROM GoogleFile__c WHERE Id = :localFile.Id]);
		Assert.areEqual(0, [SELECT COUNT() FROM GoogleFileVersion__c WHERE Id = :localFileVersion.Id]);
	}

	@IsTest
	private static void testRegisterRelationshipPositive() {
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('UoW_RegRel_File').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version().withName('UoW_RegRel_Version.pdf').build();

		GoogleCloudUnitOfWork uow = buildUow();
		uow.registerNew(localFileVersion);
		uow.registerRelationship(localFileVersion, GoogleFileVersion__c.GoogleFileId__c, localFile);

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		GoogleFileVersion__c reloaded = [SELECT GoogleFileId__c FROM GoogleFileVersion__c WHERE Id = :localFileVersion.Id];
		Assert.areEqual(localFile.Id, reloaded.GoogleFileId__c);
	}

	@IsTest
	private static void testCommitWorkNegativeUnresolvedDependency() {
		GoogleCloudTestFactory.bypassTriggers();
		GoogleCloudUnitOfWork uow = buildUow();

		GoogleFile__c unregisteredParent = GoogleCloudTestFactory.file().withName('UoW_Orphan_Parent').build();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version().withName('UoW_Orphan.pdf').build();
		uow.registerNew(localFileVersion, GoogleFileVersion__c.GoogleFileId__c, unregisteredParent);

		try {
			uow.commitWork(true);
			Assert.fail('commitWork should reject a child whose parent is never registered');
		} catch (GoogleCloudUnitOfWork.UnitOfWorkException ex) {
			Assert.isTrue(ex.getMessage().contains('could not resolve dependencies'));
		}
	}
}
