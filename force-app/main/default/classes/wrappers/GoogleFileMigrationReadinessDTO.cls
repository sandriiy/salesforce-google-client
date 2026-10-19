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
 * Whether the running user and the org are ready for a migration, and the facts the migration screen
 * states before anything is chosen. An empty list of blockers means ready.
 */
public with sharing class GoogleFileMigrationReadinessDTO {
	/**
	 * What stops a migration from starting, in words a user can act on. Empty means nothing does.
	 */
	@AuraEnabled
	public List<String> blockers = new List<String>();
	/**
	 * True when AI Analytics is on, which is when skipping it is a choice worth offering.
	 */
	@AuraEnabled
	public Boolean isIntelligenceEnabled = false;
	/**
	 * The Google Drive folder uploads land in before folder placement moves them.
	 */
	@AuraEnabled
	public String uploadFolderId;
	/**
	 * The largest Salesforce file the migration takes, in bytes.
	 */
	@AuraEnabled
	public Long maxFileSizeBytes;
}
