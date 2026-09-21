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
 * The shipped answer to where uploads go, which is the folder or folders configured in Google Client.
 * Swap in your own implementation of IGoogleTargetFolderResolver to decide that per user or per record.
 */
public with sharing class GoogleMetadataTargetFolderResolver implements IGoogleTargetFolderResolver {
    private final GoogleMetadataConfigService config;

    /**
     * Builds the resolver on the configuration it reads.
     *
     * @param config The configuration holding the upload folders.
     */
    public GoogleMetadataTargetFolderResolver(GoogleMetadataConfigService config) {
        this.config = config;
    }

    /**
     * The single folder the folder structure is built under.
     *
     * @return A list holding the primary upload folder.
     */
    public List<String> resolveUploadFolderId() {
        return new List<String>{config.getDefaultUploadFolderId()};
    }

    /**
     * Every folder an upload may go to, in the order they should be tried when one is full.
     *
     * @return The upload folders in priority order.
     */
    public List<String> resolveUploadFolderCandidates() {
        return config.getAllUploadFolderIds();
    }
}