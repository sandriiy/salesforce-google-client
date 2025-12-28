public with sharing class GoogleFileVersionExpireLinkAction {
    public class Input {
        @InvocableVariable(required=true)
        public Id localFileRecordId;
    }

    @InvocableMethod(
        label='Public Link Expiration'
        description='Public link expiration for a Google Drive file (Local Google File Version)'
    )
    public static void expireLink(List<Input> inputs) {
        if (inputs == null || inputs.isEmpty()) return;

        GoogleLocalFileVersionService localVersionService = new GoogleLocalFileVersionService();

        for (Input input : inputs) {
            if (input == null) continue;
			localVersionService.removePublicLinkSharing(input.localFileRecordId);
        }
    }
}