public inherited sharing class GoogleMetadataConfigService {
	public class GoogleMetadataConfigException extends Exception {}

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

    public void saveConfig(Map<String, Object> fieldApiToValue) {
        if (fieldApiToValue == null || fieldApiToValue.isEmpty()) {
            return;
        }

        deployNewMetadataChanges(fieldApiToValue);
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

    public String getGoogleAuthorizerClassName() {
        return configRecord.CustomGoogleAuthorizerClass__c;
    }

	private void deployNewMetadataChanges(Map<String, Object> fieldApiToValue) {
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
            if (deploymentId == null) {
                throw new GoogleMetadataConfigException('Failed to enqueue Custom Metadata deployment');
            }
        } catch (Exception ex) {
            throw new GoogleMetadataConfigException('Failed to save Google Client configuration');
        }
	}

	private class DefaultMetadataDeployer implements IGoogleMetadataDeployer {
		public Id enqueue(Metadata.DeployContainer container) {
			return Metadata.Operations.enqueueDeployment(container, null);
		}
	}
}