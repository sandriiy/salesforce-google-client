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
 * One label an administrator described, as stored in the configuration. The description is what the model
 * compares a document against, so it is worth writing properly. Label field values are not supported yet.
 */
public class GoogleAiLabelDefinitionDTO {
	@AuraEnabled
	public String name;
	@AuraEnabled
	public String labelId;
	@AuraEnabled
	public String description;

	/**
	 * Whether this definition can be used at all. An incomplete one is dropped rather than sent, so a half
	 * filled row in the editor never breaks an upload.
	 *
	 * @return True when the name, the Drive label Id and the description are all there.
	 */
	public Boolean isComplete() {
		return String.isNotBlank(name) && String.isNotBlank(labelId) && String.isNotBlank(description);
	}
}
