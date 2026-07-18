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
public with sharing class GoogleDriveCapacityErrorClassifier {
    private static final Integer CAPACITY_HTTP_CODE = 403;

    private static final Set<String> CAPACITY_REASONS = new Set<String>{
        'teamDriveFileLimitExceeded',
        'storageQuotaExceeded',
        'numChildrenInNonRootLimitExceeded'
    };

    public static Boolean isCapacityExhaustedError(Exception ex) {
        String message = extractMessage(ex);
        if (String.isBlank(message)) return false;

        DriveErrorBody body = parseErrorBody(message);
        if (body != null && body.error != null && body.error.code == CAPACITY_HTTP_CODE) {
            for (DriveErrorDetail detail : nonNullDetails(body)) {
                if (CAPACITY_REASONS.contains(detail.reason)) return true;
            }
        }

        return matchesBySubstring(message);
    }

    public static String extractReason(Exception ex) {
        String message = extractMessage(ex);
        if (String.isBlank(message)) return null;

        DriveErrorBody body = parseErrorBody(message);
        if (body == null) return null;

        for (DriveErrorDetail detail : nonNullDetails(body)) {
            if (String.isNotBlank(detail.reason)) return detail.reason;
        }

        return null;
    }

    private static String extractMessage(Exception ex) {
        return ex == null ? null : ex.getMessage();
    }

    private static DriveErrorBody parseErrorBody(String message) {
        try {
            return (DriveErrorBody) JSON.deserialize(message, DriveErrorBody.class);
        } catch (Exception parseEx) {
            return null;
        }
    }

    private static List<DriveErrorDetail> nonNullDetails(DriveErrorBody body) {
        if (body == null || body.error == null || body.error.errors == null) return new List<DriveErrorDetail>();

        List<DriveErrorDetail> result = new List<DriveErrorDetail>();
        for (DriveErrorDetail detail : body.error.errors) {
            if (detail != null) result.add(detail);
        }
        return result;
    }

    private static Boolean matchesBySubstring(String message) {
        String normalized = message.replaceAll('\\s+', '');
        if (!normalized.contains('"code":' + CAPACITY_HTTP_CODE)) return false;

        for (String reason : CAPACITY_REASONS) {
            if (normalized.contains('"reason":"' + reason + '"')) return true;
        }

        return false;
    }

    public class DriveErrorBody {
        public DriveErrorEnvelope error;
    }

    public class DriveErrorEnvelope {
        public Integer code;
        public String message;
        public List<DriveErrorDetail> errors;
    }

    public class DriveErrorDetail {
        public String domain;
        public String reason;
        public String message;
        public String locationType;
        public String location;
    }
}
