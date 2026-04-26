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
	@IsTest
	private static void testCommitWorkPositiveInsert() {
		GoogleCloudUnitOfWork uow = new GoogleCloudUnitOfWork(new List<SObjectType>{ Account.SObjectType });

		Account acc = new Account(Name = 'UoW_Insert_1');
		uow.registerNew(acc);

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Assert.isNotNull(acc.Id);
		Assert.areEqual(1, [SELECT count() FROM Account WHERE Name = 'UoW_Insert_1']);
	}

	@IsTest
	private static void testCommitWorkPositiveInsertList() {
		GoogleCloudUnitOfWork uow = new GoogleCloudUnitOfWork(new List<SObjectType>{ Account.SObjectType });

		List<Account> accounts = new List<Account>{
			new Account(Name = 'UoW_IL_1'),
			new Account(Name = 'UoW_IL_2')
		};
		uow.registerNew(accounts);

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Assert.areEqual(2, [SELECT count() FROM Account WHERE Name LIKE 'UoW_IL_%']);
	}

	@IsTest
	private static void testCommitWorkPositiveUpdate() {
		Account acc = new Account(Name = 'UoW_Update_Before');
		insert acc;

		GoogleCloudUnitOfWork uow = new GoogleCloudUnitOfWork(new List<SObjectType>{ Account.SObjectType });
		acc.Name = 'UoW_Update_After';
		uow.registerDirty(acc);

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Assert.areEqual('UoW_Update_After', [SELECT Name FROM Account WHERE Id = :acc.Id].Name);
	}

	@IsTest
	private static void testCommitWorkPositiveUpdateList() {
		Account acc1 = new Account(Name = 'UoW_UL_1');
		Account acc2 = new Account(Name = 'UoW_UL_2');
		insert new List<Account>{ acc1, acc2 };

		GoogleCloudUnitOfWork uow = new GoogleCloudUnitOfWork(new List<SObjectType>{ Account.SObjectType });
		acc1.Name = 'UoW_UL_1_Updated';
		acc2.Name = 'UoW_UL_2_Updated';
		uow.registerDirty(new List<Account>{ acc1, acc2 });

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Assert.areEqual(2, [SELECT count() FROM Account WHERE Name LIKE 'UoW_UL_%_Updated']);
	}

	@IsTest
	private static void testCommitWorkPositiveSparseUpdate() {
		Account acc = new Account(Name = 'UoW_Sparse_Before', Description = 'D');
		insert acc;

		GoogleCloudUnitOfWork uow = new GoogleCloudUnitOfWork(new List<SObjectType>{ Account.SObjectType });
		acc.Name = 'UoW_Sparse_After';
		uow.registerDirty(acc, new List<Schema.SObjectField>{ Account.Name });

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Account reloaded = [SELECT Name, Description FROM Account WHERE Id = :acc.Id];
		Assert.areEqual('UoW_Sparse_After', reloaded.Name);
		Assert.areEqual('D', reloaded.Description);
	}

	@IsTest
	private static void testCommitWorkPositiveDelete() {
		Account acc = new Account(Name = 'UoW_Delete_1');
		insert acc;

		GoogleCloudUnitOfWork uow = new GoogleCloudUnitOfWork(new List<SObjectType>{ Account.SObjectType });
		uow.registerDeleted(acc);

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Assert.areEqual(0, [SELECT count() FROM Account WHERE Id = :acc.Id]);
	}

	@IsTest
	private static void testCommitWorkPositiveDeleteList() {
		Account acc1 = new Account(Name = 'UoW_DL_1');
		Account acc2 = new Account(Name = 'UoW_DL_2');
		insert new List<Account>{ acc1, acc2 };

		GoogleCloudUnitOfWork uow = new GoogleCloudUnitOfWork(new List<SObjectType>{ Account.SObjectType });
		uow.registerDeleted(new List<Account>{ acc1, acc2 });

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Assert.areEqual(0, [SELECT count() FROM Account WHERE Id IN (:acc1.Id, :acc2.Id)]);
	}

	@IsTest
	private static void testRegisterDirtyNegativeNoId() {
		GoogleCloudUnitOfWork uow = new GoogleCloudUnitOfWork(new List<SObjectType>{ Account.SObjectType });

		try {
			uow.registerDirty(new Account(Name = 'NoId'));
			Assert.isTrue(false);
		} catch (GoogleCloudUnitOfWork.UnitOfWorkException ex) {
			Assert.isTrue(ex.getMessage().contains('requires a record with an Id'));
		}
	}

	@IsTest
	private static void testRegisterDeletedNegativeNoId() {
		GoogleCloudUnitOfWork uow = new GoogleCloudUnitOfWork(new List<SObjectType>{ Account.SObjectType });

		try {
			uow.registerDeleted(new Account(Name = 'NoId'));
			Assert.isTrue(false);
		} catch (GoogleCloudUnitOfWork.UnitOfWorkException ex) {
			Assert.isTrue(ex.getMessage().contains('requires a record with an Id'));
		}
	}

	@IsTest
	private static void testCommitWorkPositiveWithRelationship() {
		GoogleCloudUnitOfWork uow = new GoogleCloudUnitOfWork(new List<SObjectType>{
			Account.SObjectType,
			Contact.SObjectType
		});

		Account acc = new Account(Name = 'UoW_Rel_Acc');
		Contact con = new Contact(LastName = 'UoW_Rel_Con');

		uow.registerNew(acc);
		uow.registerNew(con, Contact.AccountId, acc);

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Assert.isNotNull(acc.Id);
		Assert.isNotNull(con.Id);
		Contact reloaded = [SELECT AccountId FROM Contact WHERE Id = :con.Id];
		Assert.areEqual(acc.Id, reloaded.AccountId);
	}

	@IsTest
	private static void testCommitWorkPositiveAllOrNoneFalse() {
		GoogleCloudUnitOfWork uow = new GoogleCloudUnitOfWork(new List<SObjectType>{ Account.SObjectType });

		Account acc = new Account(Name = 'UoW_Partial');
		uow.registerNew(acc);

		Test.startTest();
		uow.commitWork(false);
		Test.stopTest();

		Assert.isNotNull(acc.Id);
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

		Assert.isTrue(true);
	}

	@IsTest
	private static void testConfigureDeleteOrderPositive() {
		Account acc1 = new Account(Name = 'UoW_DO_1');
		insert acc1;

		GoogleCloudUnitOfWork uow = new GoogleCloudUnitOfWork(new List<SObjectType>{ Account.SObjectType });
		uow.configureDeleteOrder(new List<SObjectType>{ Account.SObjectType });
		uow.registerDeleted(acc1);

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Assert.areEqual(0, [SELECT count() FROM Account WHERE Id = :acc1.Id]);
	}

	@IsTest
	private static void testRegisterRelationshipPositive() {
		Account acc = new Account(Name = 'UoW_RegRel');
		insert acc;

		Contact con = new Contact(LastName = 'UoW_RegRel_Con');

		GoogleCloudUnitOfWork uow = new GoogleCloudUnitOfWork(new List<SObjectType>{
			Contact.SObjectType
		});
		uow.registerNew(con);
		uow.registerRelationship(con, Contact.AccountId, acc);

		Test.startTest();
		uow.commitWork(true);
		Test.stopTest();

		Contact reloaded = [SELECT AccountId FROM Contact WHERE Id = :con.Id];
		Assert.areEqual(acc.Id, reloaded.AccountId);
	}
}
