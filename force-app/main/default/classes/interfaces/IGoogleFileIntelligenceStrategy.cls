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
 * What an AI provider has to do for this package. Implement it to send summaries and questions somewhere
 * other than Gemini or Agent Platform. Nothing is ever added to this interface, since that would break
 * every implementation an org already has, which is why labeling lives in its own one.
 */
public interface IGoogleFileIntelligenceStrategy {
    /**
     * Writes the short description of a file.
     *
     * @param localGoogleFileVersionId The version to summarize.
     * @return The summary, or why there is none.
     */
    GoogleFileAnalysisResultDTO summarize(Id localGoogleFileVersionId);
	/**
	 * Answers a question about a file from its content.
	 *
	 * @param localGoogleFileVersionId The version being asked about.
	 * @param question What the user asked.
	 * @return The answer, or why there is none.
	 */
	GoogleFileAnalysisResultDTO answerQuestion(Id localGoogleFileVersionId, String question);
	/**
	 * Checks that the provider answers at all, which is what the setup screen calls before letting an
	 * administrator turn analysis on.
	 *
	 * @return True when the provider responded.
	 */
	Boolean validate();
}