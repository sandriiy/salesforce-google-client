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

        return deployNewMetadataChanges(fieldApiToValue);
    }

    public GoogleClientConfig__mdt getConfig() {
        return configRecord;
    }

	public IGoogleTargetFolderResolver getTargetFolderResolver() {
		return new GoogleMetadataTargetFolderResolver(this);
	}

    public Boolean isPreviewDisabled() {
        return configRecord.IsFilePreviewDisabled__c;
    }

	public Boolean isImageOcrEnabled() {
		return configRecord.IsImageOcrEnabled__c == true;
	}

	public Long getBigFileSizeInBytes() {
        return (Long) configRecord.DefaultBigFileSize__c;
    }

	public Integer getDeleteChainSize() {
        return (Integer) configRecord.MaxDeleteChainSize__c;
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

	public String getGoogleDriveDomain() {
        return configRecord.OrganizationalDomain__c;
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