public inherited sharing class GoogleMetadataConfigService {
	public class GoogleMetadataConfigException extends Exception {}

	private static GoogleOrgCacheProvider orgWideProvider = new GoogleOrgCacheProvider(GoogleCacheConfigService.PARTITION);
	private static GoogleCacheConfigService cacheService = new GoogleCacheConfigService(orgWideProvider);

	@TestVisible
	public static final String DEFAULT_METADATA_DEPLOY_KEY = 'DefaultGoogleMetadataDeployerKey';
	@TestVisible
	public static final String DEFAULT_AUTH_CLASS_NAME = 'DefaultGoogleDriveAuthorizer';

	private GoogleClientConfig__mdt configRecord;
	private IGoogleMetadataDeployer metadataDeployer;

    public GoogleMetadataConfigService() {
        this(new DefaultMetadataDeployer());
    }

	public GoogleMetadataConfigService(IGoogleMetadataDeployer deployer) {
		Map<String, GoogleClientConfig__mdt> all = GoogleClientConfig__mdt.getAll();
		this.metadataDeployer = deployer;
		this.configRecord = (all != null && !all.isEmpty())
			? all.values()[0]
			: new GoogleClientConfig__mdt();
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

	public String getGoogleGeminiKey() {
        return configRecord.CustomGeminiApiKey__c;
    }

	public String getGoogleAiModel() {
        return configRecord.CustomModelName__c;
    }

	public String getGoogleVertexLocation() {
        return configRecord.CustomVertexLocation__c;
    }

	public String getGoogleVertexProjectId() {
        return configRecord.CustomVertexProjectId__c;
    }

	public String getGoogleDriveDomain() {
        return configRecord.OrganizationalDomain__c;
    }

	private Id deployNewMetadataChanges(Map<String, Object> fieldApiToValue) {
		try {
            Metadata.DeployContainer container = new Metadata.DeployContainer();

            Metadata.CustomMetadata cmdt = new Metadata.CustomMetadata();
            cmdt.fullName = 'GoogleClientConfig__mdt.' + configRecord.DeveloperName;
            cmdt.label = configRecord.MasterLabel;

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