public without sharing class GoogleFileEditDetailsAction {
    public class Input {
        @InvocableVariable(required=true)
        public GoogleFile__c localFileRecord;
        @InvocableVariable(required=true)
        public GoogleFileVersion__c localFileVersionRecord;
        @InvocableVariable
        public String newFileName;
        @InvocableVariable
        public String newFileVersionName;
        @InvocableVariable
        public String newFileDescription;
    }

    @InvocableMethod(
        label='Edit Google File Details'
        description='Updates local Google file and Version details'
    )
    public static void editDetails(List<Input> inputs) {
        if (inputs == null || inputs.isEmpty()) return;
        
        List<GoogleFileUpdateRequestDTO> requests = transformInputsToRequest(inputs);
        new GoogleLocalFileService().updateGoogleFileDetails(requests);
    }

	private static List<GoogleFileUpdateRequestDTO> transformInputsToRequest(List<Input> inputs) {
		List<GoogleFileUpdateRequestDTO> requests = new List<GoogleFileUpdateRequestDTO>();
		
		for (Input input : inputs) {
            GoogleFileUpdateRequestDTO request = new GoogleFileUpdateRequestDTO();
            request.localGoogleFileRecord = input.localFileRecord;
            request.localGoogleFileVersionRecord = input.localFileVersionRecord;
            request.fileName = input.newFileName;
            request.fileVersionName = input.newFileVersionName;
            request.fileDescription = input.newFileDescription;

            requests.add(request);
        }

		return requests;
	}
}