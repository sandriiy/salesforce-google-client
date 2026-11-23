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
 * The Flow face of GoogleLocalFileService.resolveAccessLevels(). A flow that runs in system context and
 * shows or changes a Google File asks this first, so it applies the same access rules as the Google
 * Client components instead of trusting what its caller passed in.
 */
public with sharing class GoogleFileAccessCheckAction {
	@TestVisible
	private static GoogleLocalFileService fileServiceOverride;

	/**
	 * What the flow supplies: the Google File, or one of its versions, to check for the running user.
	 */
	public class Input {
		@InvocableVariable(label='Google File or Version ID' description='The Google File to check, or one of its versions, which is judged by its file' required=true)
		public Id fileOrVersionId;
	}

	/**
	 * The running user's access, as a level and as two flags a decision can test directly.
	 */
	public class Output {
		@InvocableVariable(label='Access Level' description='"View" or "Edit", or blank when the user cannot open the file')
		public String accessLevel;
		@InvocableVariable(label='Can View' description='True when the user can open the file')
		public Boolean canView;
		@InvocableVariable(label='Can Edit' description='True when the user can change the file')
		public Boolean canEdit;
	}

	/**
	 * Checks every file the flow supplied for the user running it, one output per input and in the same
	 * order. A file or version that does not exist reads the same as one the user cannot open.
	 *
	 * @param inputs One request per file or version.
	 * @return One result per request, in the same order.
	 */
	@InvocableMethod(
		label='Check Access to a Google File'
		description='Tells whether the user running the flow can open or change a Google Client file, by the same rules as the Google Client components'
		category='Google Client'
		iconName='slds:standard:lock'
	)
	public static List<Output> checkAccess(List<Input> inputs) {
		List<Output> outputs = new List<Output>();
		if (inputs == null || inputs.isEmpty()) return outputs;

		List<Id> requestedIds = new List<Id>();
		for (Input input : inputs) {
			requestedIds.add(input?.fileOrVersionId);
		}

		Map<Id, String> accessLevelByRequestedId = resolveFileService().resolveAccessLevels(requestedIds);
		for (Id requestedId : requestedIds) {
			outputs.add(toOutput(requestedId == null ? null : accessLevelByRequestedId.get(requestedId)));
		}

		return outputs;
	}

	private static GoogleLocalFileService resolveFileService() {
		return fileServiceOverride != null ? fileServiceOverride : new GoogleLocalFileService();
	}

	private static Output toOutput(String accessLevel) {
		Output output = new Output();
		output.accessLevel = accessLevel;
		output.canView = accessLevel != null;
		output.canEdit = accessLevel == 'Edit';
		return output;
	}
}
