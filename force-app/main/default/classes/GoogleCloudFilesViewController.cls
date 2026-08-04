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
public with sharing class GoogleCloudFilesViewController {
    @AuraEnabled
    public static GoogleFileHeaderInfoDTO fetchFileHeaderDetails(Id localFileRecordId) {
		assertFileReadable(localFileRecordId);

		GoogleLocalFileService service = new GoogleLocalFileService();

        return service.retrieveGoogleFileHeaderDetails()
            .forFile(localFileRecordId)
            .execute();
	}

	@AuraEnabled(cacheable=true)
    public static List<GoogleFileVersion__c> retrieveLocalGoogleFileVersions(Id localFileRecordId) {
		assertFileReadable(localFileRecordId);

		return (List<GoogleFileVersion__c>) GoogleFileVersionSelector.query()
			.withBaseFields()
			.byParentId(localFileRecordId)
			.orderByCreatedDesc()
			.with('CreatedBy', new List<SObjectField>{ User.Name })
			.toList();
    }

	private static void assertFileReadable(Id localFileRecordId) {
		if (localFileRecordId == null) return;
		
		GoogleLocalFileService service = new GoogleLocalFileService();
		List<GoogleFile__c> accessibleFiles = service.stripInaccessibleRecords()
			.forFile(localFileRecordId)
			.forUser(UserInfo.getUserId())
			.strip();

		if (accessibleFiles.isEmpty()) {
			throw new AuraHandledException('You don’t have access to view this file. Please verify your permissions and try again');
		}
	}
}