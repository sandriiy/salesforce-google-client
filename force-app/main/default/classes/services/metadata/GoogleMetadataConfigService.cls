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
 * Reads and writes the single Google Client configuration record. Every setting has a safe default here,
 * because a field added in a new version is empty in every org that upgrades into it and the package has
 * to keep behaving exactly as before until an administrator opts in. The record is read with a real
 * query once per transaction rather than through the custom metadata cache, which cuts long text fields
 * to 255 characters and quietly shortened prompts. Writing goes through the Metadata API, so a save is
 * a deployment and lands a moment later.
 */
public inherited sharing class GoogleMetadataConfigService {
	public class GoogleMetadataConfigException extends Exception {}

	private static GoogleOrgCacheProvider orgWideProvider = new GoogleOrgCacheProvider(GoogleCacheConfigService.PARTITION);
	private static GoogleCacheConfigService cacheService = new GoogleCacheConfigService(orgWideProvider);

	public static final String DEFAULT_METADATA_DEPLOY_KEY = 'DefaultGoogleMetadataDeployerKey';
	/**
	 * The shipped authorizer, used whenever an org has not named one of its own.
	 */
	public static final String DEFAULT_AUTH_CLASS_NAME = 'DefaultGoogleDriveAuthorizer';
	/**
	 * The strictness prompt inspection runs at when nothing is chosen.
	 */
	public static final String DEFAULT_AI_SAFETY_MODE = 'Standard';
	/**
	 * The columns File Explorer shows when an administrator has not picked any.
	 */
	public static final String DEFAULT_FILE_EXPLORER_COLUMNS = 'title;isLinked;access;owner;lastModified';
	public static final Set<String> SUPPORTED_AI_SAFETY_MODES = new Set<String>{ 'Strict', 'Standard', 'Relaxed', 'Off' };
	/**
	 * The size in bytes above which a file is treated as large, for previews and for uploads alike.
	 */
	public static final Long DEFAULT_BIG_FILE_SIZE = 2097152L;
	/**
	 * How many files one delete job trashes in Drive before chaining another.
	 */
	public static final Integer DEFAULT_MAX_DELETE_CHAIN_SIZE = 3;
	/**
	 * How long an answer to a question may be when nothing is configured.
	 */
	public static final Integer DEFAULT_QUESTION_MAX_OUTPUT_TOKENS = 1024;
	/**
	 * How sure the model must be before a label is applied when nothing is configured.
	 */
	public static final Integer DEFAULT_AI_LABELING_MIN_CONFIDENCE = 80;
	/**
	 * How much reasoning a labeling call gets when nothing is configured, which is none.
	 */
	public static final Integer DEFAULT_AI_LABELING_THINKING_BUDGET = 0;
	/**
	 * How many labels an administrator may define. Anything past this is ignored rather than sent.
	 */
	public static final Integer MAX_AI_LABEL_DEFINITIONS = 20;
	/**
	 * The switches that turn AI on. Deactivation sets every one of them to false.
	 */
	public static final Set<String> AI_FEATURE_FLAG_FIELDS = new Set<String>{ 'IsFileIntelligenceEnabled__c', 'IsAiLabelingEnabled__c' };
	/**
	 * Everything an administrator entered for AI. Deactivation clears every one of them, which is what makes
	 * it a reset rather than a pause. Add a new AI setting and it belongs in here too.
	 */
	public static final Set<String> AI_CONFIGURATION_FIELDS = new Set<String>{
		'CustomGeminiApiKey__c', 'CustomModelName__c', 'CustomAgentProjectId__c', 'CustomAgentLocation__c',
		'CustomSummaryPrompt__c', 'CustomQuestionPrompt__c', 'QuestionMaxOutputTokens__c',
		'AiSafetyMode__c', 'CustomAiPromptSafetyGuardClass__c',
		'CustomLabelingPrompt__c', 'AiLabelingMinConfidence__c', 'AiLabelingThinkingBudget__c', 'AiLabelDefinitions__c'
	};
	public static final String DEFAULT_SUMMARY_PROMPT = 'Create a very short summary of the provided document content that starts with "This file describes". Use only the text provided in the document and keep the summary accurate. Focus on the main subject and the most important points, names, dates, and numbers. Omit secondary details if the summary needs to stay brief.';
	public static final String DEFAULT_LABELING_PROMPT = 'You classify one business document into exactly one of the labels defined by the administrator. Read the document text and compare it against every label description. Choose a label only when the document clearly matches that description. When the document fits none of the labels, fits several of them equally well, or you are not sure, answer None. Never invent a label that is not in the list and use only the document text provided.';
	public static final String DEFAULT_QUESTION_PROMPT = 'You answer user questions about one specific file content. Use only the provided document text and be accurate. If the user refers to a table, column, field, row, section, value, or label with slightly imperfect wording, infer the closest reasonable match from the document before giving up. Prefer the most likely interpretation instead of returning nothing. If multiple interpretations are plausible, answer with the strongest match and briefly mention the ambiguity. If the answer is not available in the document - check if you can figure it out, and if not, reply exactly with "I could not find that in this file". Return plain text only. Keep the response concise, direct, and helpful. Do not use markdown, bullet lists, or headings.';

	private static final Integer MAX_AI_LABEL_NAME_LENGTH = GoogleFileVersionLabel__c.Name.getDescribe().getLength();
	private static final Integer MIN_CONFIDENCE_PERCENT = 0;
	private static final Integer MAX_CONFIDENCE_PERCENT = 100;
	private static final String DEFAULT_RECORD_DEVELOPER_NAME = 'GoogleClient';
	private static final String DEFAULT_RECORD_LABEL = 'Google Client';

	@TestVisible
	private static GoogleClientConfig__mdt configRecordOverride;
	@TestVisible
	private static GoogleClientConfig__mdt resolvedConfigRecord;

	private GoogleClientConfig__mdt configRecord;
	private IGoogleMetadataDeployer metadataDeployer;

    public GoogleMetadataConfigService() {
        this(new DefaultMetadataDeployer());
    }

	/**
	 * Builds the service on a deployer of your choosing, which is the seam that keeps saving testable.
	 *
	 * @param deployer What the configuration deployment is handed to.
	 */
	public GoogleMetadataConfigService(IGoogleMetadataDeployer deployer) {
		this.metadataDeployer = deployer;

		this.configRecord = configRecordOverride != null ? configRecordOverride : resolveConfigRecord();
    }

    /**
     * Saves the fields you name and leaves every other one alone, filling in defaults for anything that is
     * still empty and now needs a value. The deployment is asynchronous, so the record has not changed yet
     * when this returns.
     *
     * @param fieldApiToValue The fields to change, by API name.
     * @return The deployment Id to follow, or null when there was nothing to change.
     */
    public Id saveConfig(Map<String, Object> fieldApiToValue) {
        if (fieldApiToValue == null || fieldApiToValue.isEmpty()) {
            return null;
        }

		return deployNewMetadataChanges(applyManagedDefaults(fieldApiToValue));
    }

	/**
	 * Turns AI off and clears everything an administrator entered for it, so it can be set up again from
	 * scratch or against another provider. Google Drive settings are untouched, and summaries and labels
	 * already stored on files stay where they are.
	 *
	 * @return The deployment Id to follow.
	 */
	public Id deactivateAiConfig() {
		Map<String, Object> clearedValues = new Map<String, Object>();
		for (String fieldApiName : AI_CONFIGURATION_FIELDS) clearedValues.put(fieldApiName, null);
		for (String fieldApiName : AI_FEATURE_FLAG_FIELDS) clearedValues.put(fieldApiName, false);

		Logger.info('Deactivate AI Configuration --> Cleared=' + String.join(new List<String>(clearedValues.keySet()), ', ')).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		Logger.saveLog();

		return saveConfig(clearedValues);
	}

    /**
     * The configuration record itself, for a caller that wants a field this service has no getter for.
     *
     * @return The record, which is never null but may be empty on a fresh install.
     */
    public GoogleClientConfig__mdt getConfig() {
        return configRecord;
    }

	/**
	 * Says whether the configuration has ever been saved, which is what separates a fresh install from a
	 * configured org.
	 *
	 * @return True when a record exists.
	 */
	public Boolean hasConfigRecord() {
		return String.isNotBlank(configRecord == null ? null : configRecord.DeveloperName);
	}

	/**
	 * The resolver that decides where uploads go.
	 *
	 * @return The shipped resolver, which reads the configured upload folders.
	 */
	public IGoogleTargetFolderResolver getTargetFolderResolver() {
		return new GoogleMetadataTargetFolderResolver(this);
	}

    /**
     * Whether previews are turned off for the org.
     *
     * @return True when no preview copies should be made or shown.
     */
    public Boolean isPreviewDisabled() {
		return configRecord.IsFilePreviewDisabled__c == true;
    }

	/**
	 * Whether large uploads may go straight from the browser to Google Drive.
	 *
	 * @return True when direct upload is switched on.
	 */
	public Boolean isDirectBrowserUploadEnabled() {
		return configRecord.IsDirectBrowserUploadEnabled__c == true;
	}

	/**
	 * Whether a file owner may open a file in Google Drive.
	 *
	 * @return True when the action is switched on.
	 */
	public Boolean isOpenInDriveEnabled() {
		return configRecord.IsOpenInDriveEnabled__c == true;
	}

	/**
	 * The size above which a file counts as large.
	 *
	 * @return The configured size, or the shipped default.
	 */
	public Long getBigFileSizeInBytes() {
		Decimal configuredValue = configRecord.DefaultBigFileSize__c;
		return configuredValue == null ? DEFAULT_BIG_FILE_SIZE : configuredValue.longValue();
    }

	/**
	 * How many files one delete job trashes in Drive before chaining another.
	 *
	 * @return The configured size, or the shipped default.
	 */
	public Integer getDeleteChainSize() {
		Decimal configuredValue = configRecord.MaxDeleteChainSize__c;
		return configuredValue == null ? DEFAULT_MAX_DELETE_CHAIN_SIZE : configuredValue.intValue();
    }

    /**
     * The main Google Drive folder uploads go to.
     *
     * @return The folder Id, or null when Drive has not been configured yet.
     */
    public String getDefaultUploadFolderId() {
        return configRecord.DefaultGoogleUploadFolderId__c;
    }

    /**
     * The fallback folders, in the order they should be tried.
     *
     * @return The extra folders, empty when none are configured.
     */
    public List<String> getAdditionalUploadFolderIds() {
        String raw = configRecord.AdditionalGoogleUploadFolderIds__c;
        List<String> result = new List<String>();
        if (String.isBlank(raw)) return result;

        for (String token : raw.split(';')) {
            if (token == null) continue;
            String trimmed = token.trim();
            if (String.isNotBlank(trimmed)) result.add(trimmed);
        }

        return result;
    }

    /**
     * Every upload folder in priority order, the main one first and no repeats.
     *
     * @return The folders an upload may go to.
     */
    public List<String> getAllUploadFolderIds() {
        List<String> ordered = new List<String>();
        Set<String> seen = new Set<String>();

        String primary = getDefaultUploadFolderId();
        if (String.isNotBlank(primary)) {
            String trimmedPrimary = primary.trim();
            if (String.isNotBlank(trimmedPrimary)) {
                ordered.add(trimmedPrimary);
                seen.add(trimmedPrimary);
            }
        }

        for (String additional : getAdditionalUploadFolderIds()) {
            if (seen.contains(additional)) continue;
            ordered.add(additional);
            seen.add(additional);
        }

        return ordered;
    }

    /**
     * The columns File Explorer should show, in order.
     *
     * @return The configured column tokens, or the shipped default set.
     */
    public List<String> getFileExplorerColumns() {
        String raw = configRecord.FileExplorerColumns__c;
        if (String.isBlank(raw)) {
            raw = DEFAULT_FILE_EXPLORER_COLUMNS;
        }

        List<String> result = new List<String>();
        for (String token : raw.split(';')) {
            if (token == null) continue;
            String trimmed = token.trim();
            if (String.isNotBlank(trimmed)) result.add(trimmed);
        }

        return result;
    }

    /**
     * The Apex class that gets the Google access token, which an org can replace with its own.
     *
     * @return The configured class name, or the shipped authorizer.
     */
    public String getGoogleDriveAuthorizerClassName() {
        String customClassName = configRecord.CustomGoogleAuthorizerClass__c;
		return String.isNotBlank(customClassName) ? customClassName : DEFAULT_AUTH_CLASS_NAME;
    }

	/**
	 * The Google service account Salesforce authenticates as.
	 *
	 * @return The configured account, or null.
	 */
	public String getGoogleDriveServiceAccountEmail() {
        return configRecord.CustomGoogleServiceAccount__c;
    }

	/**
	 * The Salesforce certificate the token request is signed with.
	 *
	 * @return The configured certificate name, or null.
	 */
	public String getGoogleDriveCertificateName() {
        return configRecord.CustomGoogleCertificate__c;
    }

	/**
	 * How folders are laid out in Drive, such as a folder per user, per record, or both nested.
	 *
	 * @return The configured structure, or null when files go straight into the upload folder.
	 */
	public String getGoogleDriveFolderStructure() {
        return configRecord.CustomGoogleUploadFolderStructure__c;
    }

	/**
	 * Whether the configured structure keeps a folder per record, which is what shortcuts and record folder
	 * lookups depend on.
	 *
	 * @return True when records get their own folders.
	 */
	public Boolean requiresRecordFolder() {
		String folderStructure = getGoogleDriveFolderStructure();
		return (
			folderStructure == GoogleCloudConstants.STRUCTURE_RECORD ||
			folderStructure == GoogleCloudConstants.STRUCTURE_USER_RECORD ||
			folderStructure == GoogleCloudConstants.STRUCTURE_RECORD_USER
		);
	}

	/**
	 * The Gemini Developer API key.
	 *
	 * @return The configured key, or null when this org uses Agent Platform or no AI at all.
	 */
	public String getGoogleGeminiKey() {
        return configRecord.CustomGeminiApiKey__c;
    }

	/**
	 * The model AI calls are sent to.
	 *
	 * @return The configured model name, or null.
	 */
	public String getGoogleAiModel() {
        return configRecord.CustomModelName__c;
    }

	/**
	 * The Agent Platform region requests go to.
	 *
	 * @return The configured location, or null.
	 */
	public String getGoogleAgentLocation() {
        return configRecord.CustomAgentLocation__c;
    }

	/**
	 * The Google Cloud project Agent Platform runs in.
	 *
	 * @return The configured project, or null.
	 */
	public String getGoogleAgentProjectId() {
        return configRecord.CustomAgentProjectId__c;
    }

	/**
	 * Whether AI analysis is switched on. With this off nothing is ever sent to a provider.
	 *
	 * @return True when summaries, questions and labeling may run.
	 */
	public Boolean isFileIntelligenceEnabled() {
		return configRecord.IsFileIntelligenceEnabled__c == true;
	}

	/**
	 * The system prompt used when a file is summarized.
	 *
	 * @return The configured prompt, or the shipped one.
	 */
	public String getSummaryPrompt() {
		String configuredValue = configRecord.CustomSummaryPrompt__c;
		return String.isNotBlank(configuredValue) ? configuredValue : DEFAULT_SUMMARY_PROMPT;
	}

	/**
	 * The system prompt used when a question about a file is answered.
	 *
	 * @return The configured prompt, or the shipped one.
	 */
	public String getQuestionPrompt() {
		String configuredValue = configRecord.CustomQuestionPrompt__c;
		return String.isNotBlank(configuredValue) ? configuredValue : DEFAULT_QUESTION_PROMPT;
	}

	/**
	 * How long an answer may be, which is also what drives the provider bill.
	 *
	 * @return The configured limit, or the shipped default.
	 */
	public Integer getQuestionMaxOutputTokens() {
		Decimal configuredValue = configRecord.QuestionMaxOutputTokens__c;
		return configuredValue == null ? DEFAULT_QUESTION_MAX_OUTPUT_TOKENS : configuredValue.intValue();
	}

	/**
	 * How strictly prompts and answers are inspected. An unrecognised value falls back to the default rather
	 * than turning inspection off.
	 *
	 * @return "Strict", "Standard", "Relaxed" or "Off".
	 */
	public String getAiSafetyMode() {
		String configuredValue = configRecord.AiSafetyMode__c;
		if (String.isBlank(configuredValue)) {
			return DEFAULT_AI_SAFETY_MODE;
		}

		return SUPPORTED_AI_SAFETY_MODES.contains(configuredValue) ? configuredValue : DEFAULT_AI_SAFETY_MODE;
	}

	/**
	 * The Apex class that inspects prompts and answers, when an org has written its own.
	 *
	 * @return The configured class name, or null to use the shipped guard.
	 */
	public String getCustomAiPromptSafetyGuardClass() {
		return configRecord.CustomAiPromptSafetyGuardClass__c;
	}

	/**
	 * Whether new files are labeled automatically. Labeling can never be on while analysis is off.
	 *
	 * @return True when labeling may run.
	 */
	public Boolean isAiLabelingEnabled() {
		return isFileIntelligenceEnabled() && configRecord.IsAiLabelingEnabled__c == true;
	}

	/**
	 * The system prompt used when a label is chosen. The label descriptions are added to it automatically.
	 *
	 * @return The configured prompt, or the shipped one.
	 */
	public String getLabelingPrompt() {
		String configuredValue = configRecord.CustomLabelingPrompt__c;
		return String.isNotBlank(configuredValue) ? configuredValue : DEFAULT_LABELING_PROMPT;
	}

	/**
	 * How sure the model must be before a label is applied, clamped to a percentage.
	 *
	 * @return A number from 0 to 100.
	 */
	public Integer getAiLabelingMinConfidence() {
		Decimal configuredValue = configRecord.AiLabelingMinConfidence__c;
		if (configuredValue == null) return DEFAULT_AI_LABELING_MIN_CONFIDENCE;

		Integer confidence = configuredValue.intValue();
		if (confidence < MIN_CONFIDENCE_PERCENT) return MIN_CONFIDENCE_PERCENT;
		return confidence > MAX_CONFIDENCE_PERCENT ? MAX_CONFIDENCE_PERCENT : confidence;
	}

	/**
	 * How much room a labeling call gets to reason before answering.
	 *
	 * @return The configured budget in tokens, never negative.
	 */
	public Integer getAiLabelingThinkingBudget() {
		Decimal configuredValue = configRecord.AiLabelingThinkingBudget__c;
		if (configuredValue == null || configuredValue < 0) return DEFAULT_AI_LABELING_THINKING_BUDGET;
		return configuredValue.intValue();
	}

	/**
	 * The labels the AI may choose from. Reading is deliberately forgiving: an incomplete entry, a duplicate
	 * name, a name too long for the field or a broken payload is dropped rather than raised, so a bad save
	 * can never stop files being uploaded.
	 *
	 * @return The usable label definitions, capped at the maximum.
	 */
	public List<GoogleAiLabelDefinitionDTO> getAiLabelDefinitions() {
		List<GoogleAiLabelDefinitionDTO> definitions = new List<GoogleAiLabelDefinitionDTO>();
		String raw = configRecord.AiLabelDefinitions__c;
		if (String.isBlank(raw)) return definitions;

		List<GoogleAiLabelDefinitionDTO> configuredDefinitions;
		try {
			configuredDefinitions = (List<GoogleAiLabelDefinitionDTO>) JSON.deserialize(raw, List<GoogleAiLabelDefinitionDTO>.class);
		} catch (Exception ex) {
			Logger.error('AI label definitions could not be read: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			return definitions;
		}

		Set<String> seenNames = new Set<String>();
		for (GoogleAiLabelDefinitionDTO definition : configuredDefinitions) {
			if (definition == null || !definition.isComplete() || definition.name.trim().length() > MAX_AI_LABEL_NAME_LENGTH) continue;

			String nameKey = definition.name.trim().toLowerCase();
			if (seenNames.contains(nameKey)) continue;
			seenNames.add(nameKey);

			definitions.add(definition);
			if (definitions.size() >= MAX_AI_LABEL_DEFINITIONS) break;
		}

		return definitions;
	}

	/**
	 * The domain public links are restricted to, when an org set one.
	 *
	 * @return The configured domain, or null to share links with anyone.
	 */
	public String getGoogleDriveDomain() {
        return configRecord.OrganizationalDomain__c;
    }

	private GoogleClientConfig__mdt resolveConfigRecord() {
		if (resolvedConfigRecord == null) {
			resolvedConfigRecord = loadConfigRecord();
		}

		return resolvedConfigRecord;
	}

	private GoogleClientConfig__mdt loadConfigRecord() {
		List<GoogleClientConfig__mdt> configRecords = (List<GoogleClientConfig__mdt>) GoogleClientConfigSelector.query()
			.withAllFields()
			.toList();
		if (configRecords == null || configRecords.isEmpty()) {
			return new GoogleClientConfig__mdt();
		}

		for (GoogleClientConfig__mdt candidate : configRecords) {
			if (candidate.DeveloperName == DEFAULT_RECORD_DEVELOPER_NAME) {
				return candidate;
			}
		}

		return configRecords.size() == 1 ? configRecords[0] : new GoogleClientConfig__mdt();
	}

	private Map<String, Object> applyManagedDefaults(Map<String, Object> fieldApiToValue) {
		Map<String, Object> normalizedValues = new Map<String, Object>(fieldApiToValue);

		applyBooleanDefaultIfMissing(normalizedValues, 'IsFilePreviewDisabled__c', configRecord.IsFilePreviewDisabled__c, false);
		applyBooleanDefaultIfMissing(normalizedValues, 'IsDirectBrowserUploadEnabled__c', configRecord.IsDirectBrowserUploadEnabled__c, false);
		applyBooleanDefaultIfMissing(normalizedValues, 'IsOpenInDriveEnabled__c', configRecord.IsOpenInDriveEnabled__c, false);
		applyNumberDefaultIfMissing(normalizedValues, 'DefaultBigFileSize__c', configRecord.DefaultBigFileSize__c, DEFAULT_BIG_FILE_SIZE);
		applyNumberDefaultIfMissing(normalizedValues, 'MaxDeleteChainSize__c', configRecord.MaxDeleteChainSize__c, DEFAULT_MAX_DELETE_CHAIN_SIZE);

		Boolean isIntelligenceEnabled = resolveBooleanValue(normalizedValues, 'IsFileIntelligenceEnabled__c', configRecord.IsFileIntelligenceEnabled__c);
		if (isIntelligenceEnabled) {
			applyStringDefaultIfMissing(normalizedValues, 'CustomSummaryPrompt__c', configRecord.CustomSummaryPrompt__c, DEFAULT_SUMMARY_PROMPT);
			applyStringDefaultIfMissing(normalizedValues, 'CustomQuestionPrompt__c', configRecord.CustomQuestionPrompt__c, DEFAULT_QUESTION_PROMPT);
			applyNumberDefaultIfMissing(normalizedValues, 'QuestionMaxOutputTokens__c', configRecord.QuestionMaxOutputTokens__c, DEFAULT_QUESTION_MAX_OUTPUT_TOKENS);
			applyStringDefaultIfMissing(normalizedValues, 'AiSafetyMode__c', configRecord.AiSafetyMode__c, DEFAULT_AI_SAFETY_MODE);
		}

		Boolean isLabelingEnabled = resolveBooleanValue(normalizedValues, 'IsAiLabelingEnabled__c', configRecord.IsAiLabelingEnabled__c);
		if (isIntelligenceEnabled && isLabelingEnabled) {
			applyStringDefaultIfMissing(normalizedValues, 'CustomLabelingPrompt__c', configRecord.CustomLabelingPrompt__c, DEFAULT_LABELING_PROMPT);
			applyNumberDefaultIfMissing(normalizedValues, 'AiLabelingMinConfidence__c', configRecord.AiLabelingMinConfidence__c, DEFAULT_AI_LABELING_MIN_CONFIDENCE);
			applyNumberDefaultIfMissing(normalizedValues, 'AiLabelingThinkingBudget__c', configRecord.AiLabelingThinkingBudget__c, DEFAULT_AI_LABELING_THINKING_BUDGET);
		}

		return normalizedValues;
	}

	private void applyBooleanDefaultIfMissing(Map<String, Object> valuesByFieldName, String fieldApiName, Object currentValue, Boolean defaultValue) {
		if (!valuesByFieldName.containsKey(fieldApiName) && currentValue == null) {
			valuesByFieldName.put(fieldApiName, defaultValue);
		}
	}

	private void applyNumberDefaultIfMissing(Map<String, Object> valuesByFieldName, String fieldApiName, Object currentValue, Object defaultValue) {
		if (valuesByFieldName.containsKey(fieldApiName)) {
			if (valuesByFieldName.get(fieldApiName) == null) {
				valuesByFieldName.put(fieldApiName, defaultValue);
			}
			return;
		}

		if (currentValue == null) {
			valuesByFieldName.put(fieldApiName, defaultValue);
		}
	}

	private void applyStringDefaultIfMissing(Map<String, Object> valuesByFieldName, String fieldApiName, String currentValue, String defaultValue) {
		if (valuesByFieldName.containsKey(fieldApiName)) {
			Object rawNextValue = valuesByFieldName.get(fieldApiName);
			String nextValue = rawNextValue == null ? null : String.valueOf(rawNextValue);
			if (String.isBlank(nextValue)) {
				valuesByFieldName.put(fieldApiName, defaultValue);
			}
			return;
		}

		if (String.isBlank(currentValue)) {
			valuesByFieldName.put(fieldApiName, defaultValue);
		}
	}

	private Boolean resolveBooleanValue(Map<String, Object> valuesByFieldName, String fieldApiName, Boolean currentValue) {
		if (!valuesByFieldName.containsKey(fieldApiName)) {
			return currentValue == true;
		}

		Object nextValue = valuesByFieldName.get(fieldApiName);
		if (nextValue == null) {
			return false;
		}

		if (nextValue instanceof Boolean) {
			return (Boolean) nextValue;
		}

		return String.valueOf(nextValue).toLowerCase() == 'true';
	}

	private Id deployNewMetadataChanges(Map<String, Object> fieldApiToValue) {
		try {
            Metadata.DeployContainer container = new Metadata.DeployContainer();

            Metadata.CustomMetadata cmdt = new Metadata.CustomMetadata();
            cmdt.fullName = 'GoogleClientConfig__mdt.' + (String.isNotBlank(configRecord.DeveloperName) ? configRecord.DeveloperName : DEFAULT_RECORD_DEVELOPER_NAME);
            cmdt.label = String.isNotBlank(configRecord.MasterLabel) ? configRecord.MasterLabel : DEFAULT_RECORD_LABEL;

            cmdt.values = new List<Metadata.CustomMetadataValue>();

            for (String fieldApiName : fieldApiToValue.keySet()) {
                Metadata.CustomMetadataValue v = new Metadata.CustomMetadataValue();
                v.field = fieldApiName;
                v.value = fieldApiToValue.get(fieldApiName);
                cmdt.values.add(v);
            }

            container.addMetadata(cmdt);

            Id deploymentId = metadataDeployer.enqueue(container);
			cacheService.put(DEFAULT_METADATA_DEPLOY_KEY, 'pending');
			return deploymentId;
        } catch (Exception ex) {
            throw new GoogleMetadataConfigException('Failed to save Google Client configuration. Ensure the user has “Modify Metadata Through Metadata API Functions” or refer to "Google Client Config" custom metadata directly.');
        }
	}

	private class DefaultMetadataDeployer implements IGoogleMetadataDeployer {
		public Id enqueue(Metadata.DeployContainer container) {
			return Metadata.Operations.enqueueDeployment(container, new DefaultMetadataCallback());
		}
	}
	
	private class DefaultMetadataCallback implements Metadata.DeployCallback {
		public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
			Id jobId = context.getCallbackJobId();

			if (result.status == Metadata.DeployStatus.Succeeded) {
				GoogleMetadataConfigService.cacheService.put(GoogleMetadataConfigService.DEFAULT_METADATA_DEPLOY_KEY, 'success');
			} else {
				GoogleMetadataConfigService.cacheService.put(GoogleMetadataConfigService.DEFAULT_METADATA_DEPLOY_KEY, 'fail');
			}
		}
	}
}