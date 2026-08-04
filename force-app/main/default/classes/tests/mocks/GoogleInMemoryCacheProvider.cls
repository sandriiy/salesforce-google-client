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
public class GoogleInMemoryCacheProvider implements IGoogleCacheProvider {
	private final Map<String, String> entriesByKey = new Map<String, String>();
	private final Boolean isUnavailable;

	public GoogleInMemoryCacheProvider() {
		this(false);
	}

	public GoogleInMemoryCacheProvider(Boolean isUnavailable) {
		this.isUnavailable = isUnavailable == true;
	}

	public void put(String key, String value) {
		if (isUnavailable) throw new CalloutException('Platform Cache is not available');
		entriesByKey.put(key, value);
	}

	public Object get(String key) {
		if (isUnavailable) throw new CalloutException('Platform Cache is not available');
		return entriesByKey.get(key);
	}

	public void remove(String key) {
		if (isUnavailable) throw new CalloutException('Platform Cache is not available');
		entriesByKey.remove(key);
	}

	public Cache.SessionPartition getSessionPartition() {
		return null;
	}

	public Cache.OrgPartition getOrgPartition() {
		return null;
	}
}
