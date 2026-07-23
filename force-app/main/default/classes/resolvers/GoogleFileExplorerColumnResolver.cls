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
public without sharing class GoogleFileExplorerColumnResolver {
	private final GoogleMetadataConfigService googleConfig;

	public GoogleFileExplorerColumnResolver() {
		this(new GoogleMetadataConfigService());
	}

	public GoogleFileExplorerColumnResolver(GoogleMetadataConfigService googleConfig) {
		this.googleConfig = googleConfig;
	}

	public List<GoogleFileColumnDTO> resolveColumns() {
		Map<String, Schema.SObjectField> versionFields = GoogleFileVersion__c.SObjectType.getDescribe().fields.getMap();
		Set<String> confidentialFieldNames = confidentialFieldNames();

		List<GoogleFileColumnDTO> resolvedColumns = new List<GoogleFileColumnDTO>();
		for (String token : orderedTokens()) {
			if (GoogleCloudConstants.FILE_EXPLORER_COLUMNS.contains(token)) {
				resolvedColumns.add(new GoogleFileColumnDTO(token, false, null, null));
				continue;
			}

			resolvedColumns.add(resolveCustomColumn(token, versionFields, confidentialFieldNames));
		}

		return resolvedColumns;
	}

	public List<String> resolveAdditionalVersionFields() {
		Map<String, Schema.SObjectField> versionFields = GoogleFileVersion__c.SObjectType.getDescribe().fields.getMap();
		Set<String> excludedFieldNames = confidentialFieldNames();
		excludedFieldNames.addAll(alreadyQueriedFieldNames());

		List<String> additionalFields = new List<String>();
		for (String token : orderedTokens()) {
			if (GoogleCloudConstants.FILE_EXPLORER_COLUMNS.contains(token)) continue;

			String fieldKey = token.toLowerCase();
			if (versionFields.containsKey(fieldKey) && !excludedFieldNames.contains(fieldKey)) {
				additionalFields.add(versionFields.get(fieldKey).getDescribe().getName());
			}
		}

		return additionalFields;
	}

	private GoogleFileColumnDTO resolveCustomColumn(String token, Map<String, Schema.SObjectField> versionFields, Set<String> confidentialFieldNames) {
		String fieldKey = token.toLowerCase();
		if (!versionFields.containsKey(fieldKey) || confidentialFieldNames.contains(fieldKey)) {
			return new GoogleFileColumnDTO(token, true, token, 'text');
		}

		Schema.DescribeFieldResult fieldDescribe = versionFields.get(fieldKey).getDescribe();
		return new GoogleFileColumnDTO(fieldDescribe.getName(), true, fieldDescribe.getLabel(), toDataType(fieldDescribe.getType()));
	}

	private List<String> orderedTokens() {
		List<String> orderedTokens = new List<String>();
		Set<String> seen = new Set<String>();

		if (!seen.contains(GoogleCloudConstants.FILE_COLUMN_TITLE)) {
			orderedTokens.add(GoogleCloudConstants.FILE_COLUMN_TITLE);
			seen.add(GoogleCloudConstants.FILE_COLUMN_TITLE);
		}

		for (String token : googleConfig.getFileExplorerColumns()) {
			if (String.isBlank(token)) continue;
			String trimmed = token.trim();
			String dedupeKey = trimmed.toLowerCase();
			if (seen.contains(dedupeKey)) continue;

			orderedTokens.add(trimmed);
			seen.add(dedupeKey);

			if (orderedTokens.size() >= GoogleCloudConstants.MAX_FILE_EXPLORER_COLUMNS) break;
		}

		return orderedTokens;
	}

	private Set<String> confidentialFieldNames() {
		Set<String> confidentialFieldNames = new Set<String>();
		for (Schema.SObjectField confidentialField : GoogleFileVersionSelector.CONFIDENTIAL_FIELDS) {
			confidentialFieldNames.add(confidentialField.getDescribe().getName().toLowerCase());
		}

		return confidentialFieldNames;
	}

	private Set<String> alreadyQueriedFieldNames() {
		Set<String> alreadyQueriedFieldNames = new Set<String>();
		for (Schema.SObjectField baseField : GoogleFileVersionSelector.BASE_FIELDS) {
			alreadyQueriedFieldNames.add(baseField.getDescribe().getName().toLowerCase());
		}

		return alreadyQueriedFieldNames;
	}

	private String toDataType(Schema.DisplayType displayType) {
		switch on displayType {
			when DATE, DATETIME {
				return 'date';
			}
			when INTEGER, DOUBLE, CURRENCY, PERCENT, LONG {
				return 'number';
			}
			when BOOLEAN {
				return 'boolean';
			}
			when else {
				return 'text';
			}
		}
	}
}
