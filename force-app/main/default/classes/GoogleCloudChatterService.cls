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
public with sharing class GoogleCloudChatterService {
  private static final Integer DEFAULT_FEED_LIMIT = 25;
  private static final Integer MAX_FEED_LIMIT = 100;
  private static final Integer MAX_ATTACHMENTS_PER_FEED_ITEM = 10;
  private static final Integer DEFAULT_PICKER_FILE_LIMIT = 200;
  private static final Integer MAX_PICKER_FILE_LIMIT = 500;

  private static final String FEED_TYPE_POST = 'POST';
  private static final String FEED_TYPE_POLL = 'POLL';
  private static final String FEED_TYPE_QUESTION = 'QUESTION';

  private static final String FEED_ITEM_TYPE_TEXT = 'TextPost';
  private static final String FEED_ITEM_TYPE_POLL = 'PollPost';
  private static final String FEED_ITEM_TYPE_QUESTION = 'QuestionPost';

  private static final String CHATTER_MODE_READ_ONLY = 'READ_ONLY';

  public static FeedViewDTO loadFeed(
    Id parentRecordId,
    Integer feedLimitSize,
    String mode,
    String publisherTabs
  ) {
    assertRecordReadable(parentRecordId);

    FeedViewDTO response = new FeedViewDTO();
    response.parentRecordId = parentRecordId;
    response.capabilities = resolveCapabilities(
      parentRecordId,
      mode,
      publisherTabs
    );

    Integer safeLimit = resolveFeedLimit(feedLimitSize);
    List<FeedItem> feedItems = queryFeedItemsByParent(
      parentRecordId,
      safeLimit
    );

    Set<Id> feedItemIds = collectFeedItemIds(feedItems);
    Set<Id> likedFeedItemIds = loadLikedFeedItemIds(feedItemIds);
    Map<Id, String> userPhotoById = loadUserPhotoByUserId(
      collectAuthorUserIds(feedItems)
    );
    Map<Id, List<GoogleFileDTO>> filesByFeedItemId = loadGoogleFilesByFeedItemId(
      feedItemIds
    );
    Map<Id, List<PollChoiceDTO>> pollChoicesByFeedItemId = loadPollChoicesByFeedItemId(
      feedItemIds
    );

    response.items = toFeedItemDtoList(
      feedItems,
      filesByFeedItemId,
      pollChoicesByFeedItemId,
      likedFeedItemIds,
      userPhotoById
    );
    response.feedLimitSize = safeLimit;
    return response;
  }

  public static FeedItemDTO createFeedItem(
    CreateFeedItemRequestDTO normalizedRequest
  ) {
    if (normalizedRequest == null || normalizedRequest.parentRecordId == null) {
      throw new AuraHandledException(
        'A parent record is required to create a Chatter post.'
      );
    }

    assertRecordReadable(normalizedRequest.parentRecordId);
    assertFeedItemCreateAccess();

    String feedType = normalizeFeedType(normalizedRequest.publisherType);
    assertPublishAllowed(
      feedType,
      normalizedRequest.mode,
      normalizedRequest.publisherTabs
    );

    String primaryBody = sanitizeBody(normalizedRequest.body);

    FeedItem feedItemRecord = new FeedItem();
    feedItemRecord.ParentId = normalizedRequest.parentRecordId;

    if (feedType == FEED_TYPE_POLL) {
      if (String.isBlank(primaryBody)) {
        throw new AuraHandledException('A poll question is required.');
      }

      feedItemRecord.Type = FEED_ITEM_TYPE_POLL;
      feedItemRecord.Title = primaryBody;
      feedItemRecord.Body = primaryBody;
    } else if (feedType == FEED_TYPE_QUESTION) {
      if (String.isBlank(primaryBody)) {
        throw new AuraHandledException('A question body is required.');
      }

      feedItemRecord.Type = FEED_ITEM_TYPE_QUESTION;
      feedItemRecord.Title = primaryBody;
      feedItemRecord.Body = primaryBody;
    } else {
      if (String.isBlank(primaryBody)) {
        throw new AuraHandledException('Post body cannot be empty.');
      }

      feedItemRecord.Type = FEED_ITEM_TYPE_TEXT;
      feedItemRecord.Body = primaryBody;
    }

    applyRequestedVisibility(feedItemRecord, normalizedRequest.visibility);
    Savepoint feedCreationSavepoint = Database.setSavepoint();

    try {
      Database.insert(feedItemRecord, AccessLevel.USER_MODE);

      if (feedType == FEED_TYPE_POLL) {
        createPollChoices(feedItemRecord.Id, normalizedRequest.pollChoices);
      }

      attachGoogleFiles(feedItemRecord.Id, normalizedRequest.googleFileIds);
      return loadSingleFeedItem(feedItemRecord.Id);
    } catch (DmlException ex) {
      Database.rollback(feedCreationSavepoint);
      throw new AuraHandledException(
        'Unable to create the Chatter post. Please verify your permissions and try again.'
      );
    } catch (AuraHandledException ex) {
      Database.rollback(feedCreationSavepoint);
      throw ex;
    } catch (Exception ex) {
      Database.rollback(feedCreationSavepoint);
      throw new AuraHandledException(
        'Unable to create the Chatter post. Please try again or contact your system administrator.'
      );
    }
  }

  public static List<GoogleFileDTO> retrieveOwnedGoogleFiles(
    Integer maxRecords
  ) {
    Integer safeLimit = resolveOwnedFileLimit(maxRecords);

    GoogleLocalFileService fileService = new GoogleLocalFileService();
    List<GoogleFile__c> discoverableFiles = fileService.retrieveGoogleFiles(
      UserInfo.getUserId()
    );
    if (discoverableFiles == null || discoverableFiles.isEmpty()) {
      return new List<GoogleFileDTO>();
    }

    Set<Id> ownedFileIds = new Set<Id>();
    for (GoogleFile__c discoverableFile : discoverableFiles) {
      if (discoverableFile != null && discoverableFile.Id != null) {
        ownedFileIds.add(discoverableFile.Id);
      }

      if (ownedFileIds.size() >= safeLimit) {
        break;
      }
    }

    if (ownedFileIds.isEmpty()) {
      return new List<GoogleFileDTO>();
    }

    List<GoogleFile__c> queriedFiles = (List<GoogleFile__c>) GoogleFileSelector.query()
      .byRecordIds(new List<Id>(ownedFileIds))
      .withBaseFields()
      .withLatestVersionSubquery()
      .toList();

    List<GoogleFile__c> accessibleFiles = fileService.stripInaccessibleRecords()
      .forFiles(queriedFiles)
      .forUser(UserInfo.getUserId())
      .strip();

    List<GoogleFileDTO> output = new List<GoogleFileDTO>();
    for (GoogleFile__c accessibleFile : accessibleFiles) {
      output.add(toGoogleFileDto(accessibleFile));
    }

    return output;
  }

  public static FeedCommentDTO createFeedComment(
    Id feedItemId,
    String commentBody,
    String mode
  ) {
    if (feedItemId == null) {
      throw new AuraHandledException(
        'A feed post is required to add a comment.'
      );
    }

    if (String.isBlank(commentBody)) {
      throw new AuraHandledException('Comment body cannot be empty.');
    }

    assertPublishingEnabled(mode, null);
    assertFeedCommentCreateAccess();
    requireFeedItemVisible(feedItemId);

    FeedComment feedCommentRecord = new FeedComment();
    feedCommentRecord.FeedItemId = feedItemId;
    feedCommentRecord.CommentBody = sanitizeBody(commentBody);

    try {
      Database.insert(feedCommentRecord, AccessLevel.USER_MODE);

      List<FeedComment> fetchedComments = [
        SELECT
          Id,
          FeedItemId,
          CommentBody,
          CreatedDate,
          CreatedById,
          CreatedBy.Name
        FROM FeedComment
        WHERE Id = :feedCommentRecord.Id
        WITH USER_MODE
        LIMIT 1
      ];

      if (fetchedComments.isEmpty()) {
        throw new AuraHandledException(
          'The comment was created but could not be loaded.'
        );
      }

      Map<Id, String> userPhotoById = loadUserPhotoByUserId(
        new Set<Id>{ fetchedComments[0].CreatedById }
      );
      return toFeedCommentDto(fetchedComments[0], userPhotoById);
    } catch (DmlException ex) {
      throw new AuraHandledException(
        'Unable to create the comment. Please verify your permissions and try again.'
      );
    }
  }

  public static FeedItemDTO toggleFeedItemLike(
    Id feedItemId,
    Boolean shouldLike
  ) {
    if (feedItemId == null) {
      throw new AuraHandledException(
        'A feed post is required to update likes.'
      );
    }

    requireFeedItemVisible(feedItemId);

    Schema.SObjectType feedLikeType = Schema.getGlobalDescribe()
      .get('FeedLike');
    if (feedLikeType == null) {
      return loadSingleFeedItem(feedItemId);
    }

    Schema.DescribeSObjectResult feedLikeDescribe = feedLikeType.getDescribe();
    if (!feedLikeDescribe.isAccessible() || !feedLikeDescribe.isQueryable()) {
      return loadSingleFeedItem(feedItemId);
    }

    Map<String, Schema.SObjectField> fields = feedLikeDescribe.fields.getMap();
    String parentFieldName = resolveFirstExistingField(
      fields,
      new List<String>{ 'FeedItemId', 'FeedEntityId', 'ParentId' }
    );

    if (String.isBlank(parentFieldName)) {
      throw new AuraHandledException(
        'Like actions are unavailable due to missing FeedLike linkage fields.'
      );
    }

    Boolean targetLikeState = shouldLike == true;

    try {
      if (targetLikeState) {
        if (!feedLikeDescribe.isCreateable()) {
          throw new AuraHandledException(
            'You do not have permission to like this post.'
          );
        }

        if (!hasLikeForFeedItem(feedItemId, parentFieldName)) {
          SObject likeRecord = feedLikeType.newSObject();
          likeRecord.put(parentFieldName, feedItemId);
          Database.insert(likeRecord, AccessLevel.USER_MODE);
        }
      } else {
        if (!feedLikeDescribe.isDeletable()) {
          throw new AuraHandledException(
            'You do not have permission to remove likes.'
          );
        }

        List<SObject> likesToDelete = queryLikesForFeedItem(
          feedItemId,
          parentFieldName
        );
        if (!likesToDelete.isEmpty()) {
          Database.delete(likesToDelete, AccessLevel.USER_MODE);
        }
      }

      return loadSingleFeedItem(feedItemId);
    } catch (DmlException ex) {
      throw new AuraHandledException(
        'Unable to update like state. Please try again.'
      );
    }
  }

  private static FeedItemDTO loadSingleFeedItem(Id feedItemId) {
    List<FeedItem> feedItems = queryFeedItemsByIds(new Set<Id>{ feedItemId });

    if (feedItems.isEmpty()) {
      throw new AuraHandledException('The feed post could not be loaded.');
    }

    Set<Id> feedItemIds = collectFeedItemIds(feedItems);
    Set<Id> likedFeedItemIds = loadLikedFeedItemIds(feedItemIds);
    Map<Id, String> userPhotoById = loadUserPhotoByUserId(
      collectAuthorUserIds(feedItems)
    );
    Map<Id, List<GoogleFileDTO>> filesByFeedItemId = loadGoogleFilesByFeedItemId(
      feedItemIds
    );
    Map<Id, List<PollChoiceDTO>> pollChoicesByFeedItemId = loadPollChoicesByFeedItemId(
      feedItemIds
    );

    return toFeedItemDtoList(
      feedItems,
      filesByFeedItemId,
      pollChoicesByFeedItemId,
      likedFeedItemIds,
      userPhotoById
    )[0];
  }

  private static List<FeedItem> queryFeedItemsByParent(
    Id parentRecordId,
    Integer feedLimitSize
  ) {
    return [
      SELECT
        Id,
        ParentId,
        Type,
        Title,
        Body,
        CreatedDate,
        LikeCount,
        CommentCount,
        CreatedById,
        CreatedBy.Name,
        (
          SELECT
            Id,
            FeedItemId,
            CommentBody,
            CreatedDate,
            CreatedById,
            CreatedBy.Name
          FROM FeedComments
          ORDER BY CreatedDate ASC
        )
      FROM FeedItem
      WHERE ParentId = :parentRecordId
      WITH USER_MODE
      ORDER BY CreatedDate DESC
      LIMIT :feedLimitSize
    ];
  }

  private static List<FeedItem> queryFeedItemsByIds(Set<Id> feedItemIds) {
    if (feedItemIds == null || feedItemIds.isEmpty()) {
      return new List<FeedItem>();
    }

    return [
      SELECT
        Id,
        ParentId,
        Type,
        Title,
        Body,
        CreatedDate,
        LikeCount,
        CommentCount,
        CreatedById,
        CreatedBy.Name,
        (
          SELECT
            Id,
            FeedItemId,
            CommentBody,
            CreatedDate,
            CreatedById,
            CreatedBy.Name
          FROM FeedComments
          ORDER BY CreatedDate ASC
        )
      FROM FeedItem
      WHERE Id IN :feedItemIds
      WITH USER_MODE
      ORDER BY CreatedDate DESC
    ];
  }

  private static Set<Id> collectFeedItemIds(List<FeedItem> feedItems) {
    Set<Id> feedItemIds = new Set<Id>();
    for (FeedItem itemRecord : feedItems) {
      if (itemRecord != null && itemRecord.Id != null) {
        feedItemIds.add(itemRecord.Id);
      }
    }
    return feedItemIds;
  }

  private static Set<Id> collectAuthorUserIds(List<FeedItem> feedItems) {
    Set<Id> authorUserIds = new Set<Id>();

    for (
      FeedItem feedItemRecord : feedItems == null
        ? new List<FeedItem>()
        : feedItems
    ) {
      if (feedItemRecord == null) {
        continue;
      }

      if (feedItemRecord.CreatedById != null) {
        authorUserIds.add(feedItemRecord.CreatedById);
      }

      for (
        FeedComment feedCommentRecord : feedItemRecord.FeedComments == null
          ? new List<FeedComment>()
          : feedItemRecord.FeedComments
      ) {
        if (feedCommentRecord.CreatedById != null) {
          authorUserIds.add(feedCommentRecord.CreatedById);
        }
      }
    }

    return authorUserIds;
  }

  private static Map<Id, String> loadUserPhotoByUserId(Set<Id> userIds) {
    Map<Id, String> photoByUserId = new Map<Id, String>();

    if (userIds == null || userIds.isEmpty()) {
      return photoByUserId;
    }

    Map<String, Schema.SObjectField> userFields = User.SObjectType.getDescribe()
      .fields.getMap();
    if (
      !userFields.containsKey('SmallPhotoUrl') ||
      !userFields.get('SmallPhotoUrl').getDescribe().isAccessible()
    ) {
      return photoByUserId;
    }

    for (User userRecord : [
      SELECT Id, SmallPhotoUrl
      FROM User
      WHERE Id IN :userIds
      WITH USER_MODE
    ]) {
      photoByUserId.put(userRecord.Id, userRecord.SmallPhotoUrl);
    }

    return photoByUserId;
  }

  private static Set<Id> loadLikedFeedItemIds(Set<Id> feedItemIds) {
    Set<Id> likedFeedItemIds = new Set<Id>();

    if (feedItemIds == null || feedItemIds.isEmpty()) {
      return likedFeedItemIds;
    }

    Schema.SObjectType feedLikeType = Schema.getGlobalDescribe()
      .get('FeedLike');
    if (feedLikeType == null) {
      return likedFeedItemIds;
    }

    Schema.DescribeSObjectResult feedLikeDescribe = feedLikeType.getDescribe();
    if (!feedLikeDescribe.isAccessible() || !feedLikeDescribe.isQueryable()) {
      return likedFeedItemIds;
    }

    String parentFieldName = resolveFirstExistingField(
      feedLikeDescribe.fields.getMap(),
      new List<String>{ 'FeedItemId', 'FeedEntityId', 'ParentId' }
    );

    if (String.isBlank(parentFieldName)) {
      return likedFeedItemIds;
    }

    Id currentUserId = UserInfo.getUserId();

    String soql = 'SELECT ' + parentFieldName + ' FROM FeedLike';
    soql += ' WHERE CreatedById = :currentUserId';
    soql += ' AND ' + parentFieldName + ' IN :feedItemIds';
    soql += ' WITH USER_MODE';

    try {
      for (SObject likeRecord : Database.query(soql)) {
        Id likedFeedItemId = (Id) likeRecord.get(parentFieldName);
        if (likedFeedItemId != null) {
          likedFeedItemIds.add(likedFeedItemId);
        }
      }
    } catch (QueryException ex) {
      return likedFeedItemIds;
    }

    return likedFeedItemIds;
  }

  private static Map<Id, List<PollChoiceDTO>> loadPollChoicesByFeedItemId(
    Set<Id> feedItemIds
  ) {
    Map<Id, List<PollChoiceDTO>> output = new Map<Id, List<PollChoiceDTO>>();

    if (feedItemIds == null || feedItemIds.isEmpty()) {
      return output;
    }

    Schema.SObjectType pollChoiceType = Schema.getGlobalDescribe()
      .get('FeedPollChoice');
    if (pollChoiceType == null) {
      return output;
    }

    Schema.DescribeSObjectResult pollChoiceDescribe = pollChoiceType.getDescribe();
    if (!pollChoiceDescribe.isAccessible()) {
      return output;
    }

    Map<String, Schema.SObjectField> fields = pollChoiceDescribe.fields.getMap();

    String parentFieldName = resolveFirstExistingField(
      fields,
      new List<String>{ 'FeedItemId', 'ParentId' }
    );
    String choiceFieldName = resolveFirstExistingField(
      fields,
      new List<String>{ 'ChoiceBody', 'ChoiceText', 'Name', 'Text' }
    );
    String positionFieldName = resolveFirstExistingField(
      fields,
      new List<String>{ 'Position', 'SortOrder' }
    );
    String voteCountFieldName = resolveFirstExistingField(
      fields,
      new List<String>{ 'VoteCount', 'Votes' }
    );

    if (String.isBlank(parentFieldName) || String.isBlank(choiceFieldName)) {
      return output;
    }

    String soql = 'SELECT Id,' + parentFieldName + ',' + choiceFieldName;
    if (!String.isBlank(positionFieldName)) {
      soql += ',' + positionFieldName;
    }
    if (!String.isBlank(voteCountFieldName)) {
      soql += ',' + voteCountFieldName;
    }

    soql += ' FROM FeedPollChoice';
    soql += ' WHERE ' + parentFieldName + ' IN :feedItemIds';
    if (!String.isBlank(positionFieldName)) {
      soql += ' ORDER BY ' + positionFieldName + ' ASC';
    }

    List<SObject> pollChoiceRecords = Database.query(soql);

    for (SObject pollChoiceRecord : pollChoiceRecords) {
      Id feedItemId = (Id) pollChoiceRecord.get(parentFieldName);
      if (feedItemId == null) {
        continue;
      }

      if (!output.containsKey(feedItemId)) {
        output.put(feedItemId, new List<PollChoiceDTO>());
      }

      PollChoiceDTO dto = new PollChoiceDTO();
      dto.id = (Id) pollChoiceRecord.get('Id');
      dto.feedItemId = feedItemId;
      dto.choiceBody = String.valueOf(pollChoiceRecord.get(choiceFieldName));
      dto.position = !String.isBlank(positionFieldName)
        ? toIntegerSafe(pollChoiceRecord.get(positionFieldName))
        : null;
      dto.voteCount = !String.isBlank(voteCountFieldName)
        ? toIntegerSafe(pollChoiceRecord.get(voteCountFieldName))
        : null;

      output.get(feedItemId).add(dto);
    }

    return output;
  }

  private static void createPollChoices(
    Id feedItemId,
    List<String> rawChoices
  ) {
    List<String> choices = sanitizePollChoices(rawChoices);
    new GoogleCloudChatterPollChoicesCommand(feedItemId, choices).execute();
  }

  private static List<String> sanitizePollChoices(List<String> rawChoices) {
    List<String> output = new List<String>();
    Set<String> dedupe = new Set<String>();

    for (
      String rawChoice : rawChoices == null ? new List<String>() : rawChoices
    ) {
      String trimmedChoice = rawChoice == null ? '' : rawChoice.trim();
      if (String.isBlank(trimmedChoice)) {
        continue;
      }

      String capped = trimmedChoice.length() > 255
        ? trimmedChoice.substring(0, 255)
        : trimmedChoice;

      String dedupeKey = capped.toLowerCase();
      if (dedupe.contains(dedupeKey)) {
        continue;
      }

      dedupe.add(dedupeKey);
      output.add(capped);
    }

    return output;
  }

  private static void attachGoogleFiles(Id feedItemId, List<Id> googleFileIds) {
    Set<Id> selectedFileIds = new Set<Id>();
    for (
      Id candidateId : googleFileIds == null ? new List<Id>() : googleFileIds
    ) {
      if (candidateId != null) {
        selectedFileIds.add(candidateId);
      }
    }

    if (selectedFileIds.size() > MAX_ATTACHMENTS_PER_FEED_ITEM) {
      throw new AuraHandledException(
        'A post supports up to 10 attached Google files.'
      );
    }

    if (selectedFileIds.isEmpty()) {
      return;
    }

    Schema.DescribeSObjectResult fileLinkDescribe = GoogleFileLink__c.SObjectType.getDescribe();
    if (!fileLinkDescribe.isCreateable()) {
      throw new AuraHandledException(
        'You do not have permission to attach Google files to this post.'
      );
    }

    List<GoogleFile__c> queriedGoogleFiles = (List<GoogleFile__c>) GoogleFileSelector.query()
      .byRecordIds(new List<Id>(selectedFileIds))
      .withBaseFields()
      .withLatestVersionSubquery()
      .toList();

    GoogleLocalFileService fileService = new GoogleLocalFileService();
    List<GoogleFile__c> accessibleFiles = fileService.stripInaccessibleRecords()
      .forFiles(queriedGoogleFiles)
      .forUser(UserInfo.getUserId())
      .strip();

    Set<Id> accessibleFileIds = new Set<Id>();
    for (GoogleFile__c accessibleFile : accessibleFiles) {
      accessibleFileIds.add(accessibleFile.Id);
    }

    if (accessibleFileIds.size() != selectedFileIds.size()) {
      throw new AuraHandledException(
        'One or more selected Google files are inaccessible.'
      );
    }

    User currentUser = [
      SELECT Id, UserType
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];

    Boolean isInternalUser = isInternalUserType(currentUser.UserType);

    List<GoogleFileLink__c> linksToInsert = new List<GoogleFileLink__c>();
    for (Id selectedFileId : selectedFileIds) {
      GoogleFileLink__c linkRecord = new GoogleFileLink__c();
      linkRecord.GoogleFileId__c = selectedFileId;
      linkRecord.LinkedObjectId__c = String.valueOf(feedItemId);
      linkRecord.LinkedObjectType__c = FeedItem.SObjectType.getDescribe()
        .getName();
      linkRecord.ShareType__c = isInternalUser
        ? 'Viewer'
        : 'InferredFromRecord';
      linkRecord.Visibility__c = isInternalUser ? 'InternalUsers' : 'AllUsers';
      linksToInsert.add(linkRecord);
    }

    Database.insert(linksToInsert, AccessLevel.USER_MODE);
  }

  private static Map<Id, List<GoogleFileDTO>> loadGoogleFilesByFeedItemId(
    Set<Id> feedItemIds
  ) {
    Map<Id, List<GoogleFileDTO>> filesByFeedItemId = new Map<Id, List<GoogleFileDTO>>();

    if (feedItemIds == null || feedItemIds.isEmpty()) {
      return filesByFeedItemId;
    }

    if (!GoogleFileLink__c.SObjectType.getDescribe().isAccessible()) {
      return filesByFeedItemId;
    }

    Set<String> feedItemIdStrings = new Set<String>();
    for (Id feedItemId : feedItemIds) {
      feedItemIdStrings.add(String.valueOf(feedItemId));
    }

    List<GoogleFileLink__c> fileLinks = [
      SELECT Id, GoogleFileId__c, LinkedObjectId__c
      FROM GoogleFileLink__c
      WHERE LinkedObjectId__c IN :feedItemIdStrings AND GoogleFileId__c != NULL
      WITH USER_MODE
      ORDER BY CreatedDate ASC
    ];

    if (fileLinks.isEmpty()) {
      return filesByFeedItemId;
    }

    Set<Id> linkedFileIds = new Set<Id>();
    Map<String, Set<Id>> fileIdsByFeedItemIdText = new Map<String, Set<Id>>();

    for (GoogleFileLink__c fileLink : fileLinks) {
      if (
        fileLink.GoogleFileId__c == null ||
        String.isBlank(fileLink.LinkedObjectId__c)
      ) {
        continue;
      }

      linkedFileIds.add(fileLink.GoogleFileId__c);

      if (!fileIdsByFeedItemIdText.containsKey(fileLink.LinkedObjectId__c)) {
        fileIdsByFeedItemIdText.put(fileLink.LinkedObjectId__c, new Set<Id>());
      }

      fileIdsByFeedItemIdText.get(fileLink.LinkedObjectId__c)
        .add(fileLink.GoogleFileId__c);
    }

    if (linkedFileIds.isEmpty()) {
      return filesByFeedItemId;
    }

    List<GoogleFile__c> linkedFiles = (List<GoogleFile__c>) GoogleFileSelector.query()
      .byRecordIds(new List<Id>(linkedFileIds))
      .withBaseFields()
      .withLatestVersionSubquery()
      .toList();

    GoogleLocalFileService fileService = new GoogleLocalFileService();
    List<GoogleFile__c> accessibleFiles = fileService.stripInaccessibleRecords()
      .forFiles(linkedFiles)
      .forUser(UserInfo.getUserId())
      .strip();

    Map<Id, GoogleFileDTO> fileDtoByFileId = new Map<Id, GoogleFileDTO>();
    for (GoogleFile__c accessibleFile : accessibleFiles) {
      fileDtoByFileId.put(accessibleFile.Id, toGoogleFileDto(accessibleFile));
    }

    for (Id feedItemId : feedItemIds) {
      String feedItemIdText = String.valueOf(feedItemId);
      Set<Id> fileIds = fileIdsByFeedItemIdText.get(feedItemIdText);
      if (fileIds == null || fileIds.isEmpty()) {
        continue;
      }

      List<GoogleFileDTO> files = new List<GoogleFileDTO>();
      for (Id fileId : fileIds) {
        GoogleFileDTO fileDto = fileDtoByFileId.get(fileId);
        if (fileDto != null) {
          files.add(fileDto);
        }
      }

      filesByFeedItemId.put(feedItemId, files);
    }

    return filesByFeedItemId;
  }

  private static GoogleFileDTO toGoogleFileDto(GoogleFile__c fileRecord) {
    GoogleFileDTO dto = new GoogleFileDTO();
    dto.localId = fileRecord.Id;
    dto.source = fileRecord.Source__c;
    dto.userAccessLevel = fileRecord.UserAccessLevel__c;

    if (
      fileRecord.GoogleFileVersions__r != null &&
      !fileRecord.GoogleFileVersions__r.isEmpty()
    ) {
      GoogleFileVersion__c latestVersion = fileRecord.GoogleFileVersions__r[0];
      dto.latestVersionId = latestVersion.Id;
      dto.name = latestVersion.Name;
      dto.mimeType = latestVersion.Type__c;
      dto.sizeBytes = latestVersion.Size__c == null
        ? null
        : latestVersion.Size__c.longValue();
      dto.lastModifiedDate = latestVersion.LastModifiedDate;
      dto.createdDate = latestVersion.CreatedDate;

      if (latestVersion.CreatedBy != null) {
        dto.createdBy = new ActorDTO();
        dto.createdBy.id = latestVersion.CreatedBy.Id;
        dto.createdBy.name = latestVersion.CreatedBy.Name;
      }
    }

    return dto;
  }

  private static List<FeedItemDTO> toFeedItemDtoList(
    List<FeedItem> feedItems,
    Map<Id, List<GoogleFileDTO>> filesByFeedItemId,
    Map<Id, List<PollChoiceDTO>> pollChoicesByFeedItemId,
    Set<Id> likedFeedItemIds,
    Map<Id, String> userPhotoById
  ) {
    List<FeedItemDTO> output = new List<FeedItemDTO>();

    for (FeedItem feedItemRecord : feedItems) {
      FeedItemDTO dto = new FeedItemDTO();
      dto.id = feedItemRecord.Id;
      dto.parentRecordId = feedItemRecord.ParentId;
      dto.type = feedItemRecord.Type;
      dto.title = feedItemRecord.Title;
      dto.body = feedItemRecord.Body;
      dto.createdDate = feedItemRecord.CreatedDate;
      dto.likeCount = feedItemRecord.LikeCount;
      dto.commentCount = feedItemRecord.CommentCount;
      dto.isLikedByCurrentUser =
        likedFeedItemIds != null &&
        likedFeedItemIds.contains(feedItemRecord.Id);

      dto.author = new ActorDTO();
      dto.author.id = feedItemRecord.CreatedById;
      dto.author.name = feedItemRecord.CreatedBy == null
        ? null
        : feedItemRecord.CreatedBy.Name;
      dto.author.photoUrl = userPhotoById == null
        ? null
        : userPhotoById.get(feedItemRecord.CreatedById);

      dto.comments = new List<FeedCommentDTO>();
      List<FeedComment> childComments = feedItemRecord.FeedComments;
      for (
        FeedComment childComment : childComments == null
          ? new List<FeedComment>()
          : childComments
      ) {
        dto.comments.add(toFeedCommentDto(childComment, userPhotoById));
      }

      dto.googleFiles = filesByFeedItemId.containsKey(feedItemRecord.Id)
        ? filesByFeedItemId.get(feedItemRecord.Id)
        : new List<GoogleFileDTO>();

      dto.pollChoices = pollChoicesByFeedItemId.containsKey(feedItemRecord.Id)
        ? pollChoicesByFeedItemId.get(feedItemRecord.Id)
        : new List<PollChoiceDTO>();

      output.add(dto);
    }

    return output;
  }

  private static FeedCommentDTO toFeedCommentDto(
    FeedComment feedCommentRecord,
    Map<Id, String> userPhotoById
  ) {
    FeedCommentDTO dto = new FeedCommentDTO();
    dto.id = feedCommentRecord.Id;
    dto.feedItemId = feedCommentRecord.FeedItemId;
    dto.commentBody = feedCommentRecord.CommentBody;
    dto.createdDate = feedCommentRecord.CreatedDate;
    dto.likeCount = 0;
    dto.isLikedByCurrentUser = false;

    dto.author = new ActorDTO();
    dto.author.id = feedCommentRecord.CreatedById;
    dto.author.name = feedCommentRecord.CreatedBy == null
      ? null
      : feedCommentRecord.CreatedBy.Name;
    dto.author.photoUrl = userPhotoById == null
      ? null
      : userPhotoById.get(feedCommentRecord.CreatedById);
    return dto;
  }

  private static FeedCapabilitiesDTO resolveCapabilities(
    Id parentRecordId,
    String mode,
    String publisherTabs
  ) {
    FeedCapabilitiesDTO capabilities = new FeedCapabilitiesDTO();
    ChatterPublishPolicy publishPolicy = resolveChatterPublishPolicy(
      mode,
      publisherTabs
    );
    Set<String> allowedPublisherTypes = resolveAllowedPublisherTypes(
      publishPolicy
    );

    Boolean canReadFeed =
      FeedItem.SObjectType.getDescribe().isAccessible() &&
      hasReadAccessToRecord(parentRecordId);

    capabilities.canReadFeed = canReadFeed;
    capabilities.canCreatePosts =
      canReadFeed &&
      FeedItem.SObjectType.getDescribe().isCreateable() &&
      publishPolicy.isReadOnlyMode != true &&
      allowedPublisherTypes.contains(FEED_TYPE_POST);
    capabilities.canCreateComments =
      canReadFeed &&
      FeedComment.SObjectType.getDescribe().isCreateable() &&
      publishPolicy.isReadOnlyMode != true;
    capabilities.canToggleLikes = false;
    capabilities.canAttachGoogleFiles =
      capabilities.canCreatePosts &&
      GoogleFile__c.SObjectType.getDescribe().isAccessible() &&
      GoogleFileLink__c.SObjectType.getDescribe().isCreateable();
    capabilities.isReadOnlyMode = publishPolicy.isReadOnlyMode;
    capabilities.allowedPublisherTypes = toPublisherTypeList(
      allowedPublisherTypes
    );

    AudienceConfigDTO audienceConfig = resolveAudienceConfig();
    capabilities.audienceOptions = audienceConfig.options;
    capabilities.defaultAudienceValue = audienceConfig.defaultValue;

    return capabilities;
  }

  private static AudienceConfigDTO resolveAudienceConfig() {
    AudienceConfigDTO config = new AudienceConfigDTO();
    config.options = new List<AudienceOptionDTO>();

    Map<String, Schema.SObjectField> feedItemFields = FeedItem.SObjectType.getDescribe()
      .fields.getMap();
    if (!feedItemFields.containsKey('Visibility')) {
      return config;
    }

    Schema.DescribeFieldResult visibilityDescribe = feedItemFields.get(
        'Visibility'
      )
      .getDescribe();
    if (!visibilityDescribe.isAccessible()) {
      return config;
    }

    String currentUserName = UserInfo.getName();
    Boolean isInternalUser = isInternalUserType(UserInfo.getUserType());

    for (
      Schema.PicklistEntry picklistEntry : visibilityDescribe.getPicklistValues()
    ) {
      if (!picklistEntry.isActive()) {
        continue;
      }

      String picklistValue = picklistEntry.getValue();
      if (!isInternalUser && picklistValue == 'InternalUsers') {
        continue;
      }

      AudienceOptionDTO option = new AudienceOptionDTO();
      option.value = picklistValue;
      option.label = resolveAudienceLabel(
        option.value,
        picklistEntry.getLabel(),
        currentUserName,
        isInternalUser
      );
      config.options.add(option);

      if (
        String.isBlank(config.defaultValue) && picklistEntry.isDefaultValue()
      ) {
        config.defaultValue = option.value;
      }
    }

    if (isInternalUser) {
      for (AudienceOptionDTO option : config.options) {
        if (option.value == 'InternalUsers') {
          config.defaultValue = option.value;
          break;
        }
      }
    }

    if (String.isBlank(config.defaultValue)) {
      for (AudienceOptionDTO option : config.options) {
        if (option.value == 'AllUsers') {
          config.defaultValue = option.value;
          break;
        }
      }
    }

    if (String.isBlank(config.defaultValue) && !config.options.isEmpty()) {
      config.defaultValue = config.options[0].value;
    }

    return config;
  }

  private static String resolveAudienceLabel(
    String value,
    String sourceLabel,
    String currentUserName,
    Boolean isInternalUser
  ) {
    if (value == 'AllUsers') {
      return 'All with access';
    }

    if (value == 'Self' || value == 'Private') {
      return (String.isBlank(currentUserName) ? 'Me' : currentUserName) +
        ' Only';
    }

    if (value == 'InternalUsers') {
      if (isInternalUser == true) {
        return (String.isBlank(currentUserName) ? 'Me' : currentUserName) +
          ' Only';
      }
      return String.isBlank(sourceLabel) ? 'Internal users' : sourceLabel;
    }

    return String.isBlank(sourceLabel) ? value : sourceLabel;
  }

  private static void applyRequestedVisibility(
    FeedItem feedItemRecord,
    String requestedVisibility
  ) {
    if (feedItemRecord == null || String.isBlank(requestedVisibility)) {
      return;
    }

    Boolean isInternalUser = isInternalUserType(UserInfo.getUserType());
    if (!isInternalUser && requestedVisibility == 'InternalUsers') {
      return;
    }

    Map<String, Schema.SObjectField> feedItemFields = FeedItem.SObjectType.getDescribe()
      .fields.getMap();
    if (!feedItemFields.containsKey('Visibility')) {
      return;
    }

    Schema.DescribeFieldResult visibilityDescribe = feedItemFields.get(
        'Visibility'
      )
      .getDescribe();
    if (!visibilityDescribe.isCreateable()) {
      return;
    }

    Set<String> allowedValues = new Set<String>();
    for (
      Schema.PicklistEntry picklistEntry : visibilityDescribe.getPicklistValues()
    ) {
      if (picklistEntry.isActive()) {
        allowedValues.add(picklistEntry.getValue());
      }
    }

    if (allowedValues.contains(requestedVisibility)) {
      feedItemRecord.put('Visibility', requestedVisibility);
    }
  }

  private static void assertFeedItemCreateAccess() {
    if (!FeedItem.SObjectType.getDescribe().isCreateable()) {
      throw new AuraHandledException(
        'You do not have permission to create Chatter posts.'
      );
    }
  }

  private static void assertFeedCommentCreateAccess() {
    if (!FeedComment.SObjectType.getDescribe().isCreateable()) {
      throw new AuraHandledException(
        'You do not have permission to create Chatter comments.'
      );
    }
  }

  private static void assertRecordReadable(Id parentRecordId) {
    if (parentRecordId == null || !hasReadAccessToRecord(parentRecordId)) {
      throw new AuraHandledException(
        'You do not have access to this record feed.'
      );
    }

    if (!FeedItem.SObjectType.getDescribe().isAccessible()) {
      throw new AuraHandledException(
        'You do not have permission to view Chatter feed data.'
      );
    }
  }

  private static Boolean hasReadAccessToRecord(Id parentRecordId) {
    if (parentRecordId == null) {
      return false;
    }

    List<UserRecordAccess> userAccessRows = [
      SELECT RecordId, HasReadAccess
      FROM UserRecordAccess
      WHERE UserId = :UserInfo.getUserId() AND RecordId = :parentRecordId
      LIMIT 1
    ];

    return !userAccessRows.isEmpty() && userAccessRows[0].HasReadAccess;
  }

  private static FeedItem requireFeedItemVisible(Id feedItemId) {
    List<FeedItem> feedItems = [
      SELECT Id, ParentId
      FROM FeedItem
      WHERE Id = :feedItemId
      WITH USER_MODE
      LIMIT 1
    ];

    if (feedItems.isEmpty()) {
      throw new AuraHandledException(
        'The requested Chatter post is unavailable or inaccessible.'
      );
    }

    return feedItems[0];
  }

  private static String normalizeFeedType(String incomingType) {
    if (String.isBlank(incomingType)) {
      return FEED_TYPE_POST;
    }

    String normalizedType = incomingType.trim().toUpperCase();

    if (
      normalizedType == FEED_TYPE_POST ||
      normalizedType == FEED_TYPE_POLL ||
      normalizedType == FEED_TYPE_QUESTION
    ) {
      return normalizedType;
    }

    return FEED_TYPE_POST;
  }

  private static String sanitizeBody(String rawText) {
    String normalized = rawText == null ? '' : rawText.trim();
    Integer maxBodyLength = 10000;

    return normalized.length() > maxBodyLength
      ? normalized.substring(0, maxBodyLength)
      : normalized;
  }

  private static Integer resolveFeedLimit(Integer requestedLimit) {
    if (requestedLimit == null || requestedLimit <= 0) {
      return DEFAULT_FEED_LIMIT;
    }

    return Math.min(requestedLimit, MAX_FEED_LIMIT);
  }

  private static Integer resolveOwnedFileLimit(Integer requestedLimit) {
    if (requestedLimit == null || requestedLimit <= 0) {
      return DEFAULT_PICKER_FILE_LIMIT;
    }

    return Math.min(requestedLimit, MAX_PICKER_FILE_LIMIT);
  }

  private static void assertPublishAllowed(
    String feedType,
    String mode,
    String publisherTabs
  ) {
    assertPublishingEnabled(mode, publisherTabs);

    ChatterPublishPolicy publishPolicy = resolveChatterPublishPolicy(
      mode,
      publisherTabs
    );

    Set<String> allowedPublisherTypes = resolveAllowedPublisherTypes(
      publishPolicy
    );
    if (!allowedPublisherTypes.contains(feedType)) {
      throw new AuraHandledException(
        'This publisher type is disabled for this component configuration.'
      );
    }
  }

  private static void assertPublishingEnabled(
    String mode,
    String publisherTabs
  ) {
    ChatterPublishPolicy publishPolicy = resolveChatterPublishPolicy(
      mode,
      publisherTabs
    );
    if (publishPolicy.isReadOnlyMode == true) {
      throw new AuraHandledException(
        'Publishing is disabled for this component configuration.'
      );
    }
  }

  private static Set<String> resolveAllowedPublisherTypes(
    ChatterPublishPolicy publishPolicy
  ) {
    Set<String> orgSupportedTypes = resolveOrgSupportedPublisherTypes();
    Set<String> configuredTypes = publishPolicy == null ||
      publishPolicy.allowedPublisherTypes == null
      ? new Set<String>{ FEED_TYPE_POST, FEED_TYPE_POLL, FEED_TYPE_QUESTION }
      : publishPolicy.allowedPublisherTypes;

    Set<String> output = new Set<String>();
    for (String typeName : orgSupportedTypes) {
      if (configuredTypes.contains(typeName)) {
        output.add(typeName);
      }
    }

    if (
      !output.contains(FEED_TYPE_POST) &&
      orgSupportedTypes.contains(FEED_TYPE_POST)
    ) {
      output.add(FEED_TYPE_POST);
    }

    return output;
  }

  private static Set<String> resolveOrgSupportedPublisherTypes() {
    Set<String> output = new Set<String>{ FEED_TYPE_POST };

    if (
      isFeedItemTypeAvailable(FEED_ITEM_TYPE_POLL) && canCreatePollChoices()
    ) {
      output.add(FEED_TYPE_POLL);
    }

    if (isFeedItemTypeAvailable(FEED_ITEM_TYPE_QUESTION)) {
      output.add(FEED_TYPE_QUESTION);
    }

    return output;
  }

  private static Boolean isFeedItemTypeAvailable(String feedItemTypeName) {
    if (!FeedItem.SObjectType.getDescribe().isCreateable()) {
      return false;
    }

    Map<String, Schema.SObjectField> feedItemFields = FeedItem.SObjectType.getDescribe()
      .fields.getMap();
    if (!feedItemFields.containsKey('Type')) {
      return false;
    }

    Schema.DescribeFieldResult typeDescribe = feedItemFields.get('Type')
      .getDescribe();
    if (!typeDescribe.isCreateable()) {
      return false;
    }

    for (Schema.PicklistEntry entry : typeDescribe.getPicklistValues()) {
      if (entry.isActive() && entry.getValue() == feedItemTypeName) {
        return true;
      }
    }

    return false;
  }

  private static Boolean canCreatePollChoices() {
    Schema.SObjectType pollChoiceType = Schema.getGlobalDescribe()
      .get('FeedPollChoice');
    if (pollChoiceType == null) {
      return false;
    }

    Schema.DescribeSObjectResult pollChoiceDescribe = pollChoiceType.getDescribe();
    if (!pollChoiceDescribe.isCreateable()) {
      return false;
    }

    Map<String, Schema.SObjectField> fields = pollChoiceDescribe.fields.getMap();
    String parentFieldName = resolveFirstExistingField(
      fields,
      new List<String>{ 'FeedItemId', 'ParentId' }
    );
    String choiceFieldName = resolveFirstExistingField(
      fields,
      new List<String>{ 'ChoiceBody', 'ChoiceText', 'Name', 'Text' }
    );

    if (String.isBlank(parentFieldName) || String.isBlank(choiceFieldName)) {
      return false;
    }

    return fields.containsKey(parentFieldName) &&
      fields.containsKey(choiceFieldName) &&
      fields.get(parentFieldName).getDescribe().isCreateable() &&
      fields.get(choiceFieldName).getDescribe().isCreateable();
  }

  private static ChatterPublishPolicy resolveChatterPublishPolicy(
    String mode,
    String publisherTabs
  ) {
    ChatterPublishPolicy output = new ChatterPublishPolicy();
    output.isReadOnlyMode = false;
    output.allowedPublisherTypes = new Set<String>{
      FEED_TYPE_POST,
      FEED_TYPE_POLL,
      FEED_TYPE_QUESTION
    };

    String modeValue = toStringSafe(mode);
    String normalizedMode = String.isBlank(modeValue)
      ? null
      : modeValue.trim().toUpperCase();

    output.isReadOnlyMode =
      normalizedMode == CHATTER_MODE_READ_ONLY ||
      normalizedMode == 'READONLY';

    String tabsValue = toStringSafe(publisherTabs);
    Set<String> configuredPublisherTypes = parsePublisherTypeConfig(tabsValue);
    if (!configuredPublisherTypes.isEmpty()) {
      output.allowedPublisherTypes = configuredPublisherTypes;
    }

    return output;
  }

  private static Set<String> parsePublisherTypeConfig(String rawValue) {
    Set<String> output = new Set<String>();
    if (String.isBlank(rawValue)) {
      return output;
    }

    String normalizedValue = rawValue.trim().toUpperCase();
    if (normalizedValue == 'POST_ONLY') {
      output.add(FEED_TYPE_POST);
      return output;
    }

    if (normalizedValue == 'POST_POLL') {
      output.add(FEED_TYPE_POST);
      output.add(FEED_TYPE_POLL);
      return output;
    }

    if (normalizedValue == 'POST_POLL_QUESTION') {
      output.add(FEED_TYPE_POST);
      output.add(FEED_TYPE_POLL);
      output.add(FEED_TYPE_QUESTION);
      return output;
    }

    String preparedValue = normalizedValue.replace(';', ',').replace('|', ',');

    for (String token : preparedValue.split(',')) {
      String normalizedToken = token == null ? '' : token.trim().toUpperCase();
      if (String.isBlank(normalizedToken)) {
        continue;
      }

      if (normalizedToken == FEED_TYPE_POST) {
        output.add(FEED_TYPE_POST);
      } else if (normalizedToken == FEED_TYPE_POLL) {
        output.add(FEED_TYPE_POLL);
      } else if (normalizedToken == FEED_TYPE_QUESTION) {
        output.add(FEED_TYPE_QUESTION);
      }
    }

    return output;
  }

  private static List<String> toPublisherTypeList(Set<String> publisherTypes) {
    List<String> orderedTypes = new List<String>();
    if (publisherTypes != null && publisherTypes.contains(FEED_TYPE_POST)) {
      orderedTypes.add(FEED_TYPE_POST);
    }

    if (publisherTypes != null && publisherTypes.contains(FEED_TYPE_POLL)) {
      orderedTypes.add(FEED_TYPE_POLL);
    }

    if (publisherTypes != null && publisherTypes.contains(FEED_TYPE_QUESTION)) {
      orderedTypes.add(FEED_TYPE_QUESTION);
    }

    return orderedTypes;
  }

  private static Boolean isInternalUserType(String userType) {
    if (userType == null) {
      return true;
    }

    String normalizedType = userType.toLowerCase();
    return !(normalizedType.contains('guest') ||
    normalizedType.contains('portal') ||
    normalizedType.contains('partner') ||
    normalizedType.contains('customer') ||
    normalizedType.contains('csn'));
  }

  private static String resolveFirstExistingField(
    Map<String, Schema.SObjectField> fields,
    List<String> candidates
  ) {
    for (String candidate : candidates) {
      if (fields.containsKey(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  private static Integer toIntegerSafe(Object value) {
    if (value == null) {
      return null;
    }

    try {
      return Integer.valueOf(String.valueOf(value));
    } catch (Exception ex) {
      return null;
    }
  }

  public static CreateFeedItemRequestDTO buildCreateRequest(
    Id parentRecordId,
    String publisherType,
    String body,
    String visibility,
    List<String> pollChoices,
    List<String> googleFileIds,
    String mode,
    String publisherTabs
  ) {
    CreateFeedItemRequestDTO request = new CreateFeedItemRequestDTO();
    request.parentRecordId = parentRecordId;
    request.publisherType = publisherType;
    request.body = body;
    request.visibility = visibility;
    request.pollChoices = pollChoices == null
      ? new List<String>()
      : pollChoices;
    request.googleFileIds = toIdListSafe(googleFileIds);
    request.mode = mode;
    request.publisherTabs = publisherTabs;
    return request;
  }

  private static String toStringSafe(Object rawValue) {
    return rawValue == null ? null : String.valueOf(rawValue);
  }

  private static Id toIdSafe(Object rawValue) {
    if (rawValue == null) {
      return null;
    }

    String idText = String.valueOf(rawValue).trim();
    if (String.isBlank(idText)) {
      return null;
    }

    try {
      return (Id) idText;
    } catch (Exception ex) {
      return null;
    }
  }

  private static List<Id> toIdListSafe(List<String> rawIds) {
    List<Id> output = new List<Id>();
    Set<Id> dedupe = new Set<Id>();

    for (String rawId : rawIds == null ? new List<String>() : rawIds) {
      if (String.isBlank(rawId)) {
        continue;
      }

      try {
        Id parsedId = (Id) rawId.trim();
        if (parsedId == null || dedupe.contains(parsedId)) {
          continue;
        }

        dedupe.add(parsedId);
        output.add(parsedId);
      } catch (Exception ex) {
        throw new AuraHandledException(
          'One or more attached Google files are invalid.'
        );
      }
    }

    if (output.size() > MAX_ATTACHMENTS_PER_FEED_ITEM) {
      throw new AuraHandledException(
        'A post supports up to 10 attached Google files.'
      );
    }

    return output;
  }

  private static List<SObject> queryLikesForFeedItem(
    Id feedItemId,
    String parentFieldName
  ) {
    Id currentUserId = UserInfo.getUserId();
    String soql = 'SELECT Id FROM FeedLike';
    soql += ' WHERE CreatedById = :currentUserId';
    soql += ' AND ' + parentFieldName + ' = :feedItemId';
    soql += ' WITH USER_MODE';

    try {
      return Database.query(soql);
    } catch (QueryException ex) {
      return new List<SObject>();
    }
  }

  private static Boolean isLikeFeatureUsable() {
    Schema.SObjectType feedLikeType = Schema.getGlobalDescribe()
      .get('FeedLike');
    if (feedLikeType == null) {
      return false;
    }

    Schema.DescribeSObjectResult feedLikeDescribe = feedLikeType.getDescribe();
    return feedLikeDescribe.isAccessible() &&
      feedLikeDescribe.isQueryable() &&
      (feedLikeDescribe.isCreateable() || feedLikeDescribe.isDeletable());
  }

  private static Boolean hasLikeForFeedItem(
    Id feedItemId,
    String parentFieldName
  ) {
    List<SObject> likes = queryLikesForFeedItem(feedItemId, parentFieldName);
    return !likes.isEmpty();
  }

  public class FeedViewDTO {
    @AuraEnabled
    public Id parentRecordId;
    @AuraEnabled
    public Integer feedLimitSize;
    @AuraEnabled
    public FeedCapabilitiesDTO capabilities;
    @AuraEnabled
    public List<FeedItemDTO> items;
  }

  public class FeedCapabilitiesDTO {
    @AuraEnabled
    public Boolean canReadFeed;
    @AuraEnabled
    public Boolean canCreatePosts;
    @AuraEnabled
    public Boolean canCreateComments;
    @AuraEnabled
    public Boolean canToggleLikes;
    @AuraEnabled
    public Boolean canAttachGoogleFiles;
    @AuraEnabled
    public Boolean isReadOnlyMode;
    @AuraEnabled
    public String defaultAudienceValue;
    @AuraEnabled
    public List<String> allowedPublisherTypes;
    @AuraEnabled
    public List<AudienceOptionDTO> audienceOptions;
  }

  private class ChatterPublishPolicy {
    public Boolean isReadOnlyMode;
    public Set<String> allowedPublisherTypes;
  }

  public class CreateFeedItemRequestDTO {
    @AuraEnabled
    public Id parentRecordId;
    @AuraEnabled
    public String publisherType;
    @AuraEnabled
    public String body;
    @AuraEnabled
    public String visibility;
    @AuraEnabled
    public List<String> pollChoices;
    @AuraEnabled
    public List<Id> googleFileIds;
    @AuraEnabled
    public String mode;
    @AuraEnabled
    public String publisherTabs;
  }

  public class AudienceOptionDTO {
    @AuraEnabled
    public String value;
    @AuraEnabled
    public String label;
  }

  public class AudienceConfigDTO {
    public String defaultValue;
    public List<AudienceOptionDTO> options;
  }

  public class FeedItemDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id parentRecordId;
    @AuraEnabled
    public String type;
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String body;
    @AuraEnabled
    public Datetime createdDate;
    @AuraEnabled
    public Integer likeCount;
    @AuraEnabled
    public Integer commentCount;
    @AuraEnabled
    public Boolean isLikedByCurrentUser;
    @AuraEnabled
    public ActorDTO author;
    @AuraEnabled
    public List<FeedCommentDTO> comments;
    @AuraEnabled
    public List<GoogleFileDTO> googleFiles;
    @AuraEnabled
    public List<PollChoiceDTO> pollChoices;
  }

  public class FeedCommentDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id feedItemId;
    @AuraEnabled
    public String commentBody;
    @AuraEnabled
    public Datetime createdDate;
    @AuraEnabled
    public Integer likeCount;
    @AuraEnabled
    public Boolean isLikedByCurrentUser;
    @AuraEnabled
    public ActorDTO author;
  }

  public class PollChoiceDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id feedItemId;
    @AuraEnabled
    public String choiceBody;
    @AuraEnabled
    public Integer position;
    @AuraEnabled
    public Integer voteCount;
  }

  public class GoogleFileDTO {
    @AuraEnabled
    public Id localId;
    @AuraEnabled
    public Id latestVersionId;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String mimeType;
    @AuraEnabled
    public Long sizeBytes;
    @AuraEnabled
    public Datetime createdDate;
    @AuraEnabled
    public Datetime lastModifiedDate;
    @AuraEnabled
    public String source;
    @AuraEnabled
    public String userAccessLevel;
    @AuraEnabled
    public ActorDTO createdBy;
  }

  public class ActorDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String photoUrl;
  }
}
