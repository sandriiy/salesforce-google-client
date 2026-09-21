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
 * A place to keep values between transactions. Implement it to change where that is, or to supply an in
 * memory one in tests so platform cache does not leak between methods.
 */
public interface IGoogleCacheProvider {
	/**
	 * Stores a value.
	 *
	 * @param key The key to store it under.
	 * @param value The value to store.
	 */
	void put(String key, String value);
	/**
	 * Reads a value back.
	 *
	 * @param key The key to read.
	 * @return The value, or null when nothing is there.
	 */
	Object get(String key);
	/**
	 * Drops a value.
	 *
	 * @param key The key to clear.
	 */
	void remove(String key);
	/**
	 * The session partition, for handing to a library that wants the partition itself.
	 *
	 * @return The partition, or null when this provider is not a session one.
	 */
	Cache.SessionPartition getSessionPartition();
	/**
	 * The org partition, for handing to a library that wants the partition itself.
	 *
	 * @return The partition, or null when this provider is not an org one.
	 */
	Cache.OrgPartition getOrgPartition();
}