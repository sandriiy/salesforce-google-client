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
 * What a migration run was asked to do: which Salesforce files, narrowed by an optional condition and by
 * the objects they are attached to, and whether to analyze them. It travels inside the background job from
 * step to step, so it holds plain values only.
 */
public class GoogleFileMigrationRequestDTO {
	/**
	 * A WHERE condition on ContentVersion, without the keyword. Blank means every file within scope.
	 */
	public String condition;
	/**
	 * The API names of the objects a file must be attached to. Empty means any record.
	 */
	public List<String> objectNames = new List<String>();
	/**
	 * True to copy the files without an AI summary or label.
	 */
	public Boolean skipIntelligence = false;
}
