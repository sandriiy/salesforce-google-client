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
 * Names the folders of the configured structure: the object's pattern when there is one, otherwise the usual
 * "Account : Acme" and "User : Jane Doe", character for character as earlier versions named them. Records
 * are read in system mode so every uploader computes the same name. A name that is not certain (the record
 * is gone or unnamed, or its pattern cannot be used) is never a reason to rename, so a rename asks the
 * resolveExpected methods and creating a folder asks the buildNew ones.
 */
public without sharing class GoogleDriveFolderNameResolver {
	private static final String UNKNOWN_RECORD_NAME = 'Unknown Record';
	private static final String UNKNOWN_USER_NAME = 'Unknown User';
	private static final String USER_FOLDER_PREFIX = 'User : ';
	private static final String RECORD_FOLDER_SEPARATOR = ' : ';
	private static final String ERROR_LEVEL = 'ERROR';
	private static final Set<String> PERSON_FOLDER_PREFIXES = new Set<String>{ 'Contact : ', 'Lead : ', 'User : ', 'Account : ' };

	@TestVisible
	private static List<String> loggedFailures = new List<String>();
	private static Set<String> reportedPatternKeys = new Set<String>();

	private final GoogleMetadataConfigService metadataService;
	private final GoogleLocalFileLinkEnrichmentService linkEnrichmentService;
	private final GoogleFolderNamePatternResolver patternResolver;
	private final Map<Id, FolderName> recordFolderNamesById = new Map<Id, FolderName>();
	private final Map<Id, FolderName> userFolderNamesById = new Map<Id, FolderName>();

	private Map<String, String> patternsByObjectKey;
	private Boolean hasRecordedErrors = false;

	public GoogleDriveFolderNameResolver() {
		this.metadataService = new GoogleMetadataConfigService();
		this.linkEnrichmentService = new GoogleLocalFileLinkEnrichmentService();
		this.patternResolver = new GoogleFolderNamePatternResolver();
	}

	/**
	 * The name a new folder for this record gets: its object's pattern when it gives a name, otherwise
	 * "<Object API name> : <record name>", with "Unknown Record" when the record has no name.
	 *
	 * @param recordId The record the folder belongs to.
	 * @return The name, never null for a record Id.
	 */
	public String buildNewRecordFolderName(Id recordId) {
		FolderName folderName = resolveRecordFolderName(recordId);
		return folderName == null ? null : folderName.newName;
	}

	/**
	 * The name this record's folder should carry right now, for deciding whether to rename it.
	 *
	 * @param recordId The record the folder belongs to.
	 * @return The name, or null when it is not certain: the record is gone or unnamed, or its pattern cannot
	 * be used. Only a name returned here may cause a rename.
	 */
	public String resolveExpectedRecordFolderName(Id recordId) {
		FolderName folderName = resolveRecordFolderName(recordId);
		return folderName == null ? null : folderName.expectedName;
	}

	/**
	 * The name a new folder for this user gets: the User pattern when there is one and it gives a name,
	 * otherwise "User : <First> <Last>", with "Unknown User" when the user cannot be read.
	 *
	 * @param userId The user the folder belongs to.
	 * @return The name, never null for a user Id.
	 */
	public String buildNewUserFolderName(Id userId) {
		FolderName folderName = resolveUserFolderName(userId);
		return folderName == null ? null : folderName.newName;
	}

	/**
	 * The name this user's folder should carry right now, for deciding whether to rename it.
	 *
	 * @param userId The user the folder belongs to.
	 * @return The name, or null when the user is gone, has no name, or the User pattern cannot be used.
	 */
	public String resolveExpectedUserFolderName(Id userId) {
		FolderName folderName = resolveUserFolderName(userId);
		return folderName == null ? null : folderName.expectedName;
	}

	/**
	 * Says whether a folder already carries the name it should. Surrounding spaces never count, and for the
	 * usual names of people (contacts, leads, users and person accounts) the words may come in any order,
	 * because Salesforce puts a person's name together in the order of each uploader's language.
	 *
	 * @param currentName The name the folder has in Google Drive.
	 * @param expectedName The name it should have.
	 * @return True when no rename is needed.
	 */
	public Boolean isSameFolderName(String currentName, String expectedName) {
		if (String.isBlank(currentName) || String.isBlank(expectedName)) return false;

		String current = currentName.trim();
		String expected = expectedName.trim();
		if (current.equals(expected)) return true;

		String personPrefix = resolvePersonFolderPrefix(expected);
		if (personPrefix == null || !current.startsWith(personPrefix)) return false;

		return sortWords(current.removeStart(personPrefix)).equals(sortWords(expected.removeStart(personPrefix)));
	}

	/**
	 * Says whether a pattern that could not be used was logged by this resolver, so a job knows to save the
	 * log.
	 *
	 * @return True when an error line was written.
	 */
	public Boolean hasRecordedErrors() {
		return this.hasRecordedErrors == true;
	}

	private FolderName resolveRecordFolderName(Id recordId) {
		if (recordId == null) return null;
		if (this.recordFolderNamesById.containsKey(recordId)) return this.recordFolderNamesById.get(recordId);

		Schema.SObjectType objectType = recordId.getSObjectType();
		String objectApiName = objectType.getDescribe().getName();
		String unknownName = objectApiName + RECORD_FOLDER_SEPARATOR + UNKNOWN_RECORD_NAME;

		FolderName folderName;
		PatternOutcome outcome = renderPattern(objectType, objectApiName, recordId);
		if (outcome.isRecordGone) {
			folderName = new FolderName(unknownName, null);
		} else if (String.isNotBlank(outcome.folderName)) {
			folderName = new FolderName(outcome.folderName, outcome.folderName);
		} else {
			String recordName = this.linkEnrichmentService.resolveLinkedRecordName(recordId);
			String usualName = String.isBlank(recordName) ? null : objectApiName + RECORD_FOLDER_SEPARATOR + recordName;
			folderName = new FolderName(
				usualName == null ? unknownName : usualName,
				outcome.isUnusable ? null : usualName
			);
		}

		this.recordFolderNamesById.put(recordId, folderName);
		return folderName;
	}

	private FolderName resolveUserFolderName(Id userId) {
		if (userId == null) return null;
		if (this.userFolderNamesById.containsKey(userId)) return this.userFolderNamesById.get(userId);

		FolderName folderName;
		PatternOutcome outcome = renderPattern(User.SObjectType, String.valueOf(User.SObjectType), userId);
		if (outcome.isRecordGone) {
			folderName = new FolderName(UNKNOWN_USER_NAME, null);
		} else if (String.isNotBlank(outcome.folderName)) {
			folderName = new FolderName(outcome.folderName, outcome.folderName);
		} else {
			folderName = buildUsualUserFolderName(userId, outcome.isUnusable);
		}

		this.userFolderNamesById.put(userId, folderName);
		return folderName;
	}

	private FolderName buildUsualUserFolderName(Id userId, Boolean isPatternUnusable) {
		User folderUser = loadUser(userId);
		if (folderUser == null) return new FolderName(UNKNOWN_USER_NAME, null);

		String fullName = String.join(new List<String>{
			String.isBlank(folderUser.FirstName) ? null : folderUser.FirstName,
			String.isBlank(folderUser.LastName) ? null : folderUser.LastName
		}, ' ').trim();

		String usualName = USER_FOLDER_PREFIX + fullName;
		return new FolderName(usualName, String.isBlank(fullName) || isPatternUnusable ? null : usualName);
	}

	private User loadUser(Id userId) {
		List<User> users = (List<User>) GoogleUserSelector.query()
			.withNameFields()
			.byUserId(userId)
			.limitTo(1)
			.toList();

		return users.isEmpty() ? null : users[0];
	}

	private PatternOutcome renderPattern(Schema.SObjectType objectType, String objectApiName, Id recordId) {
		PatternOutcome outcome = new PatternOutcome();
		String pattern = resolvePatternsByObjectKey().get(objectApiName.toLowerCase());
		if (String.isBlank(pattern)) return outcome;

		try {
			FormulaEval.FormulaInstance formula = this.patternResolver.compile(objectType, pattern);
			SObject record = GoogleFileLinkedRecordSelector.selectById(recordId, this.patternResolver.toQueriedFields(formula.getReferencedFields()));
			if (record == null) {
				outcome.isRecordGone = true;
				return outcome;
			}

			outcome.folderName = this.patternResolver.render(formula, record);
		} catch (Exception ex) {
			outcome.isUnusable = true;
			reportUnusablePattern(objectApiName, pattern, ex);
		}

		return outcome;
	}

	private Map<String, String> resolvePatternsByObjectKey() {
		if (this.patternsByObjectKey != null) return this.patternsByObjectKey;

		this.patternsByObjectKey = new Map<String, String>();
		for (GoogleRecordFolderNamePatternDTO configuredPattern : this.metadataService.getRecordFolderNamePatterns()) {
			this.patternsByObjectKey.put(configuredPattern.objectApiName.toLowerCase(), configuredPattern.pattern);
		}

		return this.patternsByObjectKey;
	}

	private void reportUnusablePattern(String objectApiName, String pattern, Exception failure) {
		String patternKey = objectApiName.toLowerCase() + ':' + pattern;
		if (reportedPatternKeys.contains(patternKey)) return;
		reportedPatternKeys.add(patternKey);

		String message = 'Folder Name Pattern Unusable --> Object=' + objectApiName + ', Message=' + failure.getMessage();
		Logger.error(message).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		loggedFailures.add(ERROR_LEVEL + ' ' + message);
		this.hasRecordedErrors = true;
	}

	private String resolvePersonFolderPrefix(String folderName) {
		for (String personPrefix : PERSON_FOLDER_PREFIXES) {
			if (folderName.startsWith(personPrefix)) return personPrefix;
		}

		return null;
	}

	private String sortWords(String personName) {
		List<String> words = personName.normalizeSpace().split(' ');
		words.sort();
		return String.join(words, ' ');
	}

	private class FolderName {
		public final String newName;
		public final String expectedName;

		public FolderName(String newName, String expectedName) {
			this.newName = newName;
			this.expectedName = expectedName;
		}
	}

	private class PatternOutcome {
		public String folderName;
		public Boolean isRecordGone = false;
		public Boolean isUnusable = false;
	}
}
