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
private class GoogleFileVersionContextResolverTest {
	private static final String DOCX_MIME_TYPE = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
	private static final Long ANALYSIS_LIMIT_BYTES = GoogleCloudConstants.MAX_SUMMARY_FILE_SIZE_BYTES;
	private static final Long OVER_ANALYSIS_LIMIT_BYTES = ANALYSIS_LIMIT_BYTES + 1;
	private static final Long SMALL_UPLOAD_BYTES = 2048L;
	private static final Long SMALL_WORKSPACE_COPY_BYTES = 112000L;

	private static GoogleFileVersion__c buildVersion(Long uploadSize, String docsId, Long docsSize) {
		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType))
			.withName('Brochure.docx')
			.withType(DOCX_MIME_TYPE)
			.withSize(uploadSize)
			.withDriveId('GD_BROCHURE')
			.withDocsId(docsId)
			.withDocsSize(docsSize)
			.build();
		version.Id = GoogleCloudTestFactory.fakeId(GoogleFileVersion__c.SObjectType);
		Formula.recalculateFormulas(new List<GoogleFileVersion__c>{ version });

		return version;
	}

	@IsTest
	private static void testSupportsInteractiveIntelligencePositiveLargeUploadWithFittingCopy() {
		GoogleFileVersion__c version = buildVersion(OVER_ANALYSIS_LIMIT_BYTES, 'DOCS_BROCHURE', SMALL_WORKSPACE_COPY_BYTES);
		GoogleFileVersionContextResolver resolver = new GoogleFileVersionContextResolver();

		Assert.isTrue(resolver.supportsInteractiveIntelligence(version));
		Assert.isTrue(resolver.supportsSummary(version));
	}

	@IsTest
	private static void testSupportsInteractiveIntelligenceNegativeSmallUploadWithOversizedCopy() {
		GoogleFileVersion__c version = buildVersion(SMALL_UPLOAD_BYTES, 'DOCS_BROCHURE', OVER_ANALYSIS_LIMIT_BYTES);
		GoogleFileVersionContextResolver resolver = new GoogleFileVersionContextResolver();

		Assert.isFalse(resolver.supportsInteractiveIntelligence(version));
		Assert.isFalse(resolver.supportsSummary(version));
	}

	@IsTest
	private static void testSupportsInteractiveIntelligenceNegativeLargeUploadWithUnmeasuredCopy() {
		GoogleFileVersion__c version = buildVersion(OVER_ANALYSIS_LIMIT_BYTES, 'DOCS_BROCHURE', null);
		GoogleFileVersionContextResolver resolver = new GoogleFileVersionContextResolver();

		Assert.isFalse(resolver.supportsInteractiveIntelligence(version));
		Assert.isFalse(resolver.supportsSummary(version));
	}

	@IsTest
	private static void testSupportsInteractiveIntelligencePositiveCopyExactlyAtTheLimit() {
		GoogleFileVersionContextResolver resolver = new GoogleFileVersionContextResolver();

		Assert.isTrue(resolver.supportsInteractiveIntelligence(buildVersion(OVER_ANALYSIS_LIMIT_BYTES, 'DOCS_BROCHURE', ANALYSIS_LIMIT_BYTES)));
		Assert.isFalse(resolver.supportsInteractiveIntelligence(buildVersion(OVER_ANALYSIS_LIMIT_BYTES, 'DOCS_BROCHURE', OVER_ANALYSIS_LIMIT_BYTES)));
	}

	@IsTest
	private static void testCollectSummaryCandidateVersionIdsNegativeLargeUploadAtInsert() {
		GoogleFileVersion__c smallUpload = buildVersion(SMALL_UPLOAD_BYTES, null, null);
		GoogleFileVersion__c largeUpload = buildVersion(OVER_ANALYSIS_LIMIT_BYTES, null, null);

		Set<Id> candidateVersionIds = new GoogleFileVersionContextResolver().collectSummaryCandidateVersionIds(
			new List<GoogleFileVersion__c>{ smallUpload, largeUpload }
		);

		Assert.areEqual(new Set<Id>{ smallUpload.Id }, candidateVersionIds);
	}

	@IsTest
	private static void testCollectSummaryCandidatesAdmittedByWorkspaceCopyPositiveOnlyLargeUploadWithFittingCopy() {
		GoogleFileVersion__c admittedByCopy = buildVersion(OVER_ANALYSIS_LIMIT_BYTES, 'DOCS_ADMITTED', SMALL_WORKSPACE_COPY_BYTES);
		GoogleFileVersion__c admittedAtInsert = buildVersion(SMALL_UPLOAD_BYTES, 'DOCS_SMALL', SMALL_WORKSPACE_COPY_BYTES);
		GoogleFileVersion__c oversizedCopy = buildVersion(OVER_ANALYSIS_LIMIT_BYTES, 'DOCS_OVERSIZED', OVER_ANALYSIS_LIMIT_BYTES);
		GoogleFileVersion__c smallUploadOversizedCopy = buildVersion(SMALL_UPLOAD_BYTES, 'DOCS_GROWN', OVER_ANALYSIS_LIMIT_BYTES);
		GoogleFileVersion__c unmeasuredCopy = buildVersion(OVER_ANALYSIS_LIMIT_BYTES, 'DOCS_UNMEASURED', null);

		Set<Id> admittedVersionIds = new GoogleFileVersionContextResolver().collectSummaryCandidatesAdmittedByWorkspaceCopy(
			new List<GoogleFileVersion__c>{ admittedByCopy, admittedAtInsert, oversizedCopy, smallUploadOversizedCopy, unmeasuredCopy }
		);

		Assert.areEqual(new Set<Id>{ admittedByCopy.Id }, admittedVersionIds);
	}

	@IsTest
	private static void testCollectSummaryCandidatesAdmittedByWorkspaceCopyNegativeNoVersions() {
		GoogleFileVersionContextResolver resolver = new GoogleFileVersionContextResolver();

		Assert.isTrue(resolver.collectSummaryCandidatesAdmittedByWorkspaceCopy(null).isEmpty());
		Assert.isTrue(resolver.collectSummaryCandidatesAdmittedByWorkspaceCopy(new List<GoogleFileVersion__c>()).isEmpty());
	}

	@IsTest
	private static void testResolveWorkspaceCopySizeInBytesPositivePrefersMeasuredCopy() {
		GoogleFileVersionContextResolver resolver = new GoogleFileVersionContextResolver();

		Assert.areEqual(SMALL_WORKSPACE_COPY_BYTES, resolver.resolveWorkspaceCopySizeInBytes(buildVersion(OVER_ANALYSIS_LIMIT_BYTES, 'DOCS_BROCHURE', SMALL_WORKSPACE_COPY_BYTES)));
		Assert.areEqual(OVER_ANALYSIS_LIMIT_BYTES, resolver.resolveWorkspaceCopySizeInBytes(buildVersion(OVER_ANALYSIS_LIMIT_BYTES, 'DOCS_BROCHURE', null)));
		Assert.isNull(resolver.resolveWorkspaceCopySizeInBytes(null));
	}
}
