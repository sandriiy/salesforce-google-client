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