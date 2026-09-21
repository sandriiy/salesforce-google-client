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
 * The Flow face of withdrawing a public link, which is what the shipped scheduled flow calls once a link
 * has reached its expiration date.
 */
public with sharing class GoogleFileVersionExpireLinkAction {
    /**
     * The version whose public link should be withdrawn.
     */
    public class Input {
        @InvocableVariable(required=true)
        public Id localFileRecordId;
    }

    /**
     * Withdraws the public links of every version the flow supplied, removing the permission in Google Drive
     * as well as clearing the link in Salesforce.
     *
     * @param inputs One request per version.
     */
    @InvocableMethod(
        label='Public Link Expiration'
        description='Public link expiration for a Google Drive file (Local Google File Version)'
        category='Google Client'
        iconName='slds:standard:link'
    )
    public static void expireLink(List<Input> inputs) {
        if (inputs == null || inputs.isEmpty()) return;

        Set<Id> localFileVersionIds = new Set<Id>();
        for (Input input : inputs) {
            if (input != null && input.localFileRecordId != null) {
				localFileVersionIds.add(input.localFileRecordId);
			}
        }

        if (localFileVersionIds.isEmpty()) return;
        new GoogleLocalFileVersionPublicLinkService().removePublicLinkSharing(localFileVersionIds);
    }
}