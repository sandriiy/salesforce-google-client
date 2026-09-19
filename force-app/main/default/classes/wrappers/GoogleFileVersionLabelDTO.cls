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
 * One label applied to one version, with enough about that version to show which one it was and whether
 * it is still the current one.
 */
public class GoogleFileVersionLabelDTO {
	@AuraEnabled
	public Id id;
	@AuraEnabled
	public String name;
	@AuraEnabled
	public Integer confidence;
	@AuraEnabled
	public Datetime appliedDate;
	@AuraEnabled
	public Id versionId;
	@AuraEnabled
	public String versionName;
	@AuraEnabled
	public Boolean isLatestVersion;

	/**
	 * Builds the display shape from the label and the version it belongs to.
	 *
	 * @param versionLabel The stored label.
	 * @param localFileVersion The version it was applied to, or null when it is not loaded.
	 * @return The label ready for display.
	 */
	public static GoogleFileVersionLabelDTO of(GoogleFileVersionLabel__c versionLabel, GoogleFileVersion__c localFileVersion) {
		GoogleFileVersionLabelDTO dto = new GoogleFileVersionLabelDTO();
		dto.id = versionLabel.Id;
		dto.name = versionLabel.Name;
		dto.confidence = versionLabel.Confidence__c == null ? null : versionLabel.Confidence__c.intValue();
		dto.appliedDate = versionLabel.CreatedDate;
		dto.versionId = versionLabel.GoogleFileVersionId__c;
		dto.versionName = localFileVersion == null ? null : localFileVersion.Name;
		dto.isLatestVersion = localFileVersion != null && localFileVersion.IsLatestFile__c == true;
		return dto;
	}
}
