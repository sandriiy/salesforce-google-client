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
private class GoogleFileAccessCheckActionTest {
	@IsTest
	private static void testCheckAccessPositiveOwnerCanChangeTheFileAndItsVersion() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Owned').insertRecord();
		GoogleFileVersion__c localVersion = GoogleCloudTestFactory.version().forFile(localFile.Id).insertRecord();

		Test.startTest();
		List<GoogleFileAccessCheckAction.Output> outputs = GoogleFileAccessCheckAction.checkAccess(new List<GoogleFileAccessCheckAction.Input>{
			toInput(localVersion.Id),
			toInput(localFile.Id)
		});
		Test.stopTest();

		Assert.areEqual(2, outputs.size(), 'Flow expects one output per input');
		for (GoogleFileAccessCheckAction.Output output : outputs) {
			Assert.areEqual('Edit', output.accessLevel);
			Assert.isTrue(output.canView);
			Assert.isTrue(output.canEdit);
		}
	}

	@IsTest
	private static void testCheckAccessPositiveViewerLinkCanViewButNotEdit() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.denyAllRecordAccess();
		Id readableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(readableRecordId, true, false);
		Id viewableFileId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = viewableFileId, OwnerId = GoogleCloudTestFactory.otherUserId())
		});
		GoogleCloudTestFactory.mockLinks(new List<GoogleFileLink__c>{
			GoogleCloudTestFactory.link().forFile(viewableFileId).withLinkedRecord(readableRecordId).withShareType('Viewer').build()
		});

		Test.startTest();
		List<GoogleFileAccessCheckAction.Output> outputs = GoogleFileAccessCheckAction.checkAccess(new List<GoogleFileAccessCheckAction.Input>{ toInput(viewableFileId) });
		Test.stopTest();

		Assert.areEqual('View', outputs[0].accessLevel);
		Assert.isTrue(outputs[0].canView);
		Assert.isFalse(outputs[0].canEdit, 'A viewer must not be offered the editable form');
	}

	@IsTest
	private static void testCheckAccessNegativeUnreachableAndUnknownIdsGetNoAccessInOrder() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.denyAllRecordAccess();
		Id unreachableFileId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = unreachableFileId, OwnerId = GoogleCloudTestFactory.otherUserId())
		});

		Test.startTest();
		List<GoogleFileAccessCheckAction.Output> outputs = GoogleFileAccessCheckAction.checkAccess(new List<GoogleFileAccessCheckAction.Input>{
			toInput(unreachableFileId),
			toInput(GoogleCloudTestFactory.fakeId(GoogleFileVersion__c.SObjectType)),
			toInput(null)
		});
		Test.stopTest();

		Assert.areEqual(3, outputs.size(), 'Flow expects one output per input');
		for (GoogleFileAccessCheckAction.Output output : outputs) {
			Assert.isNull(output.accessLevel);
			Assert.isFalse(output.canView, 'A file the user cannot open, or one that does not exist, must not be shown');
			Assert.isFalse(output.canEdit);
		}
	}

	@IsTest
	private static void testCheckAccessNegativeEmptyRequestReturnsNothing() {
		Test.startTest();
		List<GoogleFileAccessCheckAction.Output> outputs = GoogleFileAccessCheckAction.checkAccess(new List<GoogleFileAccessCheckAction.Input>());
		Test.stopTest();

		Assert.isTrue(outputs.isEmpty());
	}

	private static GoogleFileAccessCheckAction.Input toInput(Id fileOrVersionId) {
		GoogleFileAccessCheckAction.Input input = new GoogleFileAccessCheckAction.Input();
		input.fileOrVersionId = fileOrVersionId;
		return input;
	}
}
