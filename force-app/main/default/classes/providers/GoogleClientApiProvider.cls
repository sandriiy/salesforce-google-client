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
public with sharing class GoogleClientApiProvider {
	private final String DEFAULT_ERROR_HANDLER = 'GoogleFileWebErrorHandler';
	private final String DEFAULT_TOKEN_CACHE_NAME = 'accessToken';
	private final String DEFAULT_AGENT_NAME = 'Apex Client 1/1';

	@TestVisible
	private static String authorizerClassNameOverride;

	private GoogleCacheConfigService cacheService = new GoogleCacheConfigService();
	private GoogleMetadataConfigService metadataService = new GoogleMetadataConfigService();

	public Boolean validateGoogleServiceAccount() {
		String authorizerClassName = authorizerClassNameOverride != null
			? authorizerClassNameOverride
			: metadataService.getGoogleDriveAuthorizerClassName();

		GoogleCredential testCredential = new GoogleAuthorizationCodeFlow.Builder()
			.setLocalGoogleAuthorizer(authorizerClassName)
			.build();

		return String.isNotBlank(testCredential.accessToken);
	}

	public GoogleDrive retrieveGoogleDriveClient() {
		GoogleCredential googleDriveCredentials = retrieveGoogleCredential();
		return new GoogleDrive(googleDriveCredentials, DEFAULT_AGENT_NAME)
			.withFailureStrategy(DEFAULT_ERROR_HANDLER);
	}

	public GoogleCredential retrieveGoogleClientCreds() {
		return retrieveGoogleCredential();
	}

	private GoogleCredential retrieveGoogleCredential() {
		String authorizerClassName = authorizerClassNameOverride != null
			? authorizerClassNameOverride
			: metadataService.getGoogleDriveAuthorizerClassName();

		GoogleAuthorizationCodeFlow.Builder builder = new GoogleAuthorizationCodeFlow.Builder()
			.setLocalGoogleAuthorizer(authorizerClassName);

		Cache.SessionPartition sessionPartition = cacheService.getSessionPartition();
		Cache.OrgPartition orgPartition = cacheService.getOrgPartition();

		if (sessionPartition != null) {
			builder.setLocalPlatformCache(sessionPartition, DEFAULT_TOKEN_CACHE_NAME);
		} else if (orgPartition != null) {
			builder.setLocalPlatformCache(orgPartition, DEFAULT_TOKEN_CACHE_NAME);
		}

		return builder.build();
	}
}