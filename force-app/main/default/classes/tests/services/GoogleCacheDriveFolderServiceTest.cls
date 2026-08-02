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
private class GoogleCacheDriveFolderServiceTest {
	private static GoogleCacheDriveFolderService buildService() {
		GoogleCacheDriveFolderService.cacheProviderOverride = new GoogleInMemoryCacheProvider();
		return new GoogleCacheDriveFolderService();
	}

	private static GoogleCacheDriveFolderService buildUnavailableService() {
		GoogleCacheDriveFolderService.cacheProviderOverride = new GoogleInMemoryCacheProvider(true);
		return new GoogleCacheDriveFolderService();
	}

	@IsTest
	private static void testBuildFolderKeyPositiveProducesPlatformCacheSafeKey() {
		GoogleCacheDriveFolderService folderCache = buildService();
		Id targetId = GoogleCloudTestFactory.fakeId(Account.SObjectType);

		Test.startTest();
		String folderKey = folderCache.buildFolderKey('1AbCdEfGhIjKlMnOpQrStUvWxYz012345', targetId);
		Test.stopTest();

		Assert.isNotNull(folderKey);
		Assert.isTrue(folderKey.startsWith(GoogleCacheDriveFolderService.KEY_PREFIX));
		Assert.isTrue(folderKey.length() <= 50, 'Platform Cache rejects keys longer than 50 characters');
		Assert.isTrue(Pattern.matches('^[A-Za-z0-9]+$', folderKey), 'Platform Cache keys must be alphanumeric');
	}

	@IsTest
	private static void testBuildFolderKeyPositiveDistinguishesParentAndTarget() {
		GoogleCacheDriveFolderService folderCache = buildService();
		Id firstTargetId = GoogleCloudTestFactory.fakeId(Account.SObjectType);
		Id secondTargetId = GoogleCloudTestFactory.fakeId(Account.SObjectType);

		Test.startTest();
		String sameTargetUnderRootA = folderCache.buildFolderKey('ROOT_A', firstTargetId);
		String sameTargetUnderRootB = folderCache.buildFolderKey('ROOT_B', firstTargetId);
		String otherTargetUnderRootA = folderCache.buildFolderKey('ROOT_A', secondTargetId);
		String repeatedKey = folderCache.buildFolderKey('ROOT_A', firstTargetId);
		Test.stopTest();

		Assert.areEqual(sameTargetUnderRootA, repeatedKey, 'The same parent and target must always produce the same key');
		Assert.areNotEqual(sameTargetUnderRootA, sameTargetUnderRootB);
		Assert.areNotEqual(sameTargetUnderRootA, otherTargetUnderRootA);
	}

	@IsTest
	private static void testBuildFolderKeyNegativeMissingInput() {
		GoogleCacheDriveFolderService folderCache = buildService();

		Test.startTest();
		String blankParentKey = folderCache.buildFolderKey('', GoogleCloudTestFactory.fakeId(Account.SObjectType));
		String missingTargetKey = folderCache.buildFolderKey('ROOT_A', null);
		Test.stopTest();

		Assert.isNull(blankParentKey);
		Assert.isNull(missingTargetKey);
	}

	@IsTest
	private static void testPutAndGetFolderIdPositive() {
		GoogleCacheDriveFolderService folderCache = buildService();
		String folderKey = folderCache.buildFolderKey('ROOT_A', GoogleCloudTestFactory.fakeId(Account.SObjectType));

		Test.startTest();
		folderCache.putFolderId(folderKey, 'FOLDER_01');
		String cachedFolderId = folderCache.getFolderId(folderKey);
		Test.stopTest();

		Assert.areEqual('FOLDER_01', cachedFolderId);
		Assert.isFalse(folderCache.isPending(folderKey));
	}

	@IsTest
	private static void testMarkPendingPositiveHidesFolderUntilResolved() {
		GoogleCacheDriveFolderService folderCache = buildService();
		String folderKey = folderCache.buildFolderKey('ROOT_A', GoogleCloudTestFactory.fakeId(Account.SObjectType));

		Test.startTest();
		folderCache.markPending(folderKey);
		Boolean isPendingWhileClaimed = folderCache.isPending(folderKey);
		String folderIdWhileClaimed = folderCache.getFolderId(folderKey);

		folderCache.putFolderId(folderKey, 'FOLDER_01');
		Boolean isPendingAfterResolution = folderCache.isPending(folderKey);
		Test.stopTest();

		Assert.isTrue(isPendingWhileClaimed);
		Assert.isNull(folderIdWhileClaimed, 'A pending claim must never be mistaken for a resolved folder');
		Assert.isFalse(isPendingAfterResolution);
		Assert.areEqual('FOLDER_01', folderCache.getFolderId(folderKey));
	}

	@IsTest
	private static void testIsPendingPositiveExpiresStaleClaim() {
		GoogleCacheDriveFolderService folderCache = buildService();
		String folderKey = folderCache.buildFolderKey('ROOT_A', GoogleCloudTestFactory.fakeId(Account.SObjectType));

		Long staleClaimedAt = DateTime.now().getTime() - (GoogleCacheDriveFolderService.PENDING_LIFESPAN_MILLISECONDS * 2);
		GoogleCacheDriveFolderService.cacheProviderOverride.put(folderKey, GoogleCacheDriveFolderService.PENDING_PREFIX + ':' + String.valueOf(staleClaimedAt));

		Test.startTest();
		Boolean isPending = folderCache.isPending(folderKey);
		Test.stopTest();

		Assert.isFalse(isPending, 'An abandoned claim must expire so folder creation can proceed');
	}

	@IsTest
	private static void testEvictPositiveRemovesEntry() {
		GoogleCacheDriveFolderService folderCache = buildService();
		String folderKey = folderCache.buildFolderKey('ROOT_A', GoogleCloudTestFactory.fakeId(Account.SObjectType));
		folderCache.putFolderId(folderKey, 'FOLDER_01');

		Test.startTest();
		folderCache.evict(folderKey);
		Test.stopTest();

		Assert.isNull(folderCache.getFolderId(folderKey));
	}

	@IsTest
	private static void testPutFolderIdNegativeIgnoresBlankFolderId() {
		GoogleCacheDriveFolderService folderCache = buildService();
		String folderKey = folderCache.buildFolderKey('ROOT_A', GoogleCloudTestFactory.fakeId(Account.SObjectType));

		Test.startTest();
		folderCache.putFolderId(folderKey, '');
		Test.stopTest();

		Assert.isNull(folderCache.getFolderId(folderKey));
	}

	@IsTest
	private static void testUnavailableCacheNegativeDegradesToMissWithoutThrowing() {
		GoogleCacheDriveFolderService folderCache = buildUnavailableService();
		String folderKey = folderCache.buildFolderKey('ROOT_A', GoogleCloudTestFactory.fakeId(Account.SObjectType));

		Test.startTest();
		folderCache.markPending(folderKey);
		folderCache.putFolderId(folderKey, 'FOLDER_01');
		folderCache.evict(folderKey);

		String cachedFolderId = folderCache.getFolderId(folderKey);
		Boolean isPending = folderCache.isPending(folderKey);
		Test.stopTest();

		Assert.isNull(cachedFolderId, 'An unallocated Platform Cache partition must read as a clean miss');
		Assert.isFalse(isPending);
	}

	@IsTest
	private static void testBlankKeyNegativeIsAlwaysAMiss() {
		GoogleCacheDriveFolderService folderCache = buildService();

		Test.startTest();
		folderCache.markPending(null);
		folderCache.putFolderId(null, 'FOLDER_01');
		folderCache.evict(null);
		Test.stopTest();

		Assert.isNull(folderCache.getFolderId(null));
		Assert.isFalse(folderCache.isPending(null));
	}
}
