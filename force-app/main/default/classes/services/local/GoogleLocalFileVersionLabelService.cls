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
public without sharing class GoogleLocalFileVersionLabelService {
	public class GoogleLocalFileVersionLabelServiceException extends Exception {}

	private static final String LABEL_NAME_SEPARATOR = '; ';
	private static final Integer MAX_LABEL_NAMES_LENGTH = 255;
	private static final String FILE_ACCESS_DENIED_MESSAGE = 'You don’t have access to view this file. Please verify your permissions and try again';
	private static final String LABEL_NAMES_UPDATE_FAILED_MESSAGE = 'Unable to update the file labels. Please try again or contact your system administrator';

	private final IGoogleUnitOfWork uow;

	public GoogleLocalFileVersionLabelService() {
		this(null);
	}

	public GoogleLocalFileVersionLabelService(IGoogleUnitOfWork injectedUow) {
		this.uow = injectedUow != null ? injectedUow : new GoogleCloudUnitOfWork(GoogleCloudConstants.DEFAULT_WRITE_ORDER);
	}

	public void syncLabelNames(List<GoogleFileVersionLabel__c> newLabels, List<GoogleFileVersionLabel__c> oldLabels) {
		Set<Id> versionIds = collectVersionIds(newLabels, oldLabels);
		if (versionIds.isEmpty()) return;

		Set<Id> existingVersionIds = new Map<Id, GoogleFileVersion__c>(
			(List<GoogleFileVersion__c>) GoogleFileVersionSelector.query()
				.withBaseFields()
				.byIds(versionIds)
				.toList()
		).keySet();
		if (existingVersionIds.isEmpty()) return;

		Map<Id, List<String>> labelNamesByVersionId = retrieveLabelNamesByVersionId(existingVersionIds);
		for (Id versionId : existingVersionIds) {
			uow.registerDirty(new GoogleFileVersion__c(
				Id = versionId,
				AiLabels__c = joinLabelNames(labelNamesByVersionId.get(versionId))
			));
		}

		try {
			uow.commitWork(true);
		} catch (Exception ex) {
			Logger.error('Google File Version label names update failed (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileVersionLabelServiceException(LABEL_NAMES_UPDATE_FAILED_MESSAGE);
		}
	}

	public List<GoogleFileVersionLabelDTO> retrieveLabelsForFile(Id localFileRecordId) {
		List<GoogleFileVersionLabelDTO> labels = new List<GoogleFileVersionLabelDTO>();
		if (localFileRecordId == null) return labels;

		requireFileAccess(localFileRecordId);

		Map<Id, GoogleFileVersion__c> versionsById = new Map<Id, GoogleFileVersion__c>(
			(List<GoogleFileVersion__c>) GoogleFileVersionSelector.query()
				.withBaseFields()
				.byParentId(localFileRecordId)
				.toList()
		);

		if (versionsById.isEmpty()) return labels;

		List<GoogleFileVersionLabel__c> versionLabels = (List<GoogleFileVersionLabel__c>) GoogleFileVersionLabelSelector.query()
			.withBaseFields()
			.byParentIds(versionsById.keySet())
			.orderByCreatedDesc()
			.toList();

		for (GoogleFileVersionLabel__c versionLabel : versionLabels) {
			labels.add(GoogleFileVersionLabelDTO.of(versionLabel, versionsById.get(versionLabel.GoogleFileVersionId__c)));
		}

		return labels;
	}

	private void requireFileAccess(Id localFileRecordId) {
		List<GoogleFile__c> accessibleFiles = new GoogleFileAccessCheckCommand()
			.forFile(localFileRecordId)
			.forUser(UserInfo.getUserId())
			.strip();

		if (accessibleFiles.isEmpty()) {
			throw new GoogleLocalFileVersionLabelServiceException(FILE_ACCESS_DENIED_MESSAGE);
		}
	}

	private Set<Id> collectVersionIds(List<GoogleFileVersionLabel__c> newLabels, List<GoogleFileVersionLabel__c> oldLabels) {
		Set<Id> versionIds = new Set<Id>();
		for (List<GoogleFileVersionLabel__c> versionLabels : new List<List<GoogleFileVersionLabel__c>>{ newLabels, oldLabels }) {
			if (versionLabels == null) continue;
			for (GoogleFileVersionLabel__c versionLabel : versionLabels) {
				if (versionLabel != null && versionLabel.GoogleFileVersionId__c != null) {
					versionIds.add(versionLabel.GoogleFileVersionId__c);
				}
			}
		}

		return versionIds;
	}

	public Map<Id, List<String>> retrieveLabelNamesByVersionId(Set<Id> versionIds) {
		Map<Id, List<String>> labelNamesByVersionId = new Map<Id, List<String>>();
		List<GoogleFileVersionLabel__c> versionLabels = (List<GoogleFileVersionLabel__c>) GoogleFileVersionLabelSelector.query()
			.withBaseFields()
			.byParentIds(versionIds)
			.orderByCreatedAsc()
			.toList();

		for (GoogleFileVersionLabel__c versionLabel : versionLabels) {
			if (!labelNamesByVersionId.containsKey(versionLabel.GoogleFileVersionId__c)) {
				labelNamesByVersionId.put(versionLabel.GoogleFileVersionId__c, new List<String>());
			}
			
			labelNamesByVersionId.get(versionLabel.GoogleFileVersionId__c).add(versionLabel.Name);
		}

		return labelNamesByVersionId;
	}

	private String joinLabelNames(List<String> labelNames) {
		if (labelNames == null || labelNames.isEmpty()) return null;

		String joined = '';
		for (String labelName : labelNames) {
			if (String.isBlank(labelName)) continue;

			String candidate = joined.length() == 0 ? labelName : joined + LABEL_NAME_SEPARATOR + labelName;
			if (candidate.length() > MAX_LABEL_NAMES_LENGTH) {
				Logger.warn('Google File Version label names exceed the field length; later labels are left out of the searchable list --> Dropped=' + labelName).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
				Logger.saveLog();
				break;
			}
			joined = candidate;
		}

		return joined.length() == 0 ? null : joined;
	}
}
