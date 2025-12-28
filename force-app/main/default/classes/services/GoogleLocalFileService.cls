public without sharing class GoogleLocalFileService {
	public class GoogleLocalFileException extends Exception {}

	private final IGoogleUnitOfWork uow;

	public GoogleLocalFileService() {
		this.uow = new GoogleCloudUnitOfWork(new List<SObjectType>{
			GoogleFile__c.SObjectType,
			GoogleFileVersion__c.SObjectType,
			GoogleFileLink__c.SObjectType
		});
	}

	public GoogleLocalFileService(IGoogleUnitOfWork injectedUow) {
		this.uow = injectedUow == null
			? new GoogleCloudUnitOfWork(new List<SObjectType>{
				GoogleFile__c.SObjectType,
				GoogleFileVersion__c.SObjectType,
				GoogleFileLink__c.SObjectType
			})
			: injectedUow;
	}

	public GoogleFileInsertCommand createGoogleFileRecord() {
		try {
			return new GoogleFileInsertCommand(uow);
		} catch (Exception ex) {
			Logger.error('Create Google File Record (Local): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleLocalFileException('Unable to create the file record. Please try again or contact your system administrator');
		}
	}

	public GoogleFileSharingCommand.CreateSharingCommand createGoogleFileSharing() {
		try {
			return new GoogleFileSharingCommand(uow).createSharing();
		} catch (Exception ex) {
			Logger.error('Create Google File Sharing (Local/Remote): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleLocalFileException('Unable to share the file. Please try again or contact your system administrator');
		}
	}

	public GoogleFileDeleteCommand deleteGoogleFileRecord() {
		try {
			return new GoogleFileDeleteCommand(uow);
		} catch (Exception ex) {
			Logger.error('Delete Google File Record (Local/Remote): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleLocalFileException('Unable to delete the file. Please try again or contact your system administrator');
		}
	}

	public GoogleFileSharingCommand.DeleteSharingCommand deleteGoogleFileSharing() {
		try {
			return new GoogleFileSharingCommand(uow).deleteSharing();
		} catch (Exception ex) {
			Logger.error('Delete Google File Sharing (Local): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleLocalFileException('Unable to remove sharing for this file. Please try again or contact your system administrator');
		}
	}

	public GoogleFileSharingCommand.ModifySharingCommand modifyGoogleFileSharing() {
		try {
			return new GoogleFileSharingCommand(uow).modifySharing();
		} catch (Exception ex) {
			Logger.error('Modify Google File Sharing (Local): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleLocalFileException('Unable to update sharing for this file. Please try again or contact your system administrator');
		}
	}

	public GoogleFileSharingCommand.RetrieveSharingCommand retrieveSharingDetails() {
		try {
			return new GoogleFileSharingCommand(uow).retrieveSharing();
		} catch (Exception ex) {
			Logger.error('Retrieve Sharing Details (Local): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleLocalFileException('Unable to retrieve sharing details. Please try again or contact your system administrator');
		}
	}

	public GoogleFilePageDetailsCommand.RetrieveHeaderCommand retrieveGoogleFileHeaderDetails() {
		try {
			return new GoogleFilePageDetailsCommand().retrieveHeader();
		} catch (Exception ex) {
			Logger.error('Retrieve Page Details Header (Local): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleLocalFileException('Unable to retrieve file details. Please try again or contact your system administrator');
		}
	}

	public GoogleFileAccessCheckCommand stripInaccessibleRecords() {
		try {
			return new GoogleFileAccessCheckCommand();
		} catch (Exception ex) {
			Logger.error('Strip Inaccessible Records (Local/Security): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleLocalFileException('Unable to verify access to the requested files due to security restrictions. Please try again or contact your system administrator');
		}
	}
}