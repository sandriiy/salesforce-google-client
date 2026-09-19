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
 * One file waiting to be moved into its folder, as the folder job works through them. The user is carried
 * along because the job runs later and cannot ask who uploaded the file.
 */
public class GoogleFileRelocationRequestDTO {
    public Id initiatorUserId;
	public Id localGoogleFileId;
	public Id localGoogleFileVersionId;
	public Id linkLocalGoogleFileId;

	/**
	 * Holds one placement.
	 *
	 * @param initiatorUserId The user who uploaded the file.
	 * @param localGoogleFileId The file being placed.
	 * @param localGoogleFileVersionId The version whose Drive copy moves.
	 * @param linkLocalGoogleFileId The link the destination record comes from.
	 */
	public GoogleFileRelocationRequestDTO(Id initiatorUserId, Id localGoogleFileId, Id localGoogleFileVersionId, Id linkLocalGoogleFileId) {
		this.initiatorUserId = initiatorUserId;
		this.localGoogleFileId = localGoogleFileId;
		this.localGoogleFileVersionId = localGoogleFileVersionId;
		this.linkLocalGoogleFileId = linkLocalGoogleFileId;
	}
}