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
public with sharing class GoogleCloudFilesSharingController {
	@TestVisible
	private static GoogleLocalFileSharingService sharingServiceOverride;

	@AuraEnabled
	public static GoogleSharingInfoDTO fetchSharingDetails(Id localFileRecordId) {
		GoogleLocalFileSharingService sharingService = resolveSharingService();
		return sharingService.fetchSharingDetails(localFileRecordId);
	}

	@AuraEnabled
	public static Id createNewSharing(Id localFileRecordId, String shareToObjectApiName, Id shareToRecordId, String uiAccessLevel) {
		GoogleLocalFileSharingService sharingService = resolveSharingService();
		return sharingService.createNewSharing(localFileRecordId, shareToObjectApiName, shareToRecordId, uiAccessLevel);
	}

	@AuraEnabled
	public static void modifyExistingSharingAccess(Id localFileRecordId, Id shareToRecordId, String uiAccessLevel) {
		GoogleLocalFileSharingService sharingService = resolveSharingService();
		sharingService.modifyExistingSharingAccess(localFileRecordId, shareToRecordId, uiAccessLevel);
	}

	@AuraEnabled
	public static void modifyExistingSharingVisibility(Id localFileRecordId, Id shareToRecordId, String visibility) {
		GoogleLocalFileSharingService sharingService = resolveSharingService();
		sharingService.modifyExistingSharingVisibility(localFileRecordId, shareToRecordId, visibility);
	}

	@AuraEnabled
	public static void deleteExistingSharing(Id localFileRecordId, Id shareToRecordId) {
		GoogleLocalFileSharingService sharingService = resolveSharingService();
		sharingService.deleteExistingSharing(localFileRecordId, shareToRecordId);
	}

	@AuraEnabled
	public static Id attachExistingFileToRecord(Id localFileRecordId, Id relatedRecordId, String source) {
		GoogleLocalFileSharingService sharingService = resolveSharingService();
		return sharingService.attachExistingFileToRecord(localFileRecordId, relatedRecordId, source);
	}

	@AuraEnabled
	public static List<GoogleFileLink__c> retrieveLinkedRecords(Id localFileRecordId) {
		GoogleLocalFileSharingService sharingService = resolveSharingService();
		return sharingService.retrieveLinkedRecords(localFileRecordId);
	}

    @AuraEnabled
    public static GoogleFileVersion__c createNewPublicLink(Id localFileVersionId, Datetime expirationDate, Boolean isDomainSkip) {
		GoogleLocalFileVersionPublicLinkService localPublicLinkService = new GoogleLocalFileVersionPublicLinkService();
		List<GoogleFileVersion__c> updatedFiles = localPublicLinkService.applyPublicLinkSharing(localFileVersionId, expirationDate, isDomainSkip);
		return updatedFiles.isEmpty() ? null : updatedFiles.get(0);
	}

	@AuraEnabled
    public static void deleteExistingPublicLink(Id localFileVersionId) {
		GoogleLocalFileVersionPublicLinkService localPublicLinkService = new GoogleLocalFileVersionPublicLinkService();
		localPublicLinkService.removePublicLinkSharing(localFileVersionId);
	}

	@AuraEnabled(cacheable=true)
    public static Boolean isPublicLinkDomain() {
		GoogleMetadataConfigService googleConfig = new GoogleMetadataConfigService();
		String googleDomain = googleConfig.getGoogleDriveDomain();
		return String.isNotBlank(googleDomain);
	}

	private static GoogleLocalFileSharingService resolveSharingService() {
		return sharingServiceOverride != null ? sharingServiceOverride : new GoogleLocalFileSharingService();
	}
}
