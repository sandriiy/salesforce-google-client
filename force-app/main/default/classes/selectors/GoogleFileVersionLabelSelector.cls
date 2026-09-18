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
public inherited sharing class GoogleFileVersionLabelSelector extends GSOQL implements GSOQL.Selector {
	@TestVisible
	private static final String MOCK_ID = 'GoogleFileVersionLabelSelector';

	public static final List<SObjectField> BASE_FIELDS = new List<SObjectField>{
		GoogleFileVersionLabel__c.Id,
		GoogleFileVersionLabel__c.Name,
		GoogleFileVersionLabel__c.GoogleFileVersionId__c,
		GoogleFileVersionLabel__c.GoogleDriveLabelId__c,
		GoogleFileVersionLabel__c.Confidence__c,
		GoogleFileVersionLabel__c.CreatedDate
	};

	public static GoogleFileVersionLabelSelector query() {
		return new GoogleFileVersionLabelSelector();
	}

	public GoogleFileVersionLabelSelector() {
		super(GoogleFileVersionLabel__c.SObjectType);
		systemMode();
		withoutSharing();
		mockId(MOCK_ID);
	}

	public GoogleFileVersionLabelSelector byParentId(Id versionId) {
		whereAre(Filter.with(GoogleFileVersionLabel__c.GoogleFileVersionId__c).equal(versionId));
		return this;
	}

	public GoogleFileVersionLabelSelector byParentIds(Set<Id> versionIds) {
		whereAre(Filter.with(GoogleFileVersionLabel__c.GoogleFileVersionId__c).isIn(versionIds));
		return this;
	}

	public GoogleFileVersionLabelSelector withBaseFields() {
		with(BASE_FIELDS);
		return this;
	}

	public GoogleFileVersionLabelSelector orderByCreatedAsc() {
		orderBy(GoogleFileVersionLabel__c.CreatedDate);
		return this;
	}

	public GoogleFileVersionLabelSelector orderByCreatedDesc() {
		orderBy(GoogleFileVersionLabel__c.CreatedDate).sortDesc();
		return this;
	}

	public GoogleFileVersionLabelSelector limitTo(Integer n) {
		setLimit(n);
		return this;
	}
}
