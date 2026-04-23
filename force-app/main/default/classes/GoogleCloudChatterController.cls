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
public with sharing class GoogleCloudChatterController {
  @AuraEnabled(cacheable=true)
  public static GoogleCloudChatterService.FeedViewDTO loadFeed(
    Id parentRecordId,
    Integer feedLimitSize,
    String mode,
    String publisherTabs
  ) {
    try {
      return GoogleCloudChatterService.loadFeed(
        parentRecordId,
        feedLimitSize,
        mode,
        publisherTabs
      );
    } catch (AuraHandledException ex) {
      throw ex;
    } catch (Exception ex) {
      throw new AuraHandledException(
        'Unable to load the Chatter feed. Please try again.'
      );
    }
  }

  @AuraEnabled
  public static GoogleCloudChatterService.FeedItemDTO createFeedItemDirect(
    Id parentRecordId,
    String publisherType,
    String body,
    String visibility,
    List<String> pollChoices,
    List<String> googleFileIds,
    String mode,
    String publisherTabs
  ) {
    try {
      GoogleCloudChatterService.CreateFeedItemRequestDTO request = GoogleCloudChatterService.buildCreateRequest(
        parentRecordId,
        publisherType,
        body,
        visibility,
        pollChoices,
        googleFileIds,
        mode,
        publisherTabs
      );
      return GoogleCloudChatterService.createFeedItem(request);
    } catch (AuraHandledException ex) {
      throw ex;
    } catch (Exception ex) {
      throw new AuraHandledException(
        'Unable to create the Chatter post. Please try again.'
      );
    }
  }

  @AuraEnabled
  public static GoogleCloudChatterService.FeedCommentDTO createFeedComment(
    Id feedItemId,
    String commentBody,
    String mode
  ) {
    try {
      return GoogleCloudChatterService.createFeedComment(
        feedItemId,
        commentBody,
        mode
      );
    } catch (AuraHandledException ex) {
      throw ex;
    } catch (Exception ex) {
      throw new AuraHandledException(
        'Unable to create the comment. Please try again.'
      );
    }
  }

  @AuraEnabled
  public static GoogleCloudChatterService.FeedItemDTO toggleFeedItemLike(
    Id feedItemId,
    Boolean shouldLike
  ) {
    try {
      return GoogleCloudChatterService.toggleFeedItemLike(
        feedItemId,
        shouldLike
      );
    } catch (AuraHandledException ex) {
      throw ex;
    } catch (Exception ex) {
      throw new AuraHandledException(
        'Unable to update the like state. Please try again.'
      );
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<GoogleCloudChatterService.GoogleFileDTO> retrieveOwnedGoogleFiles(
    Integer maxRecords
  ) {
    try {
      return GoogleCloudChatterService.retrieveOwnedGoogleFiles(maxRecords);
    } catch (AuraHandledException ex) {
      throw ex;
    } catch (Exception ex) {
      throw new AuraHandledException(
        'Unable to load your Google files. Please try again.'
      );
    }
  }
}
