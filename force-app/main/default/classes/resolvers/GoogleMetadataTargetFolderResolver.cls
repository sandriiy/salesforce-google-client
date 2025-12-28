public with sharing class GoogleMetadataTargetFolderResolver implements IGoogleTargetFolderResolver {
    private final GoogleMetadataConfigService config;

    public GoogleMetadataTargetFolderResolver(GoogleMetadataConfigService config) {
        this.config = config;
    }

    public List<String> resolveUploadFolderId() {
        return new List<String>{config.getDefaultUploadFolderId()};
    }
}