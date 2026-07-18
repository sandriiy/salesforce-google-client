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
private class GoogleDriveCapacityErrorClassifierTest {
	private static String buildDriveErrorBody(Integer code, String reason, String message) {
		return '{"error":{"errors":[{"domain":"global","reason":"' + reason + '","message":"' + message + '"}],"code":' + code + ',"message":"' + message + '"}}';
	}

	private static Exception buildException(String message) {
		return new CalloutException(message);
	}

	@IsTest
	private static void testIsCapacityExhaustedErrorPositiveTeamDriveFileLimit() {
		Exception ex = buildException(buildDriveErrorBody(403, 'teamDriveFileLimitExceeded', 'Shared drive full'));

		Assert.isTrue(GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(ex));
	}

	@IsTest
	private static void testIsCapacityExhaustedErrorPositiveStorageQuota() {
		Exception ex = buildException(buildDriveErrorBody(403, 'storageQuotaExceeded', 'Storage full'));

		Assert.isTrue(GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(ex));
	}

	@IsTest
	private static void testIsCapacityExhaustedErrorPositiveNumChildren() {
		Exception ex = buildException(buildDriveErrorBody(403, 'numChildrenInNonRootLimitExceeded', 'Folder full'));

		Assert.isTrue(GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(ex));
	}

	@IsTest
	private static void testIsCapacityExhaustedErrorNegativeAuthError() {
		Exception ex = buildException(buildDriveErrorBody(403, 'authError', 'Invalid Credentials'));

		Assert.isFalse(GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(ex));
	}

	@IsTest
	private static void testIsCapacityExhaustedErrorNegativeInsufficientPermissions() {
		Exception ex = buildException(buildDriveErrorBody(403, 'insufficientFilePermissions', 'No access'));

		Assert.isFalse(GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(ex));
	}

	@IsTest
	private static void testIsCapacityExhaustedErrorNegativeRateLimit() {
		Exception ex = buildException(buildDriveErrorBody(403, 'rateLimitExceeded', 'Rate Limit Exceeded'));

		Assert.isFalse(GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(ex));
	}

	@IsTest
	private static void testIsCapacityExhaustedErrorNegativeWrongStatusCode() {
		Exception ex = buildException(buildDriveErrorBody(401, 'storageQuotaExceeded', 'Not really'));

		Assert.isFalse(GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(ex));
	}

	@IsTest
	private static void testIsCapacityExhaustedErrorNegativeNotFound() {
		Exception ex = buildException(buildDriveErrorBody(404, 'notFound', 'Missing'));

		Assert.isFalse(GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(ex));
	}

	@IsTest
	private static void testIsCapacityExhaustedErrorNegativeServerError() {
		Exception ex = buildException(buildDriveErrorBody(500, 'internalError', 'Backend Error'));

		Assert.isFalse(GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(ex));
	}

	@IsTest
	private static void testIsCapacityExhaustedErrorNegativeMalformedJson() {
		Exception ex = buildException('this is not JSON');

		Assert.isFalse(GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(ex));
	}

	@IsTest
	private static void testIsCapacityExhaustedErrorNegativeNullException() {
		Assert.isFalse(GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(null));
	}

	@IsTest
	private static void testIsCapacityExhaustedErrorNegativeBlankMessage() {
		Exception ex = buildException('');

		Assert.isFalse(GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(ex));
	}

	@IsTest
	private static void testIsCapacityExhaustedErrorPositiveSubstringFallback() {
		Exception ex = buildException('unexpected wrapper text before {"error":{"errors":[{"reason":"teamDriveFileLimitExceeded"}],"code":403}} and after');

		Assert.isTrue(GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(ex));
	}

	@IsTest
	private static void testExtractReasonPositive() {
		Exception ex = buildException(buildDriveErrorBody(403, 'teamDriveFileLimitExceeded', 'Shared drive full'));

		Assert.areEqual('teamDriveFileLimitExceeded', GoogleDriveCapacityErrorClassifier.extractReason(ex));
	}

	@IsTest
	private static void testExtractReasonPositiveNonCapacity() {
		Exception ex = buildException(buildDriveErrorBody(401, 'authError', 'Invalid Credentials'));

		Assert.areEqual('authError', GoogleDriveCapacityErrorClassifier.extractReason(ex));
	}

	@IsTest
	private static void testExtractReasonNegativeMalformed() {
		Exception ex = buildException('not JSON at all');

		Assert.isNull(GoogleDriveCapacityErrorClassifier.extractReason(ex));
	}

	@IsTest
	private static void testExtractReasonNegativeNull() {
		Assert.isNull(GoogleDriveCapacityErrorClassifier.extractReason(null));
	}
}
