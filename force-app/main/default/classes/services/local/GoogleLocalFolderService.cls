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
/**
 * Creates folders in Google Drive for automation, and returns the folder a record already owns. Give it
 * a name and it creates one, give it only a record and it hands back that record's own folder, which
 * needs a configured structure that keeps folders per record. It also answers the setup page's two
 * folder checks: whether a folder name pattern can be used, and whether a folder can keep the Google
 * Workspace copies.
 */
public without sharing class GoogleLocalFolderService {
	public class GoogleLocalFolderException extends Exception {}

	private static final String MISSING_REQUEST_MESSAGE = 'Enter a folder name, or provide a record Id to use the record’s own folder';
	private static final String RECORD_FOLDER_UNAVAILABLE_MESSAGE = 'Google Client is not set up to keep a folder per record. Enter a folder name to create one, or choose a folder structure with {Record} under Google Drive settings';
	private static final String RECORD_FOLDER_UNRESOLVED_MESSAGE = 'The record folder could not be resolved in Google Drive. Please try again or contact your system administrator';
	private static final String MISSING_UPLOAD_FOLDER_MESSAGE = 'No Google Drive upload folder is configured. Set one under Google Drive settings or provide a parent folder Id';
	private static final String CREATE_FAILED_MESSAGE = 'Unable to create the folder in Google Drive. Please try again or contact your system administrator';
	private static final String MISSING_OBJECT_MESSAGE = 'Enter the API name of the object these folders belong to.';
	private static final String UNKNOWN_OBJECT_MESSAGE = 'This object doesn\'t exist or you can\'t see it.';
	private static final String HIDDEN_FIELD_MESSAGE = 'The field {0} doesn\'t exist or you can\'t see it.';
	private static final String UNREADABLE_FIELDS_MESSAGE = 'Google Client can\'t read every field in this formula. Use fields at most five relationships away and, of an owner that can also be a queue, only its name fields such as Name, FirstName or LastName.';
	private static final String TYPE_QUALIFIER = ':';
	private static final String QUEUE_TYPE_QUALIFIER = 'Queue';

	@TestVisible
	private static Set<String> hiddenFieldPathsOverride = new Set<String>();

	private final GoogleMetadataConfigService metadataService;

	public GoogleLocalFolderService() {
		this.metadataService = new GoogleMetadataConfigService();
	}

	/**
	 * Checks one folder name pattern for the setup page: whether Salesforce compiles it against the object
	 * and it returns text, whether the running user can see the object and every field it references,
	 * whether the folder jobs can read those fields, what would make the name change by itself, and what a
	 * real folder would be called. A pattern built on an object or field the running user cannot see is
	 * refused, so an administrator never puts values they could not see themselves into folder names. The
	 * example comes from the newest record of that object with a Google Client file (for User, the newest
	 * uploader) and is shown only when the running user can read that record.
	 *
	 * @param objectApiName The object the pattern names folders for, in any letter case.
	 * @param pattern The formula, which must return text.
	 * @return The verdict with the reason when it is refused, the warnings and the example.
	 */
	public GoogleFolderNamePatternCheckDTO checkRecordFolderNamePattern(String objectApiName, String pattern) {
		GoogleFolderNamePatternCheckDTO check = new GoogleFolderNamePatternCheckDTO();
		check.isValid = false;
		check.warnings = new List<String>();

		if (String.isBlank(objectApiName)) {
			check.message = MISSING_OBJECT_MESSAGE;
			return check;
		}

		Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName.trim().toLowerCase());
		if (objectType == null || !objectType.getDescribe().isAccessible()) {
			check.message = UNKNOWN_OBJECT_MESSAGE;
			return check;
		}

		Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
		check.objectApiName = objectDescribe.getName();
		check.objectLabel = objectDescribe.getLabel();

		GoogleFolderNamePatternResolver patternResolver = new GoogleFolderNamePatternResolver();
		List<String> problems = patternResolver.findProblems(objectType, pattern);
		if (!problems.isEmpty()) {
			check.message = problems[0];
			return check;
		}

		FormulaEval.FormulaInstance formula = patternResolver.compile(objectType, pattern);
		String hiddenFieldPath = findHiddenFieldPath(objectType, formula.getReferencedFields());
		if (hiddenFieldPath != null) {
			check.message = HIDDEN_FIELD_MESSAGE.replace('{0}', hiddenFieldPath);
			return check;
		}

		List<String> queriedFields = patternResolver.toQueriedFields(formula.getReferencedFields());
		try {
			GoogleFileLinkedRecordSelector.assertSelectable(objectType, queriedFields);
		} catch (Exception ex) {
			check.message = UNREADABLE_FIELDS_MESSAGE;
			return check;
		}

		check.isValid = true;
		check.warnings = patternResolver.findWarnings(pattern, formula.getReferencedFields());

		try {
			check.exampleName = buildExampleName(objectType, formula, queriedFields, patternResolver);
		} catch (Exception ex) {
			Logger.info('Folder Name Pattern Example Unavailable --> Object=' + check.objectApiName + ', Message=' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		}

		return check;
	}

	/**
	 * Checks the folder an administrator chose for the Google Workspace copies: it must exist, be out of the
	 * trash, be a folder and accept new files. The reason is given in an administrator's words; Google's own
	 * answer goes to the log.
	 *
	 * @param folderId The Google Drive folder Id.
	 * @return Whether it can keep the copies, its name, and why not when it cannot.
	 */
	public GoogleDriveFolderCheckDTO checkWorkspaceCopyFolder(String folderId) {
		if (String.isBlank(folderId)) {
			return new GoogleDriveFolderCheckCommand(null).check(folderId);
		}

		GoogleDriveFolderCheckDTO check = new GoogleDriveFolderCheckCommand().check(folderId);
		if (check.isUsable != true && String.isNotBlank(check.failureDetail)) {
			Logger.error('Google Workspace Copies Folder Check Failed --> FolderId=' + folderId.trim() + ', Message=' + check.failureDetail).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
		}

		return check;
	}

	/**
	 * Creates or finds one folder. Where the folder goes is decided in that order: the parent you named, the
	 * record's folder, then the default upload folder.
	 *
	 * @param request The name, the parent, the record and whether an existing folder may be reused.
	 * @return The folder with its Id and link, and whether this call created it.
	 */
	public GoogleFolderCreateResultDTO createFolder(GoogleFolderCreateRequestDTO request) {
		if (request == null || (String.isBlank(request.folderName) && request.relatedRecordId == null)) {
			throw new GoogleLocalFolderException(MISSING_REQUEST_MESSAGE);
		}

		try {
			GoogleFolderCreateCommand.GoogleFolderCreateResult result = String.isBlank(request.folderName)
				? resolveRecordFolder(request.relatedRecordId)
				: new GoogleFolderCreateCommand()
					.named(request.folderName)
					.under(resolveParentFolderId(request))
					.reuseExisting(request.reuseExistingFolder != false)
					.execute();

			return toResultDto(result);
		} catch (GoogleLocalFolderException ex) {
			throw ex;
		} catch (Exception ex) {
			Logger.error('Create Google Drive Folder (Local/Remote): ' + String.valueOf(request.folderName) + ', record: ' + String.valueOf(request.relatedRecordId) + ', message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFolderException(CREATE_FAILED_MESSAGE);
		}
	}

	private GoogleFolderCreateCommand.GoogleFolderCreateResult resolveRecordFolder(Id relatedRecordId) {
		if (!metadataService.requiresRecordFolder()) {
			throw new GoogleLocalFolderException(RECORD_FOLDER_UNAVAILABLE_MESSAGE);
		}

		GoogleFileFolderStructureCommand folderStructureCommand = new GoogleFileFolderStructureCommand();
		String existingFolderId = folderStructureCommand.findExistingFolder(UserInfo.getUserId(), relatedRecordId);
		String folderId = String.isNotBlank(existingFolderId) ? existingFolderId : folderStructureCommand.ensureFolder(relatedRecordId);

		if (String.isBlank(folderId)) {
			throw new GoogleLocalFolderException(RECORD_FOLDER_UNRESOLVED_MESSAGE);
		}

		return new GoogleFolderCreateCommand().retrieve(folderId, String.isBlank(existingFolderId));
	}

	private String resolveParentFolderId(GoogleFolderCreateRequestDTO request) {
		if (String.isNotBlank(request.parentFolderId)) return request.parentFolderId.trim();

		if (request.relatedRecordId != null && String.isNotBlank(metadataService.getGoogleDriveFolderStructure())) {
			String recordFolderId = new GoogleFileFolderStructureCommand().ensureFolder(request.relatedRecordId);
			if (String.isNotBlank(recordFolderId)) return recordFolderId;
		}

		String defaultFolderId = metadataService.getDefaultUploadFolderId();
		if (String.isBlank(defaultFolderId)) {
			throw new GoogleLocalFolderException(MISSING_UPLOAD_FOLDER_MESSAGE);
		}

		return defaultFolderId;
	}

	private String buildExampleName(Schema.SObjectType objectType, FormulaEval.FormulaInstance formula, List<String> queriedFields, GoogleFolderNamePatternResolver patternResolver) {
		Id exampleRecordId = resolveExampleRecordId(objectType);
		if (exampleRecordId == null || !new GoogleRecordAccessResolver().hasReadAccess(UserInfo.getUserId(), exampleRecordId)) return null;

		SObject exampleRecord = GoogleFileLinkedRecordSelector.selectById(exampleRecordId, queriedFields);
		if (exampleRecord == null) return null;

		return patternResolver.render(formula, exampleRecord);
	}

	private Id resolveExampleRecordId(Schema.SObjectType objectType) {
		if (objectType == User.SObjectType) {
			List<GoogleFile__c> newestFiles = (List<GoogleFile__c>) GoogleFileSelector.query()
				.withSpecificFields(new List<String>{ 'Id', 'CreatedById' })
				.orderByCreatedDesc()
				.limitTo(1)
				.toList();

			return newestFiles.isEmpty() ? null : newestFiles[0].CreatedById;
		}

		List<GoogleFileLink__c> newestLinks = (List<GoogleFileLink__c>) GoogleFileLinkSelector.query()
			.withBaseFields()
			.byLinkedObjectType(objectType.getDescribe().getName())
			.orderByCreatedDesc()
			.limitTo(1)
			.toList();

		return newestLinks.isEmpty() || String.isBlank(newestLinks[0].LinkedObjectId__c) ? null : (Id) newestLinks[0].LinkedObjectId__c;
	}

	private String findHiddenFieldPath(Schema.SObjectType objectType, Set<String> referencedFields) {
		if (referencedFields == null) return null;

		for (String fieldPath : referencedFields) {
			if (!isFieldPathReadable(objectType, fieldPath)) return fieldPath;
		}

		return null;
	}

	private Boolean isFieldPathReadable(Schema.SObjectType objectType, String fieldPath) {
		if (String.isBlank(fieldPath) || hiddenFieldPathsOverride.contains(fieldPath.toLowerCase())) return false;

		List<String> pathParts = fieldPath.split('\\.');
		Schema.SObjectType currentType = objectType;
		for (Integer partIndex = 0; partIndex < pathParts.size() - 1; partIndex++) {
			Schema.DescribeFieldResult relationshipField = findRelationshipField(currentType, pathParts[partIndex].substringBefore(TYPE_QUALIFIER));
			if (relationshipField == null || !relationshipField.isAccessible() || relationshipField.getReferenceTo().isEmpty()) return false;

			currentType = resolveReferencedType(relationshipField, pathParts[partIndex].substringAfter(TYPE_QUALIFIER));
			if (currentType == null || !currentType.getDescribe().isAccessible()) return false;
		}

		Schema.SObjectField lastField = currentType.getDescribe().fields.getMap().get(pathParts[pathParts.size() - 1].toLowerCase());
		return lastField != null && lastField.getDescribe().isAccessible();
	}

	private Schema.SObjectType resolveReferencedType(Schema.DescribeFieldResult relationshipField, String typeQualifier) {
		List<Schema.SObjectType> referencedTypes = relationshipField.getReferenceTo();
		if (String.isBlank(typeQualifier)) return referencedTypes[0];

		String typeName = typeQualifier.equalsIgnoreCase(QUEUE_TYPE_QUALIFIER) ? String.valueOf(Group.SObjectType) : typeQualifier;
		for (Schema.SObjectType referencedType : referencedTypes) {
			if (String.valueOf(referencedType).equalsIgnoreCase(typeName)) return referencedType;
		}

		return null;
	}

	private Schema.DescribeFieldResult findRelationshipField(Schema.SObjectType objectType, String relationshipName) {
		for (Schema.SObjectField field : objectType.getDescribe().fields.getMap().values()) {
			Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
			if (relationshipName.equalsIgnoreCase(fieldDescribe.getRelationshipName())) return fieldDescribe;
		}

		return null;
	}

	private GoogleFolderCreateResultDTO toResultDto(GoogleFolderCreateCommand.GoogleFolderCreateResult result) {
		GoogleFolderCreateResultDTO dto = new GoogleFolderCreateResultDTO();
		dto.folderId = result.folderId;
		dto.folderName = result.folderName;
		dto.parentFolderId = result.parentFolderId;
		dto.folderUrl = result.webViewLink;
		dto.wasCreated = result.wasCreated;
		return dto;
	}
}
