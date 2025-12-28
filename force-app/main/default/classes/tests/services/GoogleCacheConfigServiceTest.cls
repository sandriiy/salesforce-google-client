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
	private static void ctorTestSuccessDefault() {
		GoogleCacheConfigService svc = new GoogleCacheConfigService();
		System.assertNotEquals(null, svc);
	}

	@IsTest
	private static void ctorTestSuccessNullProvider() {
		GoogleCacheConfigService svc = new GoogleCacheConfigService((IGoogleCacheProvider) null);
		System.assertNotEquals(null, svc);
	}

	@IsTest
	private static void getSessionPartitionTestSuccessNulls() {
		GoogleCacheConfigService svc = new GoogleCacheConfigService(new FakeCacheProvider());
		System.assertEquals(null, svc.getSessionPartition());
		System.assertEquals(null, svc.getOrgPartition());
	}

	@IsTest
	private static void getTestFailBlankKey() {
		GoogleCacheConfigService svc = new GoogleCacheConfigService(new FakeCacheProvider());
		try {
			svc.get('');
			System.assert(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			System.assert(true);
		}
	}

	@IsTest
	private static void getTestFailLongKey() {
		GoogleCacheConfigService svc = new GoogleCacheConfigService(new FakeCacheProvider());
		String k = '';
		while (k.length() <= 121) k += 'a';
		try {
			svc.get(k);
			System.assert(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			System.assert(true);
		}
	}

	@IsTest
	private static void putTestFailNullValue() {
		GoogleCacheConfigService svc = new GoogleCacheConfigService(new FakeCacheProvider());
		try {
			svc.put('abc', null);
			System.assert(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			System.assert(true);
		}
	}

	@IsTest
	private static void putGetRemoveTestSuccessRoundtrip() {
		GoogleCacheConfigService svc = new GoogleCacheConfigService(new FakeCacheProvider());

		svc.put('a-b_c', 'v1');
		System.assertEquals('v1', svc.get('a-b_c'));

		svc.remove('a-b_c');
		System.assertEquals(null, svc.get('a-b_c'));
	}

	@IsTest
	private static void generateConfigIdTestSuccessValidate() {
		GoogleCacheConfigService svc = new GoogleCacheConfigService(new FakeCacheProvider());
		String id = svc.generateConfigId();

		System.assertEquals(true, svc.isValidConfigId(id));
		System.assertEquals(false, svc.isValidConfigId(null));
		System.assertEquals(false, svc.isValidConfigId(''));
		System.assertEquals(false, svc.isValidConfigId('cfg_abc_12345678'));
		System.assertEquals(false, svc.isValidConfigId('cfg_123_zzzzzzzz'));
	}

	@IsTest
	private static void putConfigTestFailInvalidId() {
		GoogleCacheConfigService svc = new GoogleCacheConfigService(new FakeCacheProvider());
		try {
			svc.putConfig('bad', '{}');
			System.assert(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			System.assert(true);
		}
	}

	@IsTest
	private static void putConfigTestFailNullPayload() {
		GoogleCacheConfigService svc = new GoogleCacheConfigService(new FakeCacheProvider());
		String id = svc.generateConfigId();
		try {
			svc.putConfig(id, null);
			System.assert(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			System.assert(true);
		}
	}

	@IsTest
	private static void putGetRemoveConfigTestSuccessRoundtrip() {
		GoogleCacheConfigService svc = new GoogleCacheConfigService(new FakeCacheProvider());

		String id = svc.generateConfigId();
		svc.putConfig(id, '{"a":1}');
		System.assertEquals('{"a":1}', svc.getConfig(id));

		svc.removeConfig(id);
		System.assertEquals(null, svc.getConfig(id));
	}

	@IsTest
	private static void putTestFailCacheAccess() {
		GoogleCacheConfigService svc = new GoogleCacheConfigService(new ThrowingCacheProvider());
		try {
			svc.put('k', 'v');
			System.assert(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			System.assert(e.getMessage().contains('Unable to access Platform Cache partition'));
		}
	}

	@IsTest
	private static void getTestFailCacheAccess() {
		GoogleCacheConfigService svc = new GoogleCacheConfigService(new ThrowingCacheProvider());
		try {
			svc.get('k');
			System.assert(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			System.assert(e.getMessage().contains('Unable to access Platform Cache partition'));
		}
	}

	@IsTest
	private static void removeTestFailCacheAccess() {
		GoogleCacheConfigService svc = new GoogleCacheConfigService(new ThrowingCacheProvider());
		try {
			svc.remove('k');
			System.assert(false);
		} catch (GoogleCacheConfigService.GoogleCacheConfigException e) {
			System.assert(e.getMessage().contains('Unable to access Platform Cache partition'));
		}
	}
}
