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
 * Reads the GoogleClientConfig__mdt record with a real SOQL query instead of the custom metadata
 * cache, because the cache cuts every Long Text Area at 255 characters and silently shortens the
 * prompts and the label definitions. Go through GoogleMetadataConfigService rather than calling
 * this directly; it loads the record once per transaction.
 */
public inherited sharing class GoogleClientConfigSelector extends GSOQL implements GSOQL.Selector {
	@TestVisible
	private static final String MOCK_ID = 'GoogleClientConfigSelector';

	/**
	 * Starts a new query over GoogleClientConfig__mdt in system mode.
	 *
	 * @return A fresh selector to chain field and filter calls onto.
	 */
	public static GoogleClientConfigSelector query() {
		return new GoogleClientConfigSelector();
	}

	public GoogleClientConfigSelector() {
		super(GoogleClientConfig__mdt.SObjectType);
		systemMode();
		withoutSharing();
		mockId(MOCK_ID);
	}

	/**
	 * Selects every field on the object, so a config field added by an upgrade is read without
	 * touching this class.
	 *
	 * @return This same instance, so the call chains.
	 */
	public GoogleClientConfigSelector withAllFields() {
		with(Schema.SObjectType.GoogleClientConfig__mdt.fields.getMap().values());
		return this;
	}
}
