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
/**
 * The org cache, which every user in the org shares. This is where folder identity is remembered, since
 * the point is that another user's transaction can see it.
 */
public with sharing class GoogleOrgCacheProvider implements IGoogleCacheProvider {
	private final Cache.OrgPartition partition;

	/**
	 * Opens the named partition.
	 *
	 * @param partitionName The platform cache partition to use.
	 */
	public GoogleOrgCacheProvider(String partitionName) {
		this.partition = Cache.Org.getPartition(partitionName);
	}

	/**
	 * Stores a value for the whole org.
	 *
	 * @param key The key to store it under.
	 * @param value The value to store.
	 */
	public void put(String key, String value) {
		partition.put(key, value);
	}

	/**
	 * Reads a value back.
	 *
	 * @param key The key to read.
	 * @return The value, or null when nothing is there.
	 */
	public Object get(String key) {
		return partition.get(key);
	}

	/**
	 * Drops a value.
	 *
	 * @param key The key to clear.
	 */
	public void remove(String key) {
		partition.remove(key);
	}

	/**
	 * Always null here, since this provider is the org cache.
	 *
	 * @return Null.
	 */
	public Cache.SessionPartition getSessionPartition() {
		return null;
	}

	/**
	 * The partition itself, for handing to a library that wants it.
	 *
	 * @return The org partition.
	 */
	public Cache.OrgPartition getOrgPartition() {
		return partition;
	}
}