public without sharing class GoogleFilePageDetailsCommand {
	private static final String HEADER_FIELD_SET_NAME = 'Header';

	public RetrieveHeaderCommand retrieveHeader() {
		return new RetrieveHeaderCommand();
	}

	public class RetrieveHeaderCommand {
		private Id fileId;

		public RetrieveHeaderCommand forFile(Id fileId) {
			this.fileId = fileId;
			return this;
		}

		public GoogleFileHeaderInfoDTO execute() {
			GoogleFileHeaderInfoDTO result = createEmptyResult();

			if (fileId == null) {
				return result;
			}

			Schema.DescribeSObjectResult describeResult = GoogleFile__c.SObjectType.getDescribe();
			Map<String, Schema.SObjectField> fieldTokenByApiName = describeResult.fields.getMap();

			List<String> requestedHeaderFields = resolveHeaderFieldApiNames();
			if (requestedHeaderFields.isEmpty()) {
				return result;
			}

			HeaderQueryPlan queryPlan = buildHeaderQueryPlan(requestedHeaderFields, fieldTokenByApiName);

			Logger.info('File Header Retrieve: Local File ID: ' + fileId + '; Requested Fields: ' + String.join(queryPlan.requestedFieldApiNames, ','));

			GoogleFile__c fileRecord = fetchFileRecord(fileId, queryPlan.selectFields);
			if (fileRecord == null) {
				return result;
			}

			result.name = fileRecord.Name;
			result.compactFields = buildCompactFields(fileRecord, queryPlan, fieldTokenByApiName);
			return result;
		}

		private GoogleFileHeaderInfoDTO createEmptyResult() {
			GoogleFileHeaderInfoDTO result = new GoogleFileHeaderInfoDTO();
			result.name = null;
			result.compactFields = new List<GoogleFileHeaderInfoDTO.CompactFieldDTO>();
			return result;
		}

		private GoogleFile__c fetchFileRecord(Id fileId, List<String> selectFields) {
			List<String> selectFieldsWithName = new List<String>(selectFields);
			if (!selectFields.contains('Name')) selectFieldsWithName.add('Name');

			return (GoogleFile__c) GoogleFileSelector.query()
				.byRecordId(fileId)
				.withSpecificFields(selectFieldsWithName)
				.toObject();
		}

		private List<GoogleFileHeaderInfoDTO.CompactFieldDTO> buildCompactFields(GoogleFile__c fileRecord, HeaderQueryPlan queryPlan, Map<String, Schema.SObjectField> fieldTokenByApiName) {
			List<GoogleFileHeaderInfoDTO.CompactFieldDTO> compactFields = new List<GoogleFileHeaderInfoDTO.CompactFieldDTO>();

			for (String apiName : queryPlan.requestedFieldApiNames) {
				Schema.SObjectField fieldToken = fieldTokenByApiName.get(apiName);
				if (fieldToken == null) {
					continue;
				}

				Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
				GoogleFileHeaderInfoDTO.CompactFieldDTO fieldDto = buildFieldDto(
					fileRecord,
					apiName,
					fieldDescribe,
					queryPlan.relationshipNameByApiName.get(apiName)
				);

				compactFields.add(fieldDto);
			}

			return compactFields;
		}

		private GoogleFileHeaderInfoDTO.CompactFieldDTO buildFieldDto(GoogleFile__c fileRecord, String apiName, Schema.DescribeFieldResult fieldDescribe, String relationshipName) {
			GoogleFileHeaderInfoDTO.CompactFieldDTO fieldDto = new GoogleFileHeaderInfoDTO.CompactFieldDTO();
			fieldDto.apiName = apiName;
			fieldDto.label = fieldDescribe.getLabel();

			Boolean isReference = fieldDescribe.getType() == Schema.DisplayType.REFERENCE;
			fieldDto.isReference = isReference;

			Object rawValue = fileRecord.get(apiName);
			fieldDto.referenceId = (isReference && rawValue != null) ? (Id) rawValue : null;

			fieldDto.displayValue = resolveDisplayValue(fileRecord, rawValue, relationshipName);
			return fieldDto;
		}

		private String resolveDisplayValue(GoogleFile__c fileRecord, Object rawValue, String relationshipName) {
			if (!String.isBlank(relationshipName)) {
				SObject relatedRecord = fileRecord.getSObject(relationshipName);
				Object relatedName = relatedRecord == null ? null : relatedRecord.get('Name');

				if (relatedName != null) {
					return String.valueOf(relatedName);
				}
			}

			return rawValue == null ? null : String.valueOf(rawValue);
		}

		private HeaderQueryPlan buildHeaderQueryPlan(List<String> requestedHeaderFields, Map<String, Schema.SObjectField> fieldTokenByApiName) {
			HeaderQueryPlan plan = new HeaderQueryPlan();
			plan.requestedFieldApiNames.addAll(requestedHeaderFields);

			Set<String> selectFieldSet = new Set<String>();
			selectFieldSet.add('Id');

			for (String apiName : requestedHeaderFields) {
				Schema.SObjectField token = fieldTokenByApiName.get(apiName);
				if (token == null) {
					continue;
				}

				selectFieldSet.add(apiName);

				Schema.DescribeFieldResult fieldDescribe = token.getDescribe();
				if (fieldDescribe.getType() == Schema.DisplayType.REFERENCE) {
					String relationshipName = fieldDescribe.getRelationshipName();
					if (!String.isBlank(relationshipName)) {
						plan.relationshipNameByApiName.put(apiName, relationshipName);
						selectFieldSet.add(relationshipName + '.Name');
					}
				}
			}

			plan.selectFields.addAll(selectFieldSet);
			plan.selectFields.sort();
			return plan;
		}

		private List<String> resolveHeaderFieldApiNames() {
			List<String> requestedApiNames = new List<String>();

			Schema.DescribeSObjectResult describeResult = GoogleFile__c.SObjectType.getDescribe();
			Map<String, Schema.FieldSet> fieldSetMap = describeResult.fieldSets.getMap();

			if (fieldSetMap == null || !fieldSetMap.containsKey(HEADER_FIELD_SET_NAME)) {
				return requestedApiNames;
			}

			Schema.FieldSet headerFieldSet = fieldSetMap.get(HEADER_FIELD_SET_NAME);
			if (headerFieldSet == null) {
				return requestedApiNames;
			}

			for (Schema.FieldSetMember member : headerFieldSet.getFields()) {
				String fieldPath = member.getFieldPath();
				if (String.isBlank(fieldPath)) {
					continue;
				}

				String baseApiName = normalizeFieldSetPathToBaseField(fieldPath);
				if (!requestedApiNames.contains(baseApiName)) {
					requestedApiNames.add(baseApiName);
				}
			}

			return requestedApiNames;
		}

		private String normalizeFieldSetPathToBaseField(String fieldPath) {
			Integer dotIndex = fieldPath.indexOf('.');
			return dotIndex > 0 ? fieldPath.substring(0, dotIndex) : fieldPath;
		}
	}

	private class HeaderQueryPlan {
		public List<String> requestedFieldApiNames = new List<String>();
		public List<String> selectFields = new List<String>();
		public Map<String, String> relationshipNameByApiName = new Map<String, String>();
	}
}