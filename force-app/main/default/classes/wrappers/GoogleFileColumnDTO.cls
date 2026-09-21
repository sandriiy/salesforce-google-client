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
 * One File Explorer column. A catalog column is known to the component already, while a custom one
 * carries the label and data type read from the field.
 */
public with sharing class GoogleFileColumnDTO {
	@AuraEnabled
	public String key;
	@AuraEnabled
	public Boolean isCustomField;
	@AuraEnabled
	public String label;
	@AuraEnabled
	public String dataType;

	public GoogleFileColumnDTO() {}
	/**
	 * Holds one column.
	 *
	 * @param key The catalog token or the field API name.
	 * @param isCustomField True when this is a field rather than a catalog column.
	 * @param label What the header shows, for a custom field.
	 * @param dataType How the value is rendered, for a custom field.
	 */
	public GoogleFileColumnDTO(String key, Boolean isCustomField, String label, String dataType) {
		this.key = key;
		this.isCustomField = isCustomField;
		this.label = label;
		this.dataType = dataType;
	}
}
