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
private class GoogleCacheConfigServiceTest {
	private class FakeCacheProvider implements IGoogleCacheProvider {
		private Map<String, Object> store = new Map<String, Object>();

		public void put(String key, String value) {
			store.put(key, value);
		}

		public Object get(String key) {
			return store.get(key);
		}

		public void remove(String key) {
			store.remove(key);
		}

		public Cache.SessionPartition getSessionPartition() {
			return null;
		}

		public Cache.OrgPartition getOrgPartition() {
			return null;
		}
	}

	private class ThrowingCacheProvider implements IGoogleCacheProvider {
		public void put(String key, String value) {
			throw new CalloutException('x');
		}

		public Object get(String key) {
			throw new CalloutException('x');
		}

		public void remove(String key) {
			throw new CalloutException('x');
		}

		public Cache.SessionPartition getSessionPartition() {
			return null;
		}

		public Cache.OrgPartition getOrgPartition() {
			return null;
		}
	}

	@IsTest
	private static void testCtorPositiveDefault() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService();
		Assert.areNotEqual(null, cacheConfigService);
	}

	@IsTest
	private static void testCtorPositiveNullProvider() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService((IGoogleCacheProvider) null);
		Assert.areNotEqual(null, cacheConfigService);
	}

	@IsTest
	private static void testGetPartitionsPositiveNulls() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService(new FakeCacheProvider());
		Assert.areEqual(null, cacheConfigService.getSessionPartition());
		Assert.areEqual(null, cacheConfigService.getOrgPartition());
	}

	@IsTest
	private static void testGetNegativeBlankKey() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService(new FakeCacheProvider());
		try {
			cacheConfigService.get('');
			Assert.isTrue(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			Assert.isTrue(true);
		}
	}

	@IsTest
	private static void testGetNegativeLongKey() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService(new FakeCacheProvider());
		String cacheKey = '';
		while (cacheKey.length() <= 121) cacheKey += 'a';

		try {
			cacheConfigService.get(cacheKey);
			Assert.isTrue(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			Assert.isTrue(true);
		}
	}

	@IsTest
	private static void testPutNegativeNullValue() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService(new FakeCacheProvider());
		try {
			cacheConfigService.put('abc', null);
			Assert.isTrue(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			Assert.isTrue(true);
		}
	}

	@IsTest
	private static void testPutGetRemovePositiveRoundtrip() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService(new FakeCacheProvider());

		String rawCacheKey = 'a-b_c';
		String cacheValue = 'v1';

		cacheConfigService.put(rawCacheKey, cacheValue);
		Assert.areEqual(cacheValue, cacheConfigService.get(rawCacheKey));

		cacheConfigService.remove(rawCacheKey);
		Assert.areEqual(null, cacheConfigService.get(rawCacheKey));
	}

	@IsTest
	private static void testPutGetRemovePositiveSanitizedKeyToEmpty() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService(new FakeCacheProvider());

		String rawCacheKey = '---___---';
		String cacheValue = 'v1';

		cacheConfigService.put(rawCacheKey, cacheValue);
		Assert.areEqual(cacheValue, cacheConfigService.get(rawCacheKey));

		cacheConfigService.remove(rawCacheKey);
		Assert.areEqual(null, cacheConfigService.get(rawCacheKey));
	}

	@IsTest
	private static void testGenerateConfigIdPositiveValidate() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService(new FakeCacheProvider());
		String generatedConfigId = cacheConfigService.generateConfigId();

		Assert.areEqual(true, cacheConfigService.isValidConfigId(generatedConfigId));
		Assert.areEqual(false, cacheConfigService.isValidConfigId(null));
		Assert.areEqual(false, cacheConfigService.isValidConfigId(''));
		Assert.areEqual(false, cacheConfigService.isValidConfigId('cfg_abc_12345678'));
		Assert.areEqual(false, cacheConfigService.isValidConfigId('cfg_123_zzzzzzzz'));
		Assert.areEqual(false, cacheConfigService.isValidConfigId(' cfg_123_12345678 '));
	}

	@IsTest
	private static void testPutConfigNegativeInvalidId() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService(new FakeCacheProvider());
		try {
			cacheConfigService.putConfig('bad', '{}');
			Assert.isTrue(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			Assert.isTrue(true);
		}
	}

	@IsTest
	private static void testGetConfigNegativeInvalidId() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService(new FakeCacheProvider());
		try {
			cacheConfigService.getConfig('bad');
			Assert.isTrue(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			Assert.isTrue(true);
		}
	}

	@IsTest
	private static void testRemoveConfigNegativeInvalidId() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService(new FakeCacheProvider());
		try {
			cacheConfigService.removeConfig('bad');
			Assert.isTrue(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			Assert.isTrue(true);
		}
	}

	@IsTest
	private static void testPutConfigNegativeNullPayload() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService(new FakeCacheProvider());
		String generatedConfigId = cacheConfigService.generateConfigId();

		try {
			cacheConfigService.putConfig(generatedConfigId, null);
			Assert.isTrue(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			Assert.isTrue(true);
		}
	}

	@IsTest
	private static void testPutGetRemoveConfigPositiveRoundtrip() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService(new FakeCacheProvider());

		String generatedConfigId = cacheConfigService.generateConfigId();
		String payloadJson = '{"a":1}';

		cacheConfigService.putConfig(generatedConfigId, payloadJson);
		Assert.areEqual(payloadJson, cacheConfigService.getConfig(generatedConfigId));

		cacheConfigService.removeConfig(generatedConfigId);
		Assert.areEqual(null, cacheConfigService.getConfig(generatedConfigId));
	}

	@IsTest
	private static void testPutNegativeCacheAccess() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService(new ThrowingCacheProvider());
		String cacheKey = 'k';
		String cacheValue = 'v';

		try {
			cacheConfigService.put(cacheKey, cacheValue);
			Assert.isTrue(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			Assert.isTrue(e.getMessage().contains('Unable to access Platform Cache partition'));
		}
	}

	@IsTest
	private static void testGetNegativeCacheAccess() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService(new ThrowingCacheProvider());
		String cacheKey = 'k';

		try {
			cacheConfigService.get(cacheKey);
			Assert.isTrue(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			Assert.isTrue(e.getMessage().contains('Unable to access Platform Cache partition'));
		}
	}

	@IsTest
	private static void testRemoveNegativeCacheAccess() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService(new ThrowingCacheProvider());
		String cacheKey = 'k';

		try {
			cacheConfigService.remove(cacheKey);
			Assert.isTrue(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			Assert.isTrue(e.getMessage().contains('Unable to access Platform Cache partition'));
		}
	}

	@IsTest
	private static void testPutConfigNegativeCacheAccess() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService(new ThrowingCacheProvider());
		String generatedConfigId = cacheConfigService.generateConfigId();
		String payloadJson = '{"a":1}';

		try {
			cacheConfigService.putConfig(generatedConfigId, payloadJson);
			Assert.isTrue(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			Assert.isTrue(e.getMessage().contains('Unable to access Platform Cache partition'));
		}
	}

	@IsTest
	private static void testGetConfigNegativeCacheAccess() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService(new ThrowingCacheProvider());
		String generatedConfigId = cacheConfigService.generateConfigId();

		try {
			cacheConfigService.getConfig(generatedConfigId);
			Assert.isTrue(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			Assert.isTrue(e.getMessage().contains('Unable to access Platform Cache partition'));
		}
	}

	@IsTest
	private static void testRemoveConfigNegativeCacheAccess() {
		GoogleCacheConfigService cacheConfigService = new GoogleCacheConfigService(new ThrowingCacheProvider());
		String generatedConfigId = cacheConfigService.generateConfigId();

		try {
			cacheConfigService.removeConfig(generatedConfigId);
			Assert.isTrue(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			Assert.isTrue(e.getMessage().contains('Unable to access Platform Cache partition'));
		}
	}
}