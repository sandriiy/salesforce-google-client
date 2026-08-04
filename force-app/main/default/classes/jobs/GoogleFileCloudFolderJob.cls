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

    private static final Integer MAX_PLACEMENT_ATTEMPTS = 3;
    private static final Integer DEFERRED_RETRY_DELAY_MINUTES = 1;

    @TestVisible
    private static Boolean skipExecution = false;

    private final List<GoogleFileRelocationRequestDTO> requests;
    private final Integer placementAttempt;

    public GoogleFileCloudFolderJob(GoogleFileRelocationRequestDTO request) {
        this(
            request == null
                ? new List<GoogleFileRelocationRequestDTO>()
                : new List<GoogleFileRelocationRequestDTO>{ request },
            1
        );
    }

    public GoogleFileCloudFolderJob(List<GoogleFileRelocationRequestDTO> requests) {
        this(requests, 1);
    }

    public GoogleFileCloudFolderJob(List<GoogleFileRelocationRequestDTO> requests, Integer placementAttempt) {
        this.requests = requests == null
            ? new List<GoogleFileRelocationRequestDTO>()
            : new List<GoogleFileRelocationRequestDTO>(requests);
        this.placementAttempt = placementAttempt == null || placementAttempt < 1 ? 1 : placementAttempt;
    }

    public override void work() {
        if (skipExecution) return;
        if (this.requests.isEmpty()) return;

        IGoogleUnitOfWork uow = new GoogleCloudUnitOfWork(GoogleCloudConstants.DEFAULT_WRITE_ORDER);

        List<GoogleFileRelocationRequestDTO> deferredRequests = new List<GoogleFileRelocationRequestDTO>();

        try {
            GoogleFileStoreInFolderCommand storeInFolderCommand = new GoogleFileStoreInFolderCommand(uow);
            if (this.placementAttempt >= MAX_PLACEMENT_ATTEMPTS) {
                storeInFolderCommand.ignorePendingFolderClaims();
            }

            for (GoogleFileRelocationRequestDTO request : this.requests) {
                if (request == null) continue;

                Logger.info(
                    'Folder Placement Job --> FileId=' + String.valueOf(request.localGoogleFileId) +
                    ', VersionId=' + String.valueOf(request.localGoogleFileVersionId) +
                    ', LinkId=' + String.valueOf(request.linkLocalGoogleFileId) +
                    ', Attempt=' + String.valueOf(this.placementAttempt)
                ).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

                if (storeInFolderCommand.placeFile(request) != true) {
                    deferredRequests.add(request);
                }
            }

            uow.commitWork(true);
        } catch (Exception ex) {
            Logger.error('Folder Placement Job Failed --> ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
            Logger.saveLog();
            throw new GoogleFileCloudFolderJobException('Unable to place the file into a folder. Please try again or contact your system administrator');
        }

        enqueueDeferredRequests(deferredRequests);
    }

    private void enqueueDeferredRequests(List<GoogleFileRelocationRequestDTO> deferredRequests) {
        if (deferredRequests.isEmpty()) return;

        if (this.placementAttempt >= MAX_PLACEMENT_ATTEMPTS) {
            Logger.error(
                'Folder Placement Job Failed --> Deferred requests exhausted their attempts' +
                ', DeferredRequests=' + String.valueOf(deferredRequests.size())
            ).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
            Logger.saveLog();
            return;
        }

        Logger.info(
            'Folder Placement Job --> Rescheduling deferred requests' +
            ', DeferredRequests=' + String.valueOf(deferredRequests.size()) +
            ', NextAttempt=' + String.valueOf(this.placementAttempt + 1)
        ).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

        GAsync.queueable()
            .chain(new GoogleFileCloudFolderJob(deferredRequests, this.placementAttempt + 1))
            .deepClone()
            .delay(DEFERRED_RETRY_DELAY_MINUTES)
            .enqueue();
    }
}