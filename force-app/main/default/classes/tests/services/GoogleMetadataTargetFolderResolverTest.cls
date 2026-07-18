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
@IsTest
private class GoogleMetadataTargetFolderResolverTest {
	@IsTest
	private static void testResolveUploadFolderIdPositivePrimaryOnly() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			DefaultGoogleUploadFolderId__c = 'primary_folder',
			AdditionalGoogleUploadFolderIds__c = 'secondary_folder;third_folder'
		);

		IGoogleTargetFolderResolver resolver = new GoogleMetadataTargetFolderResolver(new GoogleMetadataConfigService());
		List<String> primaryOnly = resolver.resolveUploadFolderId();

		Assert.areEqual(1, primaryOnly.size());
		Assert.areEqual('primary_folder', primaryOnly[0]);
	}

	@IsTest
	private static void testResolveUploadFolderCandidatesPositivePrimaryPlusAdditional() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			DefaultGoogleUploadFolderId__c = 'primary_folder',
			AdditionalGoogleUploadFolderIds__c = 'secondary_folder;third_folder'
		);

		IGoogleTargetFolderResolver resolver = new GoogleMetadataTargetFolderResolver(new GoogleMetadataConfigService());
		List<String> candidates = resolver.resolveUploadFolderCandidates();

		Assert.areEqual(3, candidates.size());
		Assert.areEqual('primary_folder', candidates[0]);
		Assert.areEqual('secondary_folder', candidates[1]);
		Assert.areEqual('third_folder', candidates[2]);
	}

	@IsTest
	private static void testResolveUploadFolderCandidatesPositivePrimaryOnly() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			DefaultGoogleUploadFolderId__c = 'primary_folder',
			AdditionalGoogleUploadFolderIds__c = null
		);

		IGoogleTargetFolderResolver resolver = new GoogleMetadataTargetFolderResolver(new GoogleMetadataConfigService());
		List<String> candidates = resolver.resolveUploadFolderCandidates();

		Assert.areEqual(1, candidates.size());
		Assert.areEqual('primary_folder', candidates[0]);
	}

	@IsTest
	private static void testResolveUploadFolderCandidatesPositiveNoPrimary() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			DefaultGoogleUploadFolderId__c = null,
			AdditionalGoogleUploadFolderIds__c = null
		);

		IGoogleTargetFolderResolver resolver = new GoogleMetadataTargetFolderResolver(new GoogleMetadataConfigService());
		Assert.areEqual(0, resolver.resolveUploadFolderCandidates().size());
	}
}
