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
 * Moves newly uploaded files out of the upload folder and into the folder their record or user owns. A
 * placement that could not settle, because another transaction was creating the same folder, is
 * rescheduled a minute later and forced through on the last of three attempts, so a file is never left
 * in the root folder because two uploads raced. A file is started only when the transaction still has
 * room for its worst case; the files left continue straight away in a follow-up job, so a placement step
 * such as renaming a folder is never skipped for lack of time. The log is saved only by a run that
 * recorded an error.
 */
public without sharing class GoogleFileCloudFolderJob extends GQueueableJob.AllowsCallouts {
    public class GoogleFileCloudFolderJobException extends Exception {}

    private static final Integer MAX_PLACEMENT_ATTEMPTS = 3;
    private static final Integer DEFERRED_RETRY_DELAY_MINUTES = 1;
    private static final Integer FOLLOW_UP_PRIORITY = 1;
    private static final Integer MAX_CALLOUTS_PER_PLACEMENT = 10;
    private static final Integer MIN_PLACEMENT_WINDOW_MILLIS = 20000;

    @TestVisible
    private static Boolean skipExecution = false;
    @TestVisible
    private static Integer calloutsLeftOverride;

    private final List<GoogleFileRelocationRequestDTO> requests;
    private final Integer placementAttempt;

    /**
     * Builds the job for one file.
     *
     * @param request The version to place and the record it belongs to.
     */
    public GoogleFileCloudFolderJob(GoogleFileRelocationRequestDTO request) {
        this(
            request == null
                ? new List<GoogleFileRelocationRequestDTO>()
                : new List<GoogleFileRelocationRequestDTO>{ request },
            1
        );
    }

    /**
     * Builds the job for several files.
     *
     * @param requests The versions to place.
     */
    public GoogleFileCloudFolderJob(List<GoogleFileRelocationRequestDTO> requests) {
        this(requests, 1);
    }

    /**
     * Builds the job for a later attempt, which is how it reschedules itself.
     *
     * @param requests The versions still to place.
     * @param placementAttempt Which attempt this is, counting from one.
     */
    public GoogleFileCloudFolderJob(List<GoogleFileRelocationRequestDTO> requests, Integer placementAttempt) {
        this.requests = requests == null
            ? new List<GoogleFileRelocationRequestDTO>()
            : new List<GoogleFileRelocationRequestDTO>(requests);
        this.placementAttempt = placementAttempt == null || placementAttempt < 1 ? 1 : placementAttempt;
    }

    /**
     * Places the files it has room for, commits the new folder Ids together, hands the rest to a follow-up
     * job and reschedules whatever has to wait for another transaction. The first file always runs, so a
     * job always moves forward.
     */
    public override void work() {
        if (skipExecution) return;
        if (this.requests.isEmpty()) return;

        GoogleCalloutTimeResolver calloutClock = new GoogleCalloutTimeResolver();
        calloutClock.startClock();
        IGoogleUnitOfWork uow = new GoogleCloudUnitOfWork(GoogleCloudConstants.DEFAULT_WRITE_ORDER);

        List<GoogleFileRelocationRequestDTO> deferredRequests = new List<GoogleFileRelocationRequestDTO>();
        List<GoogleFileRelocationRequestDTO> handedOnRequests = new List<GoogleFileRelocationRequestDTO>();
        Boolean hasRecordedErrors = false;

        try {
            GoogleFileStoreInFolderCommand storeInFolderCommand = new GoogleFileStoreInFolderCommand(uow);
            if (this.placementAttempt >= MAX_PLACEMENT_ATTEMPTS) {
                storeInFolderCommand.ignorePendingFolderClaims();
            }

            Boolean hasStartedPlacement = false;
            for (GoogleFileRelocationRequestDTO request : this.requests) {
                if (request == null) continue;

                if (hasStartedPlacement && !hasRoomForPlacement(calloutClock)) {
                    handedOnRequests.add(request);
                    continue;
                }

                hasStartedPlacement = true;
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
            hasRecordedErrors = storeInFolderCommand.hasRecordedErrors();
        } catch (Exception ex) {
            Logger.error('Folder Placement Job Failed --> ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
            Logger.saveLog();
            throw new GoogleFileCloudFolderJobException('Unable to place the file into a folder. Please try again or contact your system administrator');
        }

        chainFollowUp(handedOnRequests);
        enqueueDeferredRequests(deferredRequests);

        if (hasRecordedErrors) {
            Logger.saveLog();
        }
    }

    private Boolean hasRoomForPlacement(GoogleCalloutTimeResolver calloutClock) {
        Integer calloutsLeft = calloutsLeftOverride != null
            ? calloutsLeftOverride
            : Limits.getLimitCallouts() - Limits.getCallouts();

        return calloutsLeft >= MAX_CALLOUTS_PER_PLACEMENT
            && calloutClock.resolveRequestTimeoutMillis() >= MIN_PLACEMENT_WINDOW_MILLIS;
    }

    private void chainFollowUp(List<GoogleFileRelocationRequestDTO> handedOnRequests) {
        if (handedOnRequests.isEmpty()) return;

        Logger.info(
            'Folder Placement Job --> Continuing in a follow-up job' +
            ', Requests=' + String.valueOf(handedOnRequests.size()) +
            ', Attempt=' + String.valueOf(this.placementAttempt)
        ).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

        GAsync.queueable()
            .chain(new GoogleFileCloudFolderJob(handedOnRequests, this.placementAttempt))
            .deepClone()
            .priority(FOLLOW_UP_PRIORITY)
            .enqueue();
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