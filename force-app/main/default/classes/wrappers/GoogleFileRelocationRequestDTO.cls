public class GoogleFileRelocationRequestDTO {
    public Id initiatorUserId;
	public Id localGoogleFileId;
	public Id localGoogleFileVersionId;
	public Id linkLocalGoogleFileId;

	public GoogleFileRelocationRequestDTO(Id initiatorUserId, Id localGoogleFileId, Id localGoogleFileVersionId, Id linkLocalGoogleFileId) {
		this.initiatorUserId = initiatorUserId;
		this.localGoogleFileId = localGoogleFileId;
		this.localGoogleFileVersionId = localGoogleFileVersionId;
		this.linkLocalGoogleFileId = linkLocalGoogleFileId;
	}
}