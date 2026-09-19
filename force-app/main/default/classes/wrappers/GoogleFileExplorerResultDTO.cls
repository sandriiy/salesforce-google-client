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
 * One page of File Explorer. nextCursor is what the next page continues from, and isPrivileged only
 * decides whether the All Files view is offered, since everybody is paged the same way.
 */
public with sharing class GoogleFileExplorerResultDTO {
	@AuraEnabled
	public List<GoogleFile__c> files;
	@AuraEnabled
	public Boolean hasMore;
	@AuraEnabled
	public Boolean isPrivileged;
	@AuraEnabled
	public String nextCursor;

	public GoogleFileExplorerResultDTO() {}
	/**
	 * Holds one page.
	 *
	 * @param files The files on this page, in order.
	 * @param hasMore Whether another page follows.
	 * @param isPrivileged Whether the user holds View All or Edit All.
	 * @param nextCursor Where the next page continues, or null at the end.
	 */
	public GoogleFileExplorerResultDTO(List<GoogleFile__c> files, Boolean hasMore, Boolean isPrivileged, String nextCursor) {
		this.files = files;
		this.hasMore = hasMore;
		this.isPrivileged = isPrivileged;
		this.nextCursor = nextCursor;
	}
}
