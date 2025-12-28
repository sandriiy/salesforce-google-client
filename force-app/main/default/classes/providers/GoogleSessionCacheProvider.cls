public with sharing class GoogleSessionCacheProvider implements IGoogleCacheProvider {
	private final Cache.SessionPartition partition;

	public GoogleSessionCacheProvider(String partitionName) {
		this.partition = Cache.Session.getPartition(partitionName);
	}

	public void put(String key, String value) {
		partition.put(key, value);
	}

	public Object get(String key) {
		return partition.get(key);
	}

	public void remove(String key) {
		partition.remove(key);
	}

	public Cache.SessionPartition getSessionPartition() {
		return partition;
	}

	public Cache.OrgPartition getOrgPartition() {
		return null;
	}
}