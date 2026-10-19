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
 * What checking a migration condition answers: how many Salesforce files it selects within scope, a first
 * few of them by name, and the pace a run would move at, so the screen can say how long it might take.
 */
public with sharing class GoogleFileMigrationPreviewDTO {
	@AuraEnabled
	public Integer totalFiles = 0;
	@AuraEnabled
	public List<SampleFile> sampleFiles = new List<SampleFile>();
	@AuraEnabled
	public Integer filesPerStep;
	@AuraEnabled
	public Integer secondsPerStep;
	@AuraEnabled
	public Long maxFileSizeBytes;

	/**
	 * One of the first files the condition selects, enough to recognise it in a list.
	 */
	public class SampleFile {
		@AuraEnabled
		public Id contentDocumentId;
		@AuraEnabled
		public String name;
		@AuraEnabled
		public String fileExtension;
		@AuraEnabled
		public Long size;
		@AuraEnabled
		public String ownerName;
		@AuraEnabled
		public Datetime createdDate;
	}
}
