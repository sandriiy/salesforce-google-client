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
 * Inspects what goes to the AI provider and what comes back. Write your own and name it in the
 * configuration to replace the shipped rules with your own. Every prompt in this package passes through
 * a guard, so an implementation that lets everything through turns the protection off.
 */
public interface IGoogleAiPromptSafetyGuard {
	/**
	 * Wraps the administrator's prompt in whatever rules the model must not be talked out of.
	 *
	 * @param context The operation, the provider, the file and the prompt as configured.
	 * @return The system prompt that is actually sent.
	 */
	String wrapSystemPrompt(GoogleAiPromptContext context);
	/**
	 * Decides whether the request may go to the provider at all, and may hand back a cleaned up version of
	 * what the user typed instead of refusing.
	 *
	 * @param context The operation, the provider, the file and the user input.
	 * @return Allowed with an optional replacement input, or blocked with a reason for the user.
	 */
	GoogleAiPromptSafetyDecision inspectRequest(GoogleAiPromptContext context);
	/**
	 * Decides whether the answer may be shown, and may hand back a cleaned up version instead of refusing.
	 * It also runs over a stored summary before it is displayed, so tightening the rules covers what was
	 * written earlier.
	 *
	 * @param context The operation, the provider and the file.
	 * @param response What the model answered and why it stopped.
	 * @return Allowed with optional replacement text, or blocked with a reason for the user.
	 */
	GoogleAiResponseSafetyDecision inspectResponse(GoogleAiPromptContext context, GoogleAiResponseSnapshot response);
}
