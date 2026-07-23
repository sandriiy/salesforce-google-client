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
private class GoogleFileExplorerColumnResolverTest {
	private static void withColumns(String storedColumns) {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			FileExplorerColumns__c = storedColumns
		);
	}

	private static Map<String, GoogleFileColumnDTO> byKey(List<GoogleFileColumnDTO> columns) {
		Map<String, GoogleFileColumnDTO> byKey = new Map<String, GoogleFileColumnDTO>();
		for (GoogleFileColumnDTO column : columns) {
			byKey.put(column.key, column);
		}

		return byKey;
	}

	@IsTest
	private static void testResolveColumnsPositiveBlankUsesDefaults() {
		withColumns(null);

		Test.startTest();
		List<GoogleFileColumnDTO> columns = new GoogleFileExplorerColumnResolver().resolveColumns();
		Test.stopTest();

		Assert.areEqual(5, columns.size());
		Assert.areEqual('title', columns[0].key);
		Assert.areEqual('isLinked', columns[1].key);
		Assert.areEqual('access', columns[2].key);
		Assert.areEqual('owner', columns[3].key);
		Assert.areEqual('lastModified', columns[4].key);
		Assert.areEqual(false, columns[0].isCustomField);
	}

	@IsTest
	private static void testResolveColumnsPositiveHonoursOrder() {
		withColumns('title;summary;type');

		Test.startTest();
		List<GoogleFileColumnDTO> columns = new GoogleFileExplorerColumnResolver().resolveColumns();
		Test.stopTest();

		Assert.areEqual(3, columns.size());
		Assert.areEqual('title', columns[0].key);
		Assert.areEqual('summary', columns[1].key);
		Assert.areEqual('type', columns[2].key);
	}

	@IsTest
	private static void testResolveColumnsPositiveTitleAlwaysFirst() {
		withColumns('summary;type');

		Test.startTest();
		List<GoogleFileColumnDTO> columns = new GoogleFileExplorerColumnResolver().resolveColumns();
		Test.stopTest();

		Assert.areEqual('title', columns[0].key);
	}

	@IsTest
	private static void testResolveColumnsPositiveUnknownTokenRendersEmptyColumn() {
		withColumns('title;Not_A_Field__c');
		GoogleFileExplorerColumnResolver resolver = new GoogleFileExplorerColumnResolver();

		Test.startTest();
		List<GoogleFileColumnDTO> columns = resolver.resolveColumns();
		List<String> additionalFields = resolver.resolveAdditionalVersionFields();
		Test.stopTest();

		GoogleFileColumnDTO unknownColumn = byKey(columns).get('Not_A_Field__c');
		Assert.areNotEqual(null, unknownColumn);
		Assert.areEqual(true, unknownColumn.isCustomField);
		Assert.areEqual('Not_A_Field__c', unknownColumn.label);
		Assert.areEqual('text', unknownColumn.dataType);
		Assert.areEqual(false, additionalFields.contains('Not_A_Field__c'));
	}

	@IsTest
	private static void testResolveColumnsPositiveConfidentialFieldExcludedFromQuery() {
		withColumns('title;GoogleDriveFileId__c');
		GoogleFileExplorerColumnResolver resolver = new GoogleFileExplorerColumnResolver();

		Test.startTest();
		List<GoogleFileColumnDTO> columns = resolver.resolveColumns();
		List<String> additionalFields = resolver.resolveAdditionalVersionFields();
		Test.stopTest();

		Assert.areEqual(true, byKey(columns).containsKey('GoogleDriveFileId__c'));
		Assert.areEqual(false, additionalFields.contains('GoogleDriveFileId__c'));
	}

	@IsTest
	private static void testResolveColumnsPositiveResolvableCustomFieldQueried() {
		withColumns('title;Description__c');
		GoogleFileExplorerColumnResolver resolver = new GoogleFileExplorerColumnResolver();

		Test.startTest();
		List<GoogleFileColumnDTO> columns = resolver.resolveColumns();
		List<String> additionalFields = resolver.resolveAdditionalVersionFields();
		Test.stopTest();

		GoogleFileColumnDTO customColumn = byKey(columns).get('Description__c');
		Assert.areNotEqual(null, customColumn);
		Assert.areEqual(true, customColumn.isCustomField);
		Assert.areEqual(true, String.isNotBlank(customColumn.label));
		Assert.areEqual(true, additionalFields.contains('Description__c'));
	}

	@IsTest
	private static void testResolveAdditionalVersionFieldsPositiveSkipsBaseField() {
		withColumns('title;Summary__c');
		GoogleFileExplorerColumnResolver resolver = new GoogleFileExplorerColumnResolver();

		Test.startTest();
		List<String> additionalFields = resolver.resolveAdditionalVersionFields();
		Test.stopTest();

		Assert.areEqual(false, additionalFields.contains('Summary__c'));
	}

	@IsTest
	private static void testResolveColumnsPositiveCapsAtSeven() {
		withColumns('isLinked;access;owner;lastModified;createdDate;type;size;summary');

		Test.startTest();
		List<GoogleFileColumnDTO> columns = new GoogleFileExplorerColumnResolver().resolveColumns();
		Test.stopTest();

		Assert.areEqual(GoogleCloudConstants.MAX_FILE_EXPLORER_COLUMNS, columns.size());
		Assert.areEqual('title', columns[0].key);
	}
}
