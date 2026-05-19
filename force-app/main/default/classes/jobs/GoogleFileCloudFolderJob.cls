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
public with sharing class GoogleFileCloudFolderJob extends GQueueableJob.AllowsCallouts {
    public class GoogleFileCloudFolderJobException extends Exception {}

    @TestVisible
    private static Boolean skipExecution = false;

    private final List<GoogleFileRelocationRequestDTO> requests;

    public GoogleFileCloudFolderJob(GoogleFileRelocationRequestDTO request) {
        this.requests = request == null
            ? new List<GoogleFileRelocationRequestDTO>()
            : new List<GoogleFileRelocationRequestDTO>{ request };
    }

    public GoogleFileCloudFolderJob(List<GoogleFileRelocationRequestDTO> requests) {
        this.requests = requests == null
            ? new List<GoogleFileRelocationRequestDTO>()
            : new List<GoogleFileRelocationRequestDTO>(requests);
    }

    public override void work() {
        if (skipExecution) return;
        if (this.requests.isEmpty()) return;

        IGoogleUnitOfWork uow = new GoogleCloudUnitOfWork(new List<SObjectType>{
            GoogleFile__c.SObjectType,
            GoogleFileVersion__c.SObjectType,
            GoogleFileLink__c.SObjectType
        });

        try {
            for (GoogleFileRelocationRequestDTO request : this.requests) {
                if (request == null) continue;

                Logger.info(
                    'Folder Placement Job --> FileId=' + String.valueOf(request.localGoogleFileId) +
                    ', VersionId=' + String.valueOf(request.localGoogleFileVersionId) +
                    ', LinkId=' + String.valueOf(request.linkLocalGoogleFileId)
                ).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

                new GoogleFileStoreInFolderCommand(uow).placeFile(request);
            }

            uow.commitWork(true);
        } catch (Exception ex) {
            Logger.error('Folder Placement Job Failed --> ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
            Logger.saveLog();
            throw new GoogleFileCloudFolderJobException('Unable to place the file into a folder. Please try again or contact your system administrator');
        }
    }
}