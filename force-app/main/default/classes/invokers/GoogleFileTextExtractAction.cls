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
 * The Flow face of GoogleLocalFileVersionService.extractText(). It reads a file as plain text so the rest
 * of the flow can search it, put it in a prompt or copy part of it onto a record.
 */
public with sharing class GoogleFileTextExtractAction {
	/**
	 * What the flow supplies. Name either a version or a file, and a file takes its current version.
	 */
	public class Input {
		@InvocableVariable(label='Google File Version ID' description='The exact file version to read. Leave blank to read the latest version of the Google File')
		public Id googleFileVersionId;
		@InvocableVariable(label='Google File ID' description='The Google File whose latest version is read when no version is given')
		public Id googleFileId;
		@InvocableVariable(label='Maximum Characters' description='Cuts the text after this many characters. Leave blank to return everything')
		public Integer maxCharacters;
	}

	/**
	 * The text and how much of it there is, with a flag saying whether it stopped at the requested maximum.
	 */
	public class Output {
		@InvocableVariable(label='Text')
		public String text;
		@InvocableVariable(label='Character Count')
		public Integer characterCount;
		@InvocableVariable(label='Was Cut Short' description='True when the text was cut at Maximum Characters')
		public Boolean isTruncated;
		@InvocableVariable(label='Google File Version ID')
		public Id googleFileVersionId;
		@InvocableVariable(label='File Name')
		public String fileName;
	}

	/**
	 * Reads every file the flow supplied, one output per input and in the same order. A file whose
	 * preview copy is still being prepared faults with a message saying so, since that is different from
	 * a file with nothing in it.
	 *
	 * @param inputs One request per file.
	 * @return One result per request, in the same order.
	 */
	@InvocableMethod(
		label='Extract File Content as Text from Google Drive'
		description='Reads the content of a Google Client file as plain text, so it can be used in formulas, prompts or messages later in the flow'
		category='Google Client'
		iconName='slds:standard:text_template'
		callout=true
	)
	public static List<Output> extractText(List<Input> inputs) {
		List<Output> outputs = new List<Output>();
		if (inputs == null || inputs.isEmpty()) return outputs;

		List<GoogleFileTextExtractRequestDTO> requests = new List<GoogleFileTextExtractRequestDTO>();
		for (Input input : inputs) {
			requests.add(toRequest(input));
		}

		for (GoogleFileTextExtractResultDTO result : new GoogleLocalFileVersionService().extractText(requests)) {
			outputs.add(toOutput(result));
		}

		return outputs;
	}

	private static GoogleFileTextExtractRequestDTO toRequest(Input input) {
		GoogleFileTextExtractRequestDTO request = new GoogleFileTextExtractRequestDTO();
		if (input == null) return request;

		request.googleFileVersionId = input.googleFileVersionId;
		request.googleFileId = input.googleFileId;
		request.maxCharacters = input.maxCharacters;
		return request;
	}

	private static Output toOutput(GoogleFileTextExtractResultDTO result) {
		Output output = new Output();
		output.text = result.text;
		output.characterCount = result.characterCount;
		output.isTruncated = result.isTruncated == true;
		output.googleFileVersionId = result.googleFileVersionId;
		output.fileName = result.fileName;
		return output;
	}
}
