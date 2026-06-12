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
public inherited sharing class GoogleMetadataConfigService {
	public class GoogleMetadataConfigException extends Exception {}

	private static GoogleOrgCacheProvider orgWideProvider = new GoogleOrgCacheProvider(GoogleCacheConfigService.PARTITION);
	private static GoogleCacheConfigService cacheService = new GoogleCacheConfigService(orgWideProvider);

	public static final String DEFAULT_METADATA_DEPLOY_KEY = 'DefaultGoogleMetadataDeployerKey';
	public static final String DEFAULT_AUTH_CLASS_NAME = 'DefaultGoogleDriveAuthorizer';
	public static final Long DEFAULT_BIG_FILE_SIZE = 2097152L;
	public static final Integer DEFAULT_MAX_DELETE_CHAIN_SIZE = 3;
	public static final Integer DEFAULT_QUESTION_MAX_OUTPUT_TOKENS = 1024;
	public static final String DEFAULT_SUMMARY_PROMPT = 'Create a very short summary of the provided document content that starts with "This file describes". Use only the text provided in the document and keep the summary accurate. Focus on the main subject and the most important points, names, dates, and numbers. Omit secondary details if the summary needs to stay brief.';
	public static final String DEFAULT_QUESTION_PROMPT = 'You answer user questions about one specific file content. Use only the provided document text and be accurate. If the user refers to a table, column, field, row, section, value, or label with slightly imperfect wording, infer the closest reasonable match from the document before giving up. Prefer the most likely interpretation instead of returning nothing. If multiple interpretations are plausible, answer with the strongest match and briefly mention the ambiguity. If the answer is not available in the document - check if you can figure it out, and if not, reply exactly with "I could not find that in this file". Return plain text only. Keep the response concise, direct, and helpful. Do not use markdown, bullet lists, or headings.';

	private static final String DEFAULT_RECORD_DEVELOPER_NAME = 'GoogleClient';
	private static final String DEFAULT_RECORD_LABEL = 'Google Client';

	@TestVisible
	private static GoogleClientConfig__mdt configRecordOverride;

	private GoogleClientConfig__mdt configRecord;
	private IGoogleMetadataDeployer metadataDeployer;

    public GoogleMetadataConfigService() {
        this(new DefaultMetadataDeployer());
    }

	public GoogleMetadataConfigService(IGoogleMetadataDeployer deployer) {
		this.metadataDeployer = deployer;

		if (configRecordOverride != null) {
			this.configRecord = configRecordOverride;
		} else {
			Map<String, GoogleClientConfig__mdt> all = GoogleClientConfig__mdt.getAll();
			this.configRecord = (all != null && !all.isEmpty())
				? all.values()[0]
				: new GoogleClientConfig__mdt();
		}
    }

    public Id saveConfig(Map<String, Object> fieldApiToValue) {
        if (fieldApiToValue == null || fieldApiToValue.isEmpty()) {
            return null;
        }

		return deployNewMetadataChanges(applyManagedDefaults(fieldApiToValue));
    }

    public GoogleClientConfig__mdt getConfig() {
        return configRecord;
    }

	public Boolean hasConfigRecord() {
		return String.isNotBlank(configRecord == null ? null : configRecord.DeveloperName);
	}

	public IGoogleTargetFolderResolver getTargetFolderResolver() {
		return new GoogleMetadataTargetFolderResolver(this);
	}

    public Boolean isPreviewDisabled() {
		return configRecord.IsFilePreviewDisabled__c == true;
    }

	public Boolean isImageOcrEnabled() {
		return configRecord.IsImageOcrEnabled__c == true;
	}

	public Long getBigFileSizeInBytes() {
		Long configuredValue = (Long) configRecord.DefaultBigFileSize__c;
		return configuredValue == null ? DEFAULT_BIG_FILE_SIZE : configuredValue;
    }

	public Integer getDeleteChainSize() {
		Integer configuredValue = (Integer) configRecord.MaxDeleteChainSize__c;
		return configuredValue == null ? DEFAULT_MAX_DELETE_CHAIN_SIZE : configuredValue;
    }

    public String getDefaultUploadFolderId() {
        return configRecord.DefaultGoogleUploadFolderId__c;
    }

    public String getGoogleDriveAuthorizerClassName() {
        String customClassName = configRecord.CustomGoogleAuthorizerClass__c;
		return String.isNotBlank(customClassName) ? customClassName : DEFAULT_AUTH_CLASS_NAME;
    }

	public String getGoogleDriveServiceAccountEmail() {
        return configRecord.CustomGoogleServiceAccount__c;
    }

	public String getGoogleDriveCertificateName() {
        return configRecord.CustomGoogleCertificate__c;
    }

	public String getGoogleDriveFolderStructure() {
        return configRecord.CustomGoogleUploadFolderStructure__c;
    }

	public Boolean requiresRecordFolder() {
		String folderStructure = getGoogleDriveFolderStructure();
		return (
			folderStructure == GoogleCloudConstants.STRUCTURE_RECORD ||
			folderStructure == GoogleCloudConstants.STRUCTURE_USER_RECORD ||
			folderStructure == GoogleCloudConstants.STRUCTURE_RECORD_USER
		);
	}

	public String getGoogleGeminiKey() {
        return configRecord.CustomGeminiApiKey__c;
    }

	public String getGoogleAiModel() {
        return configRecord.CustomModelName__c;
    }

	public String getGoogleAgentLocation() {
        return configRecord.CustomAgentLocation__c;
    }

	public String getGoogleAgentProjectId() {
        return configRecord.CustomAgentProjectId__c;
    }

	public Boolean isFileIntelligenceEnabled() {
		return configRecord.IsFileIntelligenceEnabled__c == true;
	}

	public String getSummaryPrompt() {
		String configuredValue = configRecord.CustomSummaryPrompt__c;
		return String.isNotBlank(configuredValue) ? configuredValue : DEFAULT_SUMMARY_PROMPT;
	}

	public String getQuestionPrompt() {
		String configuredValue = configRecord.CustomQuestionPrompt__c;
		return String.isNotBlank(configuredValue) ? configuredValue : DEFAULT_QUESTION_PROMPT;
	}

	public Integer getQuestionMaxOutputTokens() {
		Integer configuredValue = (Integer) configRecord.QuestionMaxOutputTokens__c;
		return configuredValue == null ? DEFAULT_QUESTION_MAX_OUTPUT_TOKENS : configuredValue;
	}

	public String getGoogleDriveDomain() {
        return configRecord.OrganizationalDomain__c;
    }

	private Map<String, Object> applyManagedDefaults(Map<String, Object> fieldApiToValue) {
		Map<String, Object> normalizedValues = new Map<String, Object>(fieldApiToValue);

		applyBooleanDefaultIfMissing(normalizedValues, 'IsFilePreviewDisabled__c', configRecord.IsFilePreviewDisabled__c, false);
		applyBooleanDefaultIfMissing(normalizedValues, 'IsImageOcrEnabled__c', configRecord.IsImageOcrEnabled__c, false);
		applyNumberDefaultIfMissing(normalizedValues, 'DefaultBigFileSize__c', configRecord.DefaultBigFileSize__c, DEFAULT_BIG_FILE_SIZE);
		applyNumberDefaultIfMissing(normalizedValues, 'MaxDeleteChainSize__c', configRecord.MaxDeleteChainSize__c, DEFAULT_MAX_DELETE_CHAIN_SIZE);

		Boolean isIntelligenceEnabled = resolveBooleanValue(normalizedValues, 'IsFileIntelligenceEnabled__c', configRecord.IsFileIntelligenceEnabled__c);
		if (isIntelligenceEnabled) {
			applyStringDefaultIfMissing(normalizedValues, 'CustomSummaryPrompt__c', configRecord.CustomSummaryPrompt__c, DEFAULT_SUMMARY_PROMPT);
			applyStringDefaultIfMissing(normalizedValues, 'CustomQuestionPrompt__c', configRecord.CustomQuestionPrompt__c, DEFAULT_QUESTION_PROMPT);
			applyNumberDefaultIfMissing(normalizedValues, 'QuestionMaxOutputTokens__c', configRecord.QuestionMaxOutputTokens__c, DEFAULT_QUESTION_MAX_OUTPUT_TOKENS);
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